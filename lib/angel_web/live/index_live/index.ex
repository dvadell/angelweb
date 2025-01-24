defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :graphs, list_graphs())}
  end

  defp list_graphs() do
    graphite_host = 
      Application.get_env(:angel, AngelWeb.MetricController, [graphite_host: {127, 0, 0, 1}, graphite_port: 8125])
      |> Keyword.get(:graphite_host)
      |> Tuple.to_list 
      |> Enum.join(".")

    url = "http://#{graphite_host}/metrics/find?query=stats.gauges.jr.*"
    response = HTTPoison.get!(url)
    Jason.decode!(response.body)
    |> Enum.filter( fn graph -> Map.get(graph, "leaf") == 1 end)
  end
end
