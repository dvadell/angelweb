"""Tests for the /health endpoint."""

def test_health_check(client):
    """Test the /health endpoint to ensure the service is running."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
