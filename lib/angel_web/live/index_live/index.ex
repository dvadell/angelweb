defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :graphs, list_graphs())}
  end

  defp list_graphs() do
    url = "http://localhost:80/metrics/find?query=stats.gauges.jr.*"
    response = HTTPoison.get!(url)
    Jason.decode!(response.body)
    |> Enum.filter( fn graph -> Map.get(graph, "leaf") == 1 end)
  end
end
