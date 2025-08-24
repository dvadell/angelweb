import os
import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime, timedelta
from typing import List, Dict, Any
import uvicorn
import pandas as pd
from prophet import Prophet
import asyncio

app = FastAPI(
    title="Forecasting Service",
    description="Time series forecasting and anomaly detection for server metrics",
    version="1.0.0"
)

# Global database connection pool
db_pool = None

# Pydantic models for request/response validation
class ForecastRequest(BaseModel):
    hours_ahead: int = 24
    confidence_interval: float = 0.95

class ForecastPoint(BaseModel):
    timestamp: datetime
    predicted_value: float
    lower_bound: float
    upper_bound: float

class ForecastResponse(BaseModel):
    metric: str
    forecast_points: List[ForecastPoint]
    anomaly_threshold_upper: float
    anomaly_threshold_lower: float
    model_accuracy: float
    last_updated: datetime

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_timescaledb()
    yield
    # Shutdown
    await close_timescaledb_connection()

app = FastAPI(
    title="Forecasting Service",
    description="Time series forecasting and anomaly detection for server metrics",
    version="1.0.0",
    lifespan=lifespan
)

@app.get("/health")
async def health_check():
    """Health check endpoint for Docker/Phoenix to verify service is running"""
    return {"status": "healthy", "service": "forecasting", "timestamp": datetime.now()}

async def _get_available_metrics_from_db() -> List[str]:
    """
    Helper function to query distinct metric names from the 'graphs' table.
    """
    global db_pool
    if db_pool is None:
        raise HTTPException(status_code=500, detail="Database connection not established.")

    try:
        async with db_pool.acquire() as connection:
            metrics = await connection.fetch("SELECT DISTINCT short_name FROM graphs ORDER BY short_name")
            return [m['short_name'] for m in metrics]
    except Exception as e:
        # Re-raise as HTTPException to be caught by FastAPI's error handling
        raise HTTPException(status_code=500, detail=f"Failed to fetch available metrics from DB: {str(e)}")

@app.get("/metrics")
async def list_available_metrics():
    """
    Return list of metrics available for forecasting by querying the 'graphs' table.
    """
    available_metrics = await _get_available_metrics_from_db()
    return {"available_metrics": available_metrics}

@app.post("/forecast/{metric_name}")
async def forecast_metric(metric_name: str, request: ForecastRequest = ForecastRequest()):
    """
    Main forecasting endpoint
    
    Steps to implement:
    1. Validate metric_name exists in database
    2. Fetch historical data from TimescaleDB 
    3. Prepare data for Prophet (rename columns to 'ds' and 'y')
    4. Fit Prophet model with seasonality parameters
    5. Generate forecast for requested time period
    6. Calculate anomaly detection bounds
    7. Return structured forecast data
    """
    try:
        # Step 1: Validate metric_name exists in database
        # Query the database for the list of all available metric names.
        available_metrics = await _get_available_metrics_from_db()
        if metric_name not in available_metrics:
            # If the requested metric is not in the list, return a 404 error.
            raise HTTPException(status_code=404, detail=f"Metric '{metric_name}' not found. Available metrics: {available_metrics}")
        
        # Step 2: Fetch historical data from TimescaleDB
        # Retrieve the time series data for the specified metric.
        historical_data = await fetch_metric_data(metric_name)

        # A forecast cannot be generated without historical data.
        if not historical_data:
            raise HTTPException(status_code=404, detail=f"No historical data found for metric '{metric_name}' to generate a forecast.")

        # Steps 3, 4, and 5: Prepare data, fit model, and generate forecast.
        # These steps are computationally intensive and are handled within the `run_prophet_forecast` function.
        # To prevent blocking the main asynchronous event loop, this synchronous, CPU-bound function
        # is run in a separate thread pool managed by FastAPI.
        df, forecast = await asyncio.to_thread(
            run_prophet_forecast, 
            historical_data, 
            request.hours_ahead, 
            request.confidence_interval
        )
        
        # The forecast dataframe contains both historical predictions and future values.
        # We extract only the future points for the final response.
        future_forecast = forecast.tail(request.hours_ahead)
        forecast_points = [
            ForecastPoint(
                timestamp=row['ds'],
                predicted_value=row['yhat'],
                lower_bound=row['yhat_lower'],
                upper_bound=row['yhat_upper']
            ) for _, row in future_forecast.iterrows()
        ]

        # Step 6: Calculate anomaly detection bounds.
        # These bounds are calculated using the residuals (the difference between actual and predicted values)
        # from the historical portion of the data. A common approach is to set the threshold at a certain
        # number of standard deviations (e.g., 3) away from the mean of the predictions.
        residuals = (df['y'] - forecast.head(len(df))['yhat']).abs()
        anomaly_threshold_upper = forecast['yhat'].mean() + (3 * residuals.std())
        anomaly_threshold_lower = forecast['yhat'].mean() - (3 * residuals.std())

        # As a bonus, calculate the model's accuracy using Mean Absolute Percentage Error (MAPE)
        # on the historical data. This gives an indication of the forecast's reliability.
        # We add a small epsilon (1e-9) to the denominator to avoid division-by-zero errors.
        mape = (((df['y'] - forecast.head(len(df))['yhat']).abs()) / (df['y'] + 1e-9)).mean()
        model_accuracy = max(0, 1 - mape) # Accuracy is represented as 1 - MAPE, clamped at 0.

        # Step 7: Return structured forecast data.
        # The final data is packaged into the ForecastResponse Pydantic model, which handles
        # data validation and JSON serialization.
        return ForecastResponse(
            metric=metric_name,
            forecast_points=forecast_points,
            anomaly_threshold_upper=anomaly_threshold_upper,
            anomaly_threshold_lower=anomaly_threshold_lower,
            model_accuracy=model_accuracy,
            last_updated=datetime.now()
        )
        
    except Exception as e:
        # If the exception is an HTTPException, re-raise it to let FastAPI handle it.
        if isinstance(e, HTTPException):
            raise
        # If any other exception occurs, catch it and return a generic 500 error
        # to prevent leaking internal implementation details.
        raise HTTPException(status_code=500, detail=f"Forecasting failed: {str(e)}")

