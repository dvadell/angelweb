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
docker compose run web /bin/bash
MIX_ENV=test mix reset
MIX_ENV=test mix test
```

## API Endpoints

This project exposes two main API endpoints:

### `POST /api/v1/metric`

*   **Description**: This endpoint is used for receiving and storing metric measurements.
*   **Method**: `POST`
*   **Content-Type**: `application/json`
*   **Request Body Example**:
    ```json
    {
      "short_name": "example_metric",
      "graph_value": 43,
      "reporter": "dummy_reporter"
    }
    ```

### `GET /graphs`

*   **Description**: This endpoint is used for displaying the stored metric graphs. It provides a visual representation of the collected data.
*   **Method**: `GET`

To "deploy" see https://dev.to/hlappa/development-environment-for-elixir-phoenix-with-docker-and-docker-compose-2g17
