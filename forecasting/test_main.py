import pytest
from unittest.mock import AsyncMock, patch
from main import app
import main # Import main to access its module-level variables

@pytest.mark.asyncio
async def test_list_available_metrics_unit():
    """Unit test for list_available_metrics function."""
    mock_metrics = ["metric_a", "metric_b", "metric_c"]

    # Patch the new helper function directly
    with patch('main._get_available_metrics_from_db', new_callable=AsyncMock) as mock_get_metrics:
        mock_get_metrics.return_value = mock_metrics
        
        # Import list_available_metrics AFTER the patch is applied
        from main import list_available_metrics

        response = await list_available_metrics()
        
        assert response == {"available_metrics": mock_metrics}
        
        # Verify that the helper function was called
        mock_get_metrics.assert_called_once()

@pytest.mark.asyncio
async def test_health_check():
    """Tests the /health endpoint."""
    import httpx # Import httpx here as it's only needed for this test
    from httpx import ASGITransport
    async with httpx.AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
    
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert response.json()["service"] == "forecasting"
    assert "timestamp" in response.json()

@pytest.mark.asyncio
async def test_forecast_metric_not_found():
    """Tests the /forecast/{metric_name} endpoint when metric is not found."""
    import httpx
    from httpx import ASGITransport
    with patch('main._metric_exists_in_db', new_callable=AsyncMock) as mock_metric_exists:
        mock_metric_exists.return_value = False  # Simulate metric not found
        async with httpx.AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post("/forecast/non_existent_metric")
        
        assert response.status_code == 404
        assert response.json()["detail"] == "Metric 'non_existent_metric' not found."
        mock_metric_exists.assert_called_once_with("non_existent_metric")