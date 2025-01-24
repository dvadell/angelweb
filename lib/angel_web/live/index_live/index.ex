defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :graphs, list_graphs())}
  end

  defp list_graphs() do
    graphite_host = 
      Application.get_env(:angel, AngelWeb.MetricController, [graphite_host: "localhost", graphite_port: 8125])
      |> Keyword.get(:graphite_host)

    url = "http://#{graphite_host}/metrics/find?query=stats.gauges.jr.*"
    response = HTTPoison.get!(url)
    Jason.decode!(response.body)
    |> Enum.filter( fn graph -> Map.get(graph, "leaf") == 1 end)
  end
end
