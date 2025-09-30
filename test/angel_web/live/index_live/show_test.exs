defmodule AngelWeb.IndexLive.ShowTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  # Define a behaviour for our HTTP client. This is what Mox will mock.
  defmodule HTTPClientBehaviour do
    @callback post(url :: String.t(), body :: String.t(), headers :: list()) ::
                {:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}
  end

  # Define the mock based on the behaviour
  Mox.defmock(HTTPoison.Mock, for: HTTPClientBehaviour)

  setup do
    # Configure the application to use our mocks instead of the real modules
    # for the duration of this test.
    Application.put_env(:angel, :http_client, HTTPoison.Mock)
    Application.put_env(:angel, :graphs, Angel.Graphs.Mock)
    Application.put_env(:angel, :events, Angel.Events.Mock)
    Application.put_env(:angel, :junior, Angel.Junior.Mock)

    # The on_exit callback ensures the configuration is restored after the test.
    on_exit(fn ->
      Application.delete_env(:angel, :http_client)
      Application.delete_env(:angel, :graphs)
      Application.delete_env(:angel, :events)
      Application.delete_env(:angel, :junior)
    end)

    :ok
  end

  describe "Forecasting Feature" do
    test "sends combined historical and forecast data on successful fetch", %{conn: conn} do
      graph_name = "test_metric"
      graph = %Angel.Graphs.Index{short_name: graph_name, title: "Test Graph", graph_type: "line"}

      # Stub trace calls. The `trace` function is used to wrap other functions,
      # but is also called by telemetry with non-function arguments. This stub
      # handles both cases, preventing the test process from crashing on exit.
      stub(Angel.Junior.Mock, :trace, fn _trace_name, val ->
        if is_function(val, 0) do
          val.()
        else
          val
        end
      end)

      # Mock calls made during mount. They are called twice: once for the initial
      # static render and once for the connected LiveView.
      expect(Angel.Graphs.Mock, :get_by_short_name, 2, fn _graph_name -> graph end)
      expect(Angel.Graphs.Mock, :count_metrics, 2, fn _metric_count_arg -> 100 end)
      expect(Angel.Graphs.Mock, :first_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Graphs.Mock, :last_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Events.Mock, :for_graph, 2, fn _graph_arg -> [] end)

      # Mock the database call for the event
      historical_timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      historical_data = [%{target: graph_name, datapoints: [[100, historical_timestamp]]}]

      expect(Angel.Graphs.Mock, :fetch_timescaledb_data, fn _graph_name_arg, _start_time_arg, _end_time_arg ->
        {:ok, historical_data}
      end)

      # Mock the forecast service call
      forecast_timestamp = DateTime.utc_now() |> DateTime.add(3600, :second)
      forecast_iso = forecast_timestamp |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      forecast_points = [
        %{
          "timestamp" => forecast_iso,
          "predicted_value" => 110,
          "lower_bound" => 105,
          "upper_bound" => 115
        }
      ]

      forecast_response_body = Jason.encode!(%{"forecast_points" => forecast_points})

      expect(HTTPoison.Mock, :post, fn _url, _body, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: forecast_response_body}}
      end)

      # Mount the LiveView. The `mounted` hook will trigger the data fetch.
      {:ok, _live_view_module, _html_content} = live(conn, "/graphs/#{graph_name}")

      # Assert that the event was pushed and capture the payload
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: data}}}

      assert data[:actual_label] == graph_name
      # One historical, one forecast
      assert length(data[:dates]) == 2

      # The historical point should be present, forecast should be nil
      assert Enum.at(data[:actual], 0) == 100
      assert Enum.at(data[:forecast], 0) == nil

      # The forecast point should be present, historical should be nil
      assert Enum.at(data[:actual], 1) == nil
      assert Enum.at(data[:forecast], 1) == 110
      assert Enum.at(data[:lower_bound], 1) == 105
      assert Enum.at(data[:upper_bound], 1) == 115
    end

    test "sends only historical data when forecast service fails", %{conn: conn} do
      graph_name = "test_metric_http_error"
      graph = %Angel.Graphs.Index{short_name: graph_name, title: "Test Graph", graph_type: "line"}

      # Stub trace calls. The `trace` function is used to wrap other functions,
      # but is also called by telemetry with non-function arguments. This stub
      # handles both cases, preventing the test process from crashing on exit.
      stub(Angel.Junior.Mock, :trace, fn _trace_name, val ->
        if is_function(val, 0) do
          val.()
        else
          val
        end
      end)

      # Mock calls made during mount. They are called twice: once for the initial
      # static render and once for the connected LiveView.
      expect(Angel.Graphs.Mock, :get_by_short_name, 2, fn _graph_name -> graph end)
      expect(Angel.Graphs.Mock, :count_metrics, 2, fn _metric_count_arg -> 100 end)
      expect(Angel.Graphs.Mock, :first_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Graphs.Mock, :last_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Events.Mock, :for_graph, 2, fn _graph_arg -> [] end)

      # Mock the database call for the event
      historical_timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      historical_data = [%{target: graph_name, datapoints: [[100, historical_timestamp]]}]

      expect(Angel.Graphs.Mock, :fetch_timescaledb_data, fn _graph_name_arg, _start_time_arg, _end_time_arg ->
        {:ok, historical_data}
      end)

      # Mock the forecast service to return an error
      expect(HTTPoison.Mock, :post, fn _url, _body, _headers -> {:error, %HTTPoison.Error{reason: :econnrefused}} end)

      # Mount the LiveView. The `mounted` hook will trigger the data fetch.
      {:ok, _live_view_module, _html_content} = live(conn, "/graphs/#{graph_name}")

      # Assert that the event was pushed and capture the payload
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: data}}}

      assert data[:actual_label] == graph_name
      # Only the historical point
      assert length(data[:dates]) == 1
      assert data[:actual] == [100]
      assert data[:forecast] == [nil]
      assert data[:lower_bound] == [nil]
      assert data[:upper_bound] == [nil]
    end
  end
end
