# Hacking Guide

This document provides a quick guide to the project's structure, focusing on common Phoenix components.

## Controllers

Controllers handle incoming requests and prepare data for views.
You can find them in:

- `lib/angel_web/controllers/`

## Schemas

Schemas define the structure of your data and how it interacts with the database (using Ecto).
You can find them in:

- `lib/angel/` (for core application schemas)
- `lib/angel_web/schemas/` (for web-specific schemas, if any)

## Views

Views are responsible for rendering the data prepared by controllers into HTML or other formats.
In Phoenix, views are often associated with controllers or LiveViews. You can find them in:

- `lib/angel_web/controllers/` (for traditional HTML views, e.g., `page_html.ex`)
- `lib/angel_web/live/` (for Phoenix LiveView components)
