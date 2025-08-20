# Angel

To start your Phoenix server:

  * If using Docker Compose, run commands inside the `web` container (e.g., `docker compose exec web mix setup`).
  * Run `mix setup` to install and setup dependencies.
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To test it with curl

```
  curl -X POST "http://localhost:4000/api/v1/metric" -H "Content-Type: application/json" -d '{
  "short_name": "example_metric",
  "graph_value": 43,
  "reporter": "dummy_reporter"
}'
```

## Running tests
```
docker compose run -e MIX_ENV=test web mix reset
docker compose run -e MIX_ENV=test web mix test
```

## Web Interface

### `GET /graphs`

*   **Description**: A web interface for displaying stored metric graphs. It provides a visual representation of the collected data, including the status of each graph (e.g., whether the latest metric value is within the defined min/max range). This is a Phoenix LiveView page.

## API Endpoints

This project exposes the following API endpoints:

### `POST /api/v1/metric`

*   **Description**: This endpoint is used for receiving and storing metric measurements.
*   **Method**: `POST`
*   **Content-Type**: `application/json`
*   **Request Body Example**:
    ```json
    {
      "short_name": "example_metric",
      "value": 43
    }
    ```

### `GET /api/v1/graphs/:name`

*   **Description**: This endpoint is used for fetching metric data for a specific graph within a time range.
*   **Method**: `GET`
*   **URL Parameters**:
    *   `name`: The short name of the graph.
*   **Query Parameters**:
    *   `start_time`: The start of the time range in ISO8601 format (e.g., `2023-01-01T00:00:00Z`).
    *   `end_time`: The end of the time range in ISO8601 format (e.g., `2023-01-02T00:00:00Z`).
*   **Example Request**:
    ```
    GET /api/v1/graphs/example_metric?start_time=2023-01-01T00:00:00Z&end_time=2023-01-02T00:00:00Z
    ```

To "deploy" see https://dev.to/hlappa/development-environment-for-elixir-phoenix-with-docker-and-docker-compose-2g17