@app.post("/detect_anomalies/{metric_name}")
async def detect_anomalies(metric_name: str, hours_back: int = 24):
    """
    Anomaly detection endpoint - compares recent actual values against forecast.
    """
    try:
        # To detect anomalies in the last `hours_back` period, we need to train a model
        # on data from *before* that period. We'll use 7 days of prior data for training.
        training_plus_detection_hours = hours_back + (24 * 7)
        all_data = await fetch_metric_data(metric_name, training_plus_detection_hours)

        if not all_data:
            raise HTTPException(status_code=404, detail=f"Not enough data for metric '{metric_name}' to detect anomalies.")

        all_df = pd.DataFrame(all_data)
        all_df['timestamp'] = pd.to_datetime(all_df['timestamp']).dt.tz_localize(None)
        
        # Split data into a training set (historical) and a detection set (recent)
        detection_start_time = all_df['timestamp'].max() - timedelta(hours=hours_back)
        
        training_data = [row.to_dict() for _, row in all_df[all_df['timestamp'] < detection_start_time].iterrows()]
        detection_df = all_df[all_df['timestamp'] >= detection_start_time].copy()

        # We need a minimum amount of data to train a meaningful model.
        MIN_TRAINING_POINTS = 72  # 3 days of hourly data
        if len(training_data) < MIN_TRAINING_POINTS:
            raise HTTPException(status_code=404, detail=f"Not enough historical data for metric '{metric_name}' to build a model for anomaly detection. Need at least {MIN_TRAINING_POINTS} data points for training.")

        # Generate a forecast for the detection period using the training data.
        # We use a wider confidence interval (99%) for anomaly detection to reduce false positives.
        _, forecast = await asyncio.to_thread(
            run_prophet_forecast,
            training_data,
            hours_back,
            0.99  # 99% confidence interval
        )

        # Get the forecasted values for the detection period
        recent_forecast = forecast.tail(hours_back)

        # Merge actual recent values with the forecasted values
        detection_df.rename(columns={'timestamp': 'ds', 'value': 'y'}, inplace=True)
        merged_df = pd.merge(
            detection_df, 
            recent_forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']], 
            on='ds',
            how='inner'
        )

        # Identify points where the actual value is outside the confidence bands
        merged_df['is_anomaly'] = (merged_df['y'] < merged_df['yhat_lower']) | (merged_df['y'] > merged_df['yhat_upper'])
        
        anomalies_df = merged_df[merged_df['is_anomaly']]

        # Prepare the response
        anomalies_list = []
        for _, row in anomalies_df.iterrows():
            if row['y'] > row['yhat_upper']:
                deviation = row['y'] - row['yhat_upper']
                severity_range = (row['yhat_upper'] - row['yhat_lower'])
            else: # row['y'] < row['yhat_lower']
                deviation = row['yhat_lower'] - row['y']
                severity_range = (row['yhat_upper'] - row['yhat_lower'])

            severity = "high" if severity_range > 0 and deviation / severity_range > 0.5 else "medium"

            anomalies_list.append({
                "timestamp": row['ds'],
                "actual_value": row['y'],
                "predicted_value": row['yhat'],
                "severity": severity,
                "deviation_score": deviation
            })

        return {
            "metric": metric_name,
            "period_analyzed_hours": hours_back,
            "anomalies_detected": len(anomalies_list),
            "anomalies": anomalies_list,
            "analysis_timestamp": datetime.now()
        }
    except Exception as e:
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(status_code=500, detail=f"Anomaly detection failed: {str(e)}")

