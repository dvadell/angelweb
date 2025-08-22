"""
Tests for the Forecasting Service (main.py).

This test suite uses pytest and FastAPI's TestClient to send requests
to the application. It uses mocking to isolate the service from external
dependencies like the database, ensuring that tests are fast, reliable, and
focused on the application's logic.
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock
from datetime import datetime, timedelta
import pandas as pd

# The app from main.py is imported to be tested.
# It's important that this import happens before any patches are applied
# to ensure the application is loaded correctly.
from main import app

# The TestClient gives us a way to send HTTP requests to our FastAPI application
# inside a test function.
client = TestClient(app)

def generate_dummy_metric_data(days=14):
    """Helper function to generate a sample time series dataframe for testing."""
    data = []
    now = datetime.now()
    for i in range(days * 24):  # Generate hourly data
        # Create a simple sine wave to simulate daily seasonality
        value = 100 + 20 * (1 + (i % 24) / 24)
        timestamp = now - timedelta(hours=i)
        data.append({"timestamp": timestamp, "value": float(value)})
    # Return data in reverse chronological order, which is how it would be fetched
    return data[::-1]

@pytest.fixture
def sample_metric_data():
    """Pytest fixture to provide sample metric data to tests."""
    return generate_dummy_metric_data()

def test_health_check():
    """Test the /health endpoint to ensure the service is running."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
def test_list_available_metrics(mock_get_available_metrics):
    """Test the /metrics endpoint that lists available metrics."""
    # Arrange: Set up the mock to return a predefined list of metrics.
    expected_metrics = ["cpu", "ram", "disk"]
    mock_get_available_metrics.return_value = expected_metrics

    # Act: Call the endpoint.
    response = client.get("/metrics")

    # Assert: Check that the response is successful and contains the expected data.
    assert response.status_code == 200
    assert response.json() == {"available_metrics": expected_metrics}

@patch("main.asyncio.to_thread")
@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_forecast_metric_success(mock_fetch_data, mock_get_metrics, mock_to_thread, sample_metric_data):
    """
    Test the /forecast/{metric_name} endpoint for a successful scenario.
    It mocks the database calls and the call to Prophet to ensure the test is fast
    and doesn't depend on the forecasting model's output.
    """
    # Arrange: Configure mocks to simulate successful database calls.
    test_metric = "test_cpu_usage"
    mock_get_metrics.return_value = [test_metric, "another_metric"]
    mock_fetch_data.return_value = sample_metric_data

    # Create a dummy forecast dataframe to be returned by the mock.
    # This mimics the output of Prophet, which includes historical and future predictions.
    original_df = pd.DataFrame(sample_metric_data)
    original_df.rename(columns={'timestamp': 'ds', 'value': 'y'}, inplace=True)
    original_df['ds'] = pd.to_datetime(original_df['ds'])

    historical_forecast_df = pd.DataFrame({'ds': original_df['ds'], 'yhat': original_df['y'] * 0.95})
    
    last_timestamp = original_df['ds'].max()
    future_dates = [last_timestamp + timedelta(hours=i) for i in range(1, 25)]
    future_forecast_df = pd.DataFrame({
        'ds': future_dates,
        'yhat': [100.0] * 24,
        'yhat_lower': [90.0] * 24,
        'yhat_upper': [110.0] * 24,
    })
    
    full_forecast_df = pd.concat([historical_forecast_df, future_forecast_df], ignore_index=True)
    
    # The mocked `to_thread` will return our dummy data instead of running Prophet.
    mock_to_thread.return_value = (original_df, full_forecast_df)

    # Act: Make a POST request to the forecasting endpoint.
    response = client.post(f"/forecast/{test_metric}")

    # Assert: Verify the response is successful and has the correct structure.
    assert response.status_code == 200
    data = response.json()
    assert data["metric"] == test_metric
    assert "forecast_points" in data
    assert len(data["forecast_points"]) == 24  # Default hours_ahead
    assert "anomaly_threshold_upper" in data
    assert "anomaly_threshold_lower" in data
    assert "model_accuracy" in data
    assert data["model_accuracy"] > 0.8 # Should be high since yhat is close to y
    assert "last_updated" in data
    
    # Verify the structure of a single forecast point.
    point = data["forecast_points"][0]
    assert "timestamp" in point
    assert point["predicted_value"] == 100.0
    assert "lower_bound" in point
    assert "upper_bound" in point

@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
def test_forecast_metric_metric_not_found(mock_get_available_metrics):
    """Test that a 404 error is returned if the requested metric does not exist."""
    # Arrange: Mock the available metrics to not include the requested one.
    mock_get_available_metrics.return_value = ["some_other_metric"]

    # Act: Request a forecast for a metric that doesn't exist.
    response = client.post("/forecast/non_existent_metric")

    # Assert: Check for a 404 Not Found status and an informative error message.
    assert response.status_code == 404
    assert "not found" in response.json()["detail"]

@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_forecast_metric_no_historical_data(mock_fetch_data, mock_get_metrics):
    """Test that a 404 error is returned if a valid metric has no historical data."""
    # Arrange: Mock a valid metric name but return no data from the database.
    test_metric = "cpu_usage"
    mock_get_metrics.return_value = [test_metric]
    mock_fetch_data.return_value = []  # Simulate no data found

    # Act: Request the forecast.
    response = client.post(f"/forecast/{test_metric}")

    # Assert: Check for a 404 Not Found status and the correct error message.
    assert response.status_code == 404
    assert "No historical data found" in response.json()["detail"]

@patch("main.asyncio.to_thread")
@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_forecast_metric_internal_error(mock_fetch_data, mock_get_metrics, mock_to_thread):
    """Test that a 500 internal server error is returned if Prophet fails."""
    # Arrange: Simulate an unexpected exception during the Prophet forecasting process.
    test_metric = "ram_usage"
    mock_get_metrics.return_value = [test_metric]
    mock_fetch_data.return_value = generate_dummy_metric_data()
    mock_to_thread.side_effect = Exception("Prophet failed miserably")

    # Act: Request the forecast.
    response = client.post(f"/forecast/{test_metric}")

    # Assert: Check for a 500 Internal Server Error.
    assert response.status_code == 500
    assert "Forecasting failed" in response.json()["detail"]
