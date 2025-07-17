
# Database Schema

This document provides an overview of the database schema used in the Angel project.

The database schema is defined in the following files:
- `lib/angel/graphs/index.ex`
- `lib/angel/events/event.ex`

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

