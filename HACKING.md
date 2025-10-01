# Hacking Guide

This document provides a quick guide to the project's structure, focusing on common Phoenix components.

## Controllers

Controllers handle incoming requests and prepare data for views.
You can find them in:

- `lib/angel_web/controllers/`

## Schemas

Schemas define the structure of your data and how it interacts with the database (using Ecto).
You can find them in:

- `lib/angel/` (for core application schemas, e.g. `Angel.Graphs`, `Angel.Metrics`)
- `lib/angel_web/schemas/` (for web-specific schemas, e.g. `AngelWeb.Schemas.Graph`)

## Views

Views are responsible for rendering the data prepared by controllers into HTML or other formats.
In Phoenix, views are often associated with controllers or LiveViews. You can find them in:

- `lib/angel_web/controllers/` (for traditional HTML views, e.g., `page_html.ex`)
- `lib/angel_web/live/` (for Phoenix LiveView components)

## Chart Data Flow (`/graphs/{metric_name}`)

The interactive chart on the graph detail page has a specific data flow, transforming data from multiple sources into a format suitable for Chart.js.

### 1. Data from the Database (TimescaleDB)

- **Source:** `Angel.Graphs.fetch_timescaledb_data/3`
- **Consumer:** `AngelWeb.IndexLive.Show.fetch_and_push_data/3`
- **Format:** The function returns a list containing a single series map. The `datapoints` are a list of `[value, timestamp]` tuples, where the timestamp is in milliseconds since the Unix epoch.

    ```elixir
    [
      %{
        target: "metric_name",
        datapoints: [
          [1430.0, 1759180860000],
          [1432.5, 1759181160000],
          ...
        ]
      }
    ]
    ```

### 2. Data from the Forecasting Service

- **Source:** `http://forecasting:8000/forecast/{metric_name}` (Python service)
- **Consumer:** `AngelWeb.IndexLive.Show.fetch_forecast_data/1`
- **Format:** The service returns a JSON object containing the forecast predictions. The `forecast_points` are a list of objects, each with a timestamp in ISO 8601 format.

    ```json
    {
      "metric": "metric_name",
      "forecast_points": [
        {
          "timestamp": "2025-09-30T12:00:00",
          "predicted_value": 1450.0,
          "lower_bound": 1420.0,
          "upper_bound": 1480.0
        },
        ...
      ]
    }
    ```

### 3. Final Data Sent to Chart.js

- **Source:** `AngelWeb.IndexLive.Show.fetch_and_push_data/3`
- **Consumer:** `assets/js/app.js` (`ChartHook`)
- **Format:** The LiveView combines the historical and forecast data into a single "columnar" JSON object. It creates a unified timeline (`dates`) and provides corresponding values for each series. If a value doesn't exist for a given timestamp (e.g., no historical data for a forecast timestamp), it uses `null`. This payload is sent to the browser via a `phx:chart:data_loaded` event.

    ```json
    {
      "dates": [1759180860000, 1759181160000, 1759181460000, ...],
      "actual": [1430.0, 1432.5, null, ...],
      "forecast": [null, null, 1450.0, ...],
      "lower_bound": [null, null, 1420.0, ...],
      "upper_bound": [null, null, 1480.0, ...],
      "actual_label": "metric_name",
      "graph_type": "line",
      "min_value": 1000,
      "max_value": 2000
    }
    ```