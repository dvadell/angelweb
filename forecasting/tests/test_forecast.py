"""Tests for the /forecast endpoint."""

from unittest.mock import patch, AsyncMock
from datetime import datetime, timedelta
import pandas as pd

@patch("main.asyncio.to_thread")
@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_forecast_metric_success(mock_fetch_data, mock_get_metrics, mock_to_thread, sample_metric_data, client):
    """
    Test the /forecast/{metric_name} endpoint for a successful scenario.
    It mocks the database calls and the call to Prophet to ensure the test is fast
    and doesn't depend on the forecasting model's output.
    """
    # Arrange: Configure mocks
    test_metric = "test_cpu_usage"
    mock_get_metrics.return_value = [test_metric, "another_metric"]
    mock_fetch_data.return_value = sample_metric_data

    original_df = pd.DataFrame(sample_metric_data)
    original_df.rename(columns={'timestamp': 'ds', 'value': 'y'}, inplace=True)
    original_df['ds'] = pd.to_datetime(original_df['ds'])

    # Create a dummy forecast dataframe to be returned by the mock.
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
    
    mock_to_thread.return_value = (original_df, full_forecast_df)

    # Act: Call the endpoint
    response = client.post(f"/forecast/{test_metric}")

    # Assert: Check the response
    assert response.status_code == 200
    data = response.json()
    assert data["metric"] == test_metric
    assert len(data["forecast_points"]) == 24
    assert data["model_accuracy"] > 0.8
    
    point = data["forecast_points"][0]
    assert point["predicted_value"] == 100.0

@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
def test_forecast_metric_metric_not_found(mock_get_available_metrics, client):
    """Test that a 404 error is returned if the requested metric does not exist."""
    mock_get_available_metrics.return_value = ["some_other_metric"]
    response = client.post("/forecast/non_existent_metric")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"]

@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_forecast_metric_no_historical_data(mock_fetch_data, mock_get_metrics, client):
    """Test that a 404 error is returned if a valid metric has no historical data."""
    test_metric = "cpu_usage"
    mock_get_metrics.return_value = [test_metric]
    mock_fetch_data.return_value = []
    response = client.post(f"/forecast/{test_metric}")
    assert response.status_code == 404
    assert "No historical data found" in response.json()["detail"]

@patch("main.asyncio.to_thread")
@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_forecast_metric_internal_error(mock_fetch_data, mock_get_metrics, mock_to_thread, client):
    """Test that a 500 internal server error is returned if Prophet fails."""
    test_metric = "ram_usage"
    mock_get_metrics.return_value = [test_metric]
    mock_fetch_data.return_value = [{"timestamp": datetime.now(), "value": 1.0}]
    mock_to_thread.side_effect = Exception("Prophet failed miserably")
    response = client.post(f"/forecast/{test_metric}")
    assert response.status_code == 500
    assert "Forecasting failed" in response.json()["detail"]