async def connect_to_timescaledb():
    """
    Initialize database connection pool using DATABASE_URL from environment variables.
    """
    global db_pool
    try:
        db_url = os.getenv("DATABASE_URL")
        if not db_url:
            raise ValueError("DATABASE_URL environment variable not set.")
        db_pool = await asyncpg.create_pool(db_url)
        print("Successfully connected to TimescaleDB.")
    except Exception as e:
        print(f"Failed to connect to TimescaleDB: {e}")
        # Depending on desired behavior, you might want to re-raise or exit here
        raise

async def close_timescaledb_connection():
    """
    Close the database connection pool.
    """
    global db_pool
    if db_pool:
        await db_pool.close()
        print("TimescaleDB connection pool closed.")

async def fetch_metric_data(metric_name: str, hours_back: int = 24 * 7) -> List[Dict[str, Any]]:
    """
    Fetch historical metric data from TimescaleDB
    
    Args:
        metric_name: Name of the metric to fetch
        hours_back: How many hours of historical data to fetch
    
    Returns:
        List of dictionaries with 'timestamp' and 'value' keys
    """
    global db_pool
    if db_pool is None:
        raise HTTPException(status_code=500, detail="Database connection not established.")

    # This query joins the 'events' table (which stores time-series data)
    # with the 'graphs' table (which defines the metrics) to fetch historical
    # data for a given metric's short_name.
    query = """
      SELECT metric_timestamp, avg_value FROM get_metrics($1::text, NOW() - INTERVAL '%s hours', NOW())
    """ 
    formatted_query = query % hours_back
    
    try:
        async with db_pool.acquire() as connection:
            records = await connection.fetch(formatted_query, metric_name)
            # The Prophet library expects float values, so we cast here
            return [{"timestamp": r['metric_timestamp'], "value": float(r['avg_value'])} for r in records]
    except Exception as e:
        # Re-raise as HTTPException to be caught by FastAPI's error handling
        raise HTTPException(status_code=500, detail=f"Failed to fetch historical data for metric '{metric_name}': {str(e)}")

def run_prophet_forecast(historical_data: List[Dict[str, Any]], hours_ahead: int, confidence_interval: float):
    """
    Run Prophet forecasting model
    
    Steps:
    1. Convert data to pandas DataFrame with 'ds' and 'y' columns
    2. Initialize Prophet with seasonality settings
    3. Fit model on historical data
    4. Create future dataframe
    5. Generate predictions
    6. Return original dataframe and forecast dataframe
    """
    # 1. Convert data to pandas DataFrame
    df = pd.DataFrame(historical_data)
    df.rename(columns={'timestamp': 'ds', 'value': 'y'}, inplace=True)

    # Ensure 'ds' is datetime (and timezone-naive) and 'y' is numeric
    df['ds'] = pd.to_datetime(df['ds']).dt.tz_localize(None)
    df['y'] = pd.to_numeric(df['y'])

    # 2. Initialize Prophet
    m = Prophet(interval_width=confidence_interval)

    # 3. Fit model
    m.fit(df)

    # 4. Create future dataframe
    future = m.make_future_dataframe(periods=hours_ahead, freq='H')

    # 5. Generate predictions
    forecast = m.predict(future)

    # 6. Return both dataframes
    return df, forecast

# Development server startup
if __name__ == "__main__":
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True  # Remove in production
    )
