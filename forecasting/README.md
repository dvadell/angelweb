# Forecasting Microservice

This microservice provides time series forecasting and anomaly detection capabilities for server metrics. It is built with FastAPI and integrates with TimescaleDB for historical data storage.

## Project Structure

```
forecasting/
├── Dockerfile
├── main.py
├── requirements.txt
└── test_main.py
```

## Features

- **Health Check**: `/health` endpoint to verify service status.
- **List Available Metrics**: `/metrics` endpoint to retrieve a list of metrics available for forecasting from TimescaleDB.
- **Forecasting**: `/forecast/{metric_name}` endpoint (TODO: implementation details).
- **Anomaly Detection**: `/detect_anomalies/{metric_name}` endpoint (TODO: implementation details).

## Setup and Running

This service is designed to run as part of a larger `docker-compose` setup, alongside a TimescaleDB instance.

1.  **Prerequisites**:
    *   Docker and Docker Compose installed on your system.

2.  **Environment Variables**:
    The service requires a `DATABASE_URL` environment variable to connect to TimescaleDB. This is typically provided via a `.env` file or directly in `docker-compose.yml`.

    Example `DATABASE_URL` (as seen in `docker-compose.yml`):
    `postgresql://postgres:postgres@timescaledb:5432/angel`

3.  **Building and Running with Docker Compose**:
    Navigate to the root directory of the project (where `docker-compose.yml` is located) and run:

    ```bash
    docker compose up --build forecasting
    ```

    This command will:
    *   Build the `forecasting` service Docker image based on `forecasting/Dockerfile`.
    *   Start the `db` service (TimescaleDB) if it's not already running.
    *   Start the `forecasting` service, connecting it to the `db` service.

    The forecasting service will be accessible on port `8000` inside the Docker network.

## Testing

Tests for the forecasting microservice are written using `pytest` and can be run within the Docker environment.

1.  **Ensure the service image is built**:

    ```bash
    docker compose build forecasting
    ```

2.  **Run the tests**:

    ```bash
    docker compose run forecasting pytest test_main.py
    ```

    This command will:
    *   Start a new container for the `forecasting` service.
    *   Execute `pytest` to run all tests defined in `test_main.py`.

    To run a specific test (e.g., `test_list_available_metrics_unit`):

    ```bash
    docker compose run forecasting pytest -v test_main.py::test_list_available_metrics_unit
    ```

## API Endpoints

-   **GET /health**
    *   **Description**: Health check endpoint for Docker/Phoenix to verify service is running.
    *   **Response**: `{"status": "healthy", "service": "forecasting", "timestamp": "<current_datetime>"}`

-   **GET /metrics**
    *   **Description**: Returns a list of metrics available for forecasting.
    *   **Response**: `{"available_metrics": ["metric_name_1", "metric_name_2", ...]}`

-   **POST /forecast/{metric_name}**
    *   **Description**: Main forecasting endpoint (TODO: details).

-   **POST /detect_anomalies/{metric_name}**
    *   **Description**: Anomaly detection endpoint (TODO: details).
