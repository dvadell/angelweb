# Angel

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To test it with curl

```
  curl -X POST "http://localhost:4000/api/v1/metric" -H "Content-Type: application/json" -d '{
  "short_name": "example_metric",
  "graph_value": 43,
  "reporter": "dummy_reporter"
}'
```

To "deploy" see https://dev.to/hlappa/development-environment-for-elixir-phoenix-with-docker-and-docker-compose-2g17
