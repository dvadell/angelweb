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
    |> IO.inspect(label: :original)
    |> Enum.filter( fn graph -> Map.get(graph, "leaf") == 1 end)
    |> IO.inspect
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Graphs List</h1>
    <ul>
    <%= Enum.map(@graphs, fn g -> %>
    <li>
      <a href={"/graphs/#{Map.get(g, "id")}"}>
        <%= Map.get(g, "id") %>
      </a>
    </li>
    <% end) %>
    </ul>
    """
  end
end
