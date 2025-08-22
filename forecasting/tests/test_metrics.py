"""Tests for the /metrics endpoint."""

from unittest.mock import patch, AsyncMock

@patch("main._get_available_metrics_from_db", new_callable=AsyncMock)
def test_list_available_metrics(mock_get_available_metrics, client):
    """Test the /metrics endpoint that lists available metrics."""
    # Arrange: Set up the mock to return a predefined list of metrics.
    expected_metrics = ["cpu", "ram", "disk"]
    mock_get_available_metrics.return_value = expected_metrics

    # Act: Call the endpoint.
    response = client.get("/metrics")

    # Assert: Check that the response is successful and contains the expected data.
    assert response.status_code == 200
    assert response.json() == {"available_metrics": expected_metrics}
