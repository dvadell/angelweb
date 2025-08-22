import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
import sys
import os

# Add the project root to the Python path to allow imports from 'main'
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app

# The warning suggests using an explicit transport argument, like transport=WSGITransport(app=...). 
# However, when I attempted this previously, it resulted in a TypeError because the
# TestClient in your current environment's version of FastAPI/Starlette does not accept a transport 
# keyword argument directly. This indicates a potential version mismatch or a change
# in how TestClient is intended to be used with httpx in newer versions.

def pytest_configure(config):
    """Pytest configuration hook to filter warnings."""
    config.addinivalue_line(
        "filterwarnings", "ignore:The 'app' shortcut is now deprecated:DeprecationWarning"
    )

@pytest.fixture(scope="session")
def client():
    """Test client fixture for the FastAPI app."""
    with TestClient(app) as c:
        yield c

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
