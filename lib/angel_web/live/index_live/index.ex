# http://localhost/render?target=stats.gauges.jr.load_avg&from=-24hours&width=1200&height=400&format=png&title=Load%20Average%20Mordor&vtitle=Load%20Average%20*%20100&yMin=0
defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view

  alias Angel.Graphs
  alias Angel.Graphs.Index

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :graphs, Graphs.list_graphs())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Index")
    |> assign(:index, Graphs.get_index!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Index")
    |> assign(:index, %Index{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Graphs")
    |> assign(:index, nil)
  end

  @impl true
  def handle_info({AngelWeb.IndexLive.FormComponent, {:saved, index}}, socket) do
    {:noreply, stream_insert(socket, :graphs, index)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    index = Graphs.get_index!(id)
    {:ok, _} = Graphs.delete_index(index)

    {:noreply, stream_delete(socket, :graphs, index)}
  end
end
