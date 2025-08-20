
# Database Schema

This document provides an overview of the database schema used in the Angel project.

The database schema is defined in the following files:
- `lib/angel/graphs.ex`
- `lib/angel/events/event.ex`
- `lib/angel/metrics.ex`

## Tables

### `graphs`

The `graphs` table stores information about the graphs that can be displayed.

+------------|-----------------|-------------------------------------------+
| Column     | Type            | Purpose                                   |
+------------|-----------------|-------------------------------------------+
| id         | bigserial (PK)  | Unique identifier for each graph.         |
| short_name | string          | A short, descriptive name for the graph   |
|            |                 |  (e.g., "backup_time").                   |
| units      | string          | The units for the values being graphed    |
|            |                 | (e.g., "seconds", "requests/second").     |
| title      | string          | The title of the graph.                   |
| notes      | string          | Notes about the graph.                    |
| min        | float           | The minimum acceptable value for a metric.|
| max        | float           | The maximum acceptable value for a metric.|
| graph_type | string          | The type of graph to display.             |
| inserted_at| utc_datetime    | Timestamp of when the record was created. |
| updated_at | utc_datetime    | Timestamp of when the record was last     |
|            |                 |                                  updated. |
+------------|-----------------|-------------------------------------------+

### `events`

The `events` table stores events that can be displayed on the graphs.

+------------|-----------------|-------------------------------------------+
| Column     | Type            | Purpose                                   |
|------------|-----------------|-------------------------------------------+
| id         | bigserial (PK)  | Unique identifier for each event.         |
| text       | string          | A description of the event (e.g.,         |
|            |                 | "Backup completed successfully").         |
| for_graph  | string          | The `short_name` of the graph this event  |
|            |                 | belongs to.                               |
| inserted_at| utc_datetime    | Timestamp of when the record was created. |
| updated_at | utc_datetime    | Timestamp of when the record was last     |
|            |                 |                                  updated. |
+------------|-----------------|-------------------------------------------+

### `metrics`

The `metrics` table stores the time-series data for the graphs.

+------------|-----------------|-------------------------------------------+
| Column     | Type            | Purpose                                   |
|------------|-----------------|-------------------------------------------+
| timestamp  | utc_datetime    | The timestamp of the metric.              |
| value      | float           | The value of the metric.                  |
| short_name | string          | The `short_name` of the graph this metric |
|            |                 | belongs to.                               |
+------------|-----------------|-------------------------------------------+

