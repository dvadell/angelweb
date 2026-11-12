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
mix format
mix credo
mix dialyzer
mix sobelow --skip
MIX_ENV=test mix test
```

## CI/CD

`.github/workflows/ci.yml` runs on every push and pull request to `main`:

* **Lint**: `mix format --check-formatted`, `mix credo`, `mix dialyzer`, `mix sobelow --skip`
* **Test**: `mix test` against a TimescaleDB service container
* **Docker** (pushes to `main` only, after lint and tests pass): builds `Dockerfile.prod`
  and pushes it to `ghcr.io/dvadell/angelweb`, tagged `latest` and `sha-<commit>`.
* **Forecasting**: builds `forecasting/Dockerfile`, runs `pytest` inside the image against
  TimescaleDB, and on pushes to `main` pushes it to `ghcr.io/dvadell/angelweb-forecasting`
  with the same tags.

`Dockerfile.prod` builds a Mix release. The container runs the migrations on start. To run it:

```
docker run -p 4000:4000 \
  -e DATABASE_URL=ecto://postgres:postgres@db/angel \
  -e SECRET_KEY_BASE=<mix phx.gen.secret> \
  -e PHX_HOST=localhost \
  -e FRONTEND_URL=http://localhost:4000 \
  ghcr.io/dvadell/angelweb:latest
```

The plain `Dockerfile` is the development image used by `docker compose`.

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

To "deploy" see https://dev.to/hlappa/development-environment-for-elixir-phoenix-with-docker-and-docker-compose-2g17
