defmodule AngelWeb.IndexLive.Show do
  use AngelWeb, :live_view
  alias Angel.Graphs
  alias Jason
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => graph_name}, _session, socket) do
    graph =
      Graphs.get_by_short_name(graph_name) ||
        %Angel.Graphs.Index{short_name: graph_name, title: "", notes: ""}

    # Create the form changeset
    changeset = Angel.Graphs.Index.changeset(graph, %{})

    if connected?(socket), do: Phoenix.PubSub.subscribe(Angel.PubSub, "new_metric:#{graph_name}")

    {:ok,
     socket
     |> assign(:events, Angel.Events.for_graph(graph_name))
     |> assign(:graph_name, graph_name)
     |> assign(:graph, graph)
     |> assign(:form, to_form(changeset))
     |> assign(:show_form, false)
     |> assign(:show_events, false)
     |> assign(:show_notes, false)
     |> assign(:chart_is_playing, true)}
  end

  @impl true
  def handle_event("get_initial_data", _params, socket) do
    graph_name = socket.assigns.graph_name

    end_time = DateTime.utc_now()
    # 24 hours
    start_time = DateTime.add(end_time, -86_400, :second)

    case Angel.Graphs.fetch_timescaledb_data(graph_name, start_time, end_time) do
      {:ok, data} ->
        graph = socket.assigns.graph
        min_value = graph.min_value
        max_value = graph.max_value
        graph_type = graph.graph_type

        updated_data =
          Enum.map(data, fn item ->
            Map.merge(item, %{min_value: min_value, max_value: max_value, graph_type: graph_type})
          end)

        {:noreply, push_event(socket, "chart:data_loaded", %{data: updated_data})}

      {:error, _e} ->
        # Send empty data structure on error
        graph = socket.assigns.graph
        min_value = graph.min_value
        max_value = graph.max_value
        graph_type = graph.graph_type

        empty_data = [
          %{datapoints: [], target: graph_name, min_value: min_value, max_value: max_value, graph_type: graph_type}
        ]

        {:noreply, push_event(socket, "chart:data_loaded", %{data: empty_data})}
    end
  end

  @impl true
  def handle_event("validate", %{"index" => graph_params}, socket) do
    changeset =
      socket.assigns.graph
      |> Angel.Graphs.Index.changeset(graph_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("toggle_form", _, socket) do
    {:noreply, assign(socket, :show_form, not socket.assigns.show_form)}
  end

  @impl true
  def handle_event("toggle_events", _, socket) do
    {:noreply, assign(socket, :show_events, not socket.assigns.show_events)}
  end

  @impl true
  def handle_event("toggle_notes", _, socket) do
    {:noreply, assign(socket, :show_notes, not socket.assigns.show_notes)}
  end

  @impl true
  def handle_event("toggle_chart_play", _, socket) do
    {:noreply, assign(socket, :chart_is_playing, not socket.assigns.chart_is_playing)}
  end

  @impl true
  def handle_event("save", %{"index" => graph_params}, socket) do
    # Add the short_name to the params since it's needed for save
    graph_params = Map.put(graph_params, "short_name", socket.assigns.graph_name)

    case Graphs.create_or_update_graph(graph_params) do
      {:ok, graph} ->
        # Update both the graph and create a new clean form
        changeset = Angel.Graphs.Index.changeset(graph, graph_params)

        {:noreply,
         socket
         |> assign(:graph, graph)
         |> assign(:form, to_form(changeset))
         |> assign(:show_form, false)
         |> put_flash(:info, "Graph saved successfully!")}

      {:error, changeset} ->
        # Show validation errors in the form
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event(
        "get_more_data",
        %{"start_time" => start_time_str, "end_time" => end_time_str},
        socket
      ) do
    with {:ok, start_time, _} <- DateTime.from_iso8601(start_time_str),
         {:ok, end_time, _} <- DateTime.from_iso8601(end_time_str) do
      graph_name = socket.assigns.graph_name

      case Angel.Graphs.fetch_timescaledb_data(graph_name, start_time, end_time) do
        {:ok, new_data} ->
          graph = socket.assigns.graph
          min_value = graph.min_value
          max_value = graph.max_value
          graph_type = graph.graph_type

          updated_data =
            Enum.map(new_data, fn item ->
              Map.merge(item, %{min_value: min_value, max_value: max_value, graph_type: graph_type})
            end)

          {:noreply, push_event(socket, "chart:data_loaded", %{data: updated_data})}

        {:error, _e} ->
          {:noreply, socket}
      end
    else
      _error ->
        {:noreply, socket}
    end
  end

  # Handle pan/zoom events from the chart
  @impl true
  def handle_event(
        "chart_zoomed",
        %{"visible_range" => %{"min" => min_ms, "max" => max_ms}, "zoom_level" => level},
        socket
      ) do
    # Convert milliseconds to DateTime
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)

    # If zoomed in significantly (showing less than 6 hours), load higher resolution data
    time_span_hours = DateTime.diff(max_time, min_time, :hour)

    # Add small buffer for zoomed data
    # 5 minutes buffer
    buffer_seconds = 300
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)

    graph_name = socket.assigns.graph_name

    case Angel.Graphs.fetch_timescaledb_data(graph_name, expanded_min, expanded_max) do
      {:ok, new_data} ->
        graph = socket.assigns.graph
        min_value = graph.min_value
        max_value = graph.max_value
        graph_type = graph.graph_type

        updated_data =
          Enum.map(new_data, fn item ->
            Map.merge(item, %{min_value: min_value, max_value: max_value, graph_type: graph_type})
          end)

        {:noreply, push_event(socket, "chart:data_loaded", %{data: updated_data})}

      {:error, error} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "chart_panned",
        %{"visible_range" => %{"min" => min_ms, "max" => max_ms}},
        socket
      ) do
    # Convert milliseconds to DateTime
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)

    # Add some buffer around the visible range to preload data
    # 1 hour buffer on each side
    buffer_seconds = 3600
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)

    graph_name = socket.assigns.graph_name

    case Angel.Graphs.fetch_timescaledb_data(graph_name, expanded_min, expanded_max) do
      {:ok, new_data} ->
        graph = socket.assigns.graph
        min_value = graph.min_value
        max_value = graph.max_value
        graph_type = graph.graph_type

        updated_data =
          Enum.map(new_data, fn item ->
            Map.merge(item, %{min_value: min_value, max_value: max_value, graph_type: graph_type})
          end)

        {:noreply, push_event(socket, "chart:data_loaded", %{data: updated_data})}

      {:error, error} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_metric, metric, timestamp}, socket) do
    if socket.assigns.chart_is_playing do
      # Push the new data point to the client
      {:noreply,
       push_event(socket, "chart:new_data", %{
         value: metric.graph_value,
         timestamp: DateTime.to_unix(timestamp, :millisecond)
       })}
    else
      {:noreply, socket}
    end
  end
end
