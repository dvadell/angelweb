"""Tests for the /detect_anomalies endpoint."""

from unittest.mock import patch, AsyncMock
from datetime import datetime, timedelta
import pandas as pd

@patch("main.asyncio.to_thread")
@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_detect_anomalies_success(mock_fetch_data, mock_to_thread, sample_metric_data, client):
    """Test the /detect_anomalies/{metric_name} endpoint for a successful scenario."""
    # Arrange
    test_metric = "test_cpu_usage"
    mock_fetch_data.return_value = sample_metric_data

    original_df = pd.DataFrame(sample_metric_data)
    original_df.rename(columns={'timestamp': 'ds', 'value': 'y'}, inplace=True)
    original_df['ds'] = pd.to_datetime(original_df['ds'])

    # Create a dummy forecast that shows some anomalies
    forecast_df = original_df.copy()
    forecast_df['yhat'] = forecast_df['y'] * 0.5 # Make prediction lower to trigger anomaly
    forecast_df['yhat_lower'] = forecast_df['y'] * 0.4
    forecast_df['yhat_upper'] = forecast_df['y'] * 0.6

    mock_to_thread.return_value = (original_df, forecast_df)

    # Act
    response = client.post(f"/detect_anomalies/{test_metric}")

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["metric"] == test_metric
    assert data["anomalies_detected"] > 0
    assert "anomalies" in data
    anomaly = data["anomalies"][0]
    assert "timestamp" in anomaly
    assert "actual_value" in anomaly

@patch("main.fetch_metric_data", new_callable=AsyncMock)
def test_detect_anomalies_not_enough_data(mock_fetch_data, sample_metric_data, client):
    """Test /detect_anomalies when there is not enough data."""
    # Arrange
    test_metric = "test_cpu_usage"
    # Return data for less than the training period (e.g., 3 days)
    mock_fetch_data.return_value = sample_metric_data[:72] # 3 days of hourly data

    # Act
    response = client.post(f"/detect_anomalies/{test_metric}")

    # Assert
    assert response.status_code == 404
    assert "Not enough historical data" in response.json()["detail"]
