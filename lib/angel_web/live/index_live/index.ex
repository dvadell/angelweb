defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view
  alias Angel.Graphs

  @impl true
  def mount(_params, _session, socket) do
    graphs = list_graphs()

    {:ok,
     socket
     |> assign(:graphs, graphs)
     |> assign(:filtered_graphs, graphs)
     |> assign(:filter, nil)}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    graphs = socket.assigns.graphs
    filtered_graphs = filter_graphs(graphs, q)

    socket =
      socket
      |> assign(:filtered_graphs, filtered_graphs)
      |> assign(:filter, q)

    {:noreply, socket}
  end

  defp list_graphs do
    Graphs.list_graphs()
  end

  defp filter_graphs(graphs, nil) do
    graphs
  end

  defp filter_graphs(graphs, filter) do
    graphs
    |> Enum.filter(fn g ->
      String.contains?(g.short_name, filter)
    end)
  end
end
