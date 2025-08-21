import os
import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime, timedelta
from typing import List, Dict, Any
import uvicorn

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
        # TODO: Validate metric exists
        # if not metric_exists(metric_name):
        #     raise HTTPException(status_code=404, detail=f"Metric {metric_name} not found")
        
        # TODO: Fetch historical data from TimescaleDB
        # historical_data = fetch_metric_data(metric_name)
        
        # TODO: Run Prophet forecasting
        # forecast_data = run_prophet_forecast(historical_data, request.hours_ahead, request.confidence_interval)
        
        # DUMMY DATA - replace with actual Prophet implementation
        current_time = datetime.now()
        dummy_forecast_points = []
        
        # Generate dummy forecast points
        for i in range(request.hours_ahead):
            timestamp = current_time + timedelta(hours=i+1)
            # Simulate server response time with some seasonality pattern
            base_value = 150 + (50 * (i % 24) / 24)  # Daily pattern
            predicted_value = base_value + (10 * (i % 7) / 7)  # Weekly pattern
            
            dummy_forecast_points.append(ForecastPoint(
                timestamp=timestamp,
                predicted_value=predicted_value,
                lower_bound=predicted_value * 0.8,  # 20% lower bound
                upper_bound=predicted_value * 1.2   # 20% upper bound
            ))
        
        return ForecastResponse(
            metric=metric_name,
            forecast_points=dummy_forecast_points,
            anomaly_threshold_upper=200.0,  # TODO: Calculate from historical data
            anomaly_threshold_lower=50.0,   # TODO: Calculate from historical data
            model_accuracy=0.85,            # TODO: Calculate actual model performance metrics
            last_updated=current_time
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Forecasting failed: {str(e)}")

@app.post("/detect_anomalies/{metric_name}")
async def detect_anomalies(metric_name: str, hours_back: int = 24):
    """
    Anomaly detection endpoint - compares recent actual values against forecast
    
    Steps to implement:
    1. Get recent actual values from TimescaleDB
    2. Get corresponding forecast values (from cache or regenerate)
    3. Compare actual vs predicted with confidence bounds
    4. Flag values outside bounds as anomalies
    5. Return anomaly periods with severity scores
    """
    
    # TODO: Implement actual anomaly detection logic
    # actual_data = fetch_recent_data(metric_name, hours_back)
    # forecast_data = get_forecast_for_period(metric_name, hours_back_start, hours_back_end)
    # anomalies = detect_anomalies_logic(actual_data, forecast_data)
    
    # DUMMY DATA
    current_time = datetime.now()
    dummy_anomalies = [
        {
            "timestamp": current_time - timedelta(hours=5),
            "actual_value": 500.0,
            "predicted_value": 150.0,
            "severity": "high",
            "deviation_score": 2.5
        },
        {
            "timestamp": current_time - timedelta(hours=2),
            "actual_value": 250.0,
            "predicted_value": 180.0,
            "severity": "medium", 
            "deviation_score": 1.8
        }
    ]
    
    return {
        "metric": metric_name,
        "period_analyzed_hours": hours_back,
        "anomalies_detected": len(dummy_anomalies),
        "anomalies": dummy_anomalies,
        "analysis_timestamp": current_time
    }

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

async def fetch_metric_data(metric_name: str, hours_back: int = 24 * 7) -> List[Dict]:
    """
    Fetch historical metric data from TimescaleDB
    
    Args:
        metric_name: Name of the metric to fetch
        hours_back: How many hours of historical data to fetch
    
    Returns:
        List of dictionaries with 'timestamp' and 'value' keys
    """
    # TODO: Implement TimescaleDB query
    # SELECT time, value FROM metrics 
    # WHERE metric_name = %s 
    # AND time >= NOW() - INTERVAL '%s hours'
    # ORDER BY time ASC
    pass

async def run_prophet_forecast(historical_data: List[Dict], hours_ahead: int, confidence_interval: float):
    """
    Run Prophet forecasting model
    
    Steps:
    1. Convert data to pandas DataFrame with 'ds' and 'y' columns
    2. Initialize Prophet with seasonality settings
    3. Fit model on historical data
    4. Create future dataframe
    5. Generate predictions
    6. Extract confidence intervals
    """
    # TODO: Implement Prophet forecasting logic
    pass

# Development server startup
if __name__ == "__main__":
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True  # Remove in production
    )
