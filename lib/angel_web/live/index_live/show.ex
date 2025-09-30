defmodule AngelWeb.IndexLive.Show do
  use AngelWeb, :live_view
  alias Angel.Graphs
  alias Angel.Graphs.Index
  alias Angel.Junior
  alias Jason

  require Logger

  @impl true
  def mount(%{"id" => graph_name}, _session, socket) do
    graph =
      Graphs.get_by_short_name(graph_name) ||
        %Index{short_name: graph_name, title: "", notes: ""}

    # Create the form changeset
    changeset = Index.changeset(graph, %{})

    if connected?(socket), do: Phoenix.PubSub.subscribe(Angel.PubSub, "new_metric:#{graph_name}")

    metrics_count = Graphs.count_metrics(graph_name)
    first_metric_at = Graphs.first_metric_timestamp(graph_name)
    last_metric_at = Graphs.last_metric_timestamp(graph_name)

    {:ok,
     socket
     |> assign(:events, Angel.Events.for_graph(graph_name))
     |> assign(:graph_name, graph_name)
     |> assign(:graph, graph)
     |> assign(:form, to_form(changeset))
     |> assign(:show_form, false)
     |> assign(:show_events, false)
     |> assign(:show_notes, false)
     |> assign(:show_debug, false)
     |> assign(:metrics_count, metrics_count)
     |> assign(:first_metric_at, first_metric_at)
     |> assign(:last_metric_at, last_metric_at)
     |> assign(:chart_is_playing, true)}
  end

  @impl true
  def handle_event("get_initial_data", _params, socket) do
    end_time = DateTime.utc_now()
    # 24 hours
    start_time = DateTime.add(end_time, -86_400, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("validate", %{"index" => graph_params}, socket) do
    changeset =
      socket.assigns.graph
      |> Index.changeset(graph_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, :show_form, not socket.assigns.show_form)}
  end

  @impl true
  def handle_event("toggle_events", _params, socket) do
    {:noreply, assign(socket, :show_events, not socket.assigns.show_events)}
  end

  @impl true
  def handle_event("toggle_notes", _params, socket) do
    {:noreply, assign(socket, :show_notes, not socket.assigns.show_notes)}
  end

  @impl true
  def handle_event("toggle_debug", _params, socket) do
    {:noreply, assign(socket, :show_debug, not socket.assigns.show_debug)}
  end

  @impl true
  def handle_event("toggle_chart_play", _params, socket) do
    {:noreply, assign(socket, :chart_is_playing, not socket.assigns.chart_is_playing)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "hour"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -3600, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "day"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -86_400, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "week"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -604_800, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "month"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -2_592_000, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("save", %{"index" => graph_params}, socket) do
    # Add the short_name to the params since it's needed for save
    graph_params = Map.put(graph_params, "short_name", socket.assigns.graph_name)
    graph_params = Map.update(graph_params, "notes", "", &HtmlSanitizeEx.markdown_html/1)

    case Graphs.create_or_update_graph(graph_params) do
      {:ok, graph} ->
        # Update both the graph and create a new clean form
        changeset = Index.changeset(graph, graph_params)

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
    with {:ok, start_time, _utc_offset} <- DateTime.from_iso8601(start_time_str),
         {:ok, end_time, _utc_offset} <- DateTime.from_iso8601(end_time_str) do
      graph_name = socket.assigns.graph_name

      case Junior.trace("angel_graphs_fetch_timescaledb_data", fn ->
             Angel.Graphs.fetch_timescaledb_data(graph_name, start_time, end_time)
           end) do
        {:ok, new_data} ->
          graph = socket.assigns.graph
          min_value = graph.min_value
          max_value = graph.max_value
          graph_type = graph.graph_type

          updated_data =
            Enum.map(new_data, fn item ->
              Map.merge(item, %{
                min_value: min_value,
                max_value: max_value,
                graph_type: graph_type
              })
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
        %{"visible_range" => %{"min" => min_ms, "max" => max_ms}, "zoom_level" => _level},
        socket
      ) do
    # Convert milliseconds to DateTime
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)

    # Add small buffer for zoomed data
    # 5 minutes buffer
    buffer_seconds = 300
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)

    graph_name = socket.assigns.graph_name

    case Junior.trace("angel_graphs_fetch_timescaledb_data", fn ->
           Angel.Graphs.fetch_timescaledb_data(graph_name, expanded_min, expanded_max)
         end) do
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

      {:error, _error} ->
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

    case Junior.trace("angel_graphs_fetch_timescaledb_data", fn ->
           Angel.Graphs.fetch_timescaledb_data(graph_name, expanded_min, expanded_max)
         end) do
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

      {:error, _error} ->
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

  defp fetch_and_push_data(socket, start_time, end_time) do
    graph_name = socket.assigns.graph_name

    case Junior.trace("angel_graphs_fetch_timescaledb_data", fn ->
           Angel.Graphs.fetch_timescaledb_data(graph_name, start_time, end_time)
         end) do
      {:ok, data} ->
        # Fetch forecast data, defaulting to an empty list on failure.
        forecast_points =
          case fetch_forecast_data(graph_name) do
            {:ok, points} ->
              Logger.info("Successfully fetched forecast data for #{graph_name}")
              points

            {:error, reason} ->
              Logger.error("Failed to fetch forecast data for #{graph_name}: #{inspect(reason)}")
              []
          end

        # The main data series from the database is the first element in the `data` list.
        actual_series = List.first(data)

        # Create a map of {timestamp => value} for quick lookups from the historical data.
        actual_map =
          Enum.into(actual_series.datapoints, %{}, fn [value, timestamp] -> {timestamp, value} end)

        # Create maps for the forecast data from the (potentially empty) forecast_points list.
        forecast_maps =
          Enum.reduce(forecast_points, %{predicted: %{}, lower: %{}, upper: %{}}, fn point, acc ->
            {:ok, dt, 0} = DateTime.from_iso8601(point["timestamp"] <> "Z")
            timestamp = DateTime.to_unix(dt, :millisecond)

            predicted_map = Map.put(acc.predicted, timestamp, point["predicted_value"])
            lower_map = Map.put(acc.lower, timestamp, point["lower_bound"])
            upper_map = Map.put(acc.upper, timestamp, point["upper_bound"])

            %{predicted: predicted_map, lower: lower_map, upper: upper_map}
          end)

        # Create a single, sorted, unique timeline from all available timestamps.
        all_timestamps =
          (Map.keys(actual_map) ++ Map.keys(forecast_maps.predicted))
          |> Enum.uniq()
          |> Enum.sort()

        # Get graph metadata from the socket assigns.
        graph = socket.assigns.graph

        # Construct the final payload in the new columnar format.
        payload = %{
          dates: all_timestamps,
          actual: Enum.map(all_timestamps, &Map.get(actual_map, &1)),
          forecast: Enum.map(all_timestamps, &Map.get(forecast_maps.predicted, &1)),
          lower_bound: Enum.map(all_timestamps, &Map.get(forecast_maps.lower, &1)),
          upper_bound: Enum.map(all_timestamps, &Map.get(forecast_maps.upper, &1)),
          actual_label: actual_series.target,
          graph_type: graph.graph_type,
          min_value: graph.min_value,
          max_value: graph.max_value
        }

        push_event(socket, "chart:data_loaded", %{data: payload})

      {:error, _e} ->
        # Send empty data structure on error
        graph = socket.assigns.graph
        min_value = graph.min_value
        max_value = graph.max_value
        graph_type = graph.graph_type

        empty_data = [
          %{
            datapoints: [],
            target: graph_name,
            min_value: min_value,
            max_value: max_value,
            graph_type: graph_type
          }
        ]

        push_event(socket, "chart:data_loaded", %{data: empty_data})
    end
  end

  defp fetch_forecast_data(graph_name) do
    url = "http://forecasting:8000/forecast/#{graph_name}"
    body = Jason.encode!(%{"hours_ahead" => 24, "confidence_interval" => 0.95})
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"forecast_points" => points}} ->
            {:ok, points}

          _ ->
            {:error, :json_parsing}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
