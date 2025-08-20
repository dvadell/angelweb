defmodule AngelWeb.MetricControllerTest do
  use AngelWeb.ConnCase

  test "create returns 201 for valid metric data", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{
                                            "short_name" => "test.metric",
                                            "units" => "gauge",
                                            "min_value" => nil,
                                            "max_value" => nil
                                          } ->
      {:ok, %{short_name: "test.metric", units: "gauge"}}
    end)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: "test.metric", text: "Value: 123 g"} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         ["test.metric", 123] ->
      {:ok, %{}}
    end)

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: "test.metric",
        graph_value: 123,
        type: "g",
        reporter: "test_reporter"
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "create returns 201 for valid metric data with min_value and max_value", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{
                                            "short_name" => "test.metric",
                                            "units" => "gauge",
                                            "min_value" => 0.0,
                                            "max_value" => 100.0
                                          } ->
      {:ok, %{short_name: "test.metric", units: "gauge"}}
    end)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: "test.metric", text: "Value: 123 g"} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         ["test.metric", 123] ->
      {:ok, %{}}
    end)

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: "test.metric",
        graph_value: 123,
        type: "g",
        reporter: "test_reporter",
        min_value: 0.0,
        max_value: 100.0
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "create returns 400 for missing short_name", %{conn: conn} do
    conn = post(conn, "/api/v1/metric", %{graph_value: 123, type: "g", reporter: "test_reporter"})
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for missing graph_value", %{conn: conn} do
    conn =
      post(conn, "/api/v1/metric", %{
        short_name: "test.metric",
        type: "g",
        reporter: "test_reporter"
      })

    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 201 for missing reporter", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{"short_name" => "test.metric", "units" => "g"} ->
      {:ok, %{short_name: "test.metric", units: "g"}}
    end)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: "test.metric", text: "Value: 123 g"} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         ["test.metric", 123] ->
      {:ok, %{}}
    end)

    conn = post(conn, "/api/v1/metric", %{short_name: "test.metric", graph_value: 123, type: "g"})
    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "create returns 400 for negative graph_value", %{conn: conn} do
    conn =
      post(conn, "/api/v1/metric", %{
        short_name: "test.metric",
        graph_value: -1,
        type: "g",
        reporter: "test_reporter"
      })

    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for invalid type", %{conn: conn} do
    conn =
      post(conn, "/api/v1/metric", %{
        short_name: "test.metric",
        graph_value: 123,
        type: "invalid",
        reporter: "test_reporter"
      })

    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for non-JSON content type", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/v1/metric", "this is not json")

    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for invalid metric data", %{conn: conn} do
    # Send empty map to trigger invalid data path
    conn = post(conn, "/api/v1/metric", %{})
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "ingested data is persisted in the database", %{conn: conn} do
    # Do not mock Angel.Repo for this test to verify actual persistence
    # Mox.verify! is called automatically at the end of each test

    short_name = "test.metric.persisted"
    graph_value = 999
    type = "g"
    reporter = "test_reporter_persisted"

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        reporter: reporter
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}

    # Verify data in the database
    sanitized_short_name = Angel.Graphs.sanitize_short_name(short_name)

    # Since timestamp is NOW(), we can only check name and value
    # We need to query the raw metrics table as there's no Ecto schema for it directly
    {:ok, %{rows: rows}} =
      Angel.Repo.query("SELECT name, value FROM metrics WHERE name = $1 AND value = $2;", [
        sanitized_short_name,
        graph_value
      ])

    assert length(rows) == 1
    assert List.first(rows) == [sanitized_short_name, graph_value]
  end

  test "create stores min_value and max_value in Graph database", %{conn: conn} do
    short_name = "test.metric.with_min_max"
    graph_value = 100
    type = "g"
    min_value = 0.0
    max_value = 200.0

    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{
                                            "short_name" => ^short_name,
                                            "units" => ^type,
                                            "min_value" => ^min_value,
                                            "max_value" => ^max_value
                                          } ->
      {:ok, %{short_name: short_name, units: type, min_value: min_value, max_value: max_value}}
    end)

    _expected_event_text = "Value: " <> to_string(graph_value) <> " " <> type
    expected_event_text_initial = "Value: " <> to_string(graph_value) <> " " <> type

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: ^short_name, text: ^expected_event_text_initial} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         [^short_name, ^graph_value] ->
      {:ok, %{}}
    end)

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        min_value: min_value,
        max_value: max_value
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "min_value and max_value are persisted in the Graph database", %{conn: conn} do
    # Do not mock Angel.Graphs or Angel.Repo for this test to verify actual persistence
    # Mox.verify! is called automatically at the end of each test

    short_name = "test.metric.persisted_min_max"
    graph_value = 50
    type = "g"
    min_value = 10.0
    max_value = 100.0

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        min_value: min_value,
        max_value: max_value
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}

    # Verify data in the Graph database

    graph = Angel.Repo.get_by(Angel.Graphs.Index, short_name: "testmetricpersisted_min_max")

    assert graph.min_value == min_value
    assert graph.max_value == max_value
  end

  test "creates event when graph_value is below min_value", %{conn: conn} do
    short_name = "test.metric.below_min"
    graph_value = 5
    type = "g"
    min_value = 10.0
    max_value = 100.0

    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{
                                            "short_name" => ^short_name,
                                            "units" => ^type,
                                            "min_value" => ^min_value,
                                            "max_value" => ^max_value
                                          } ->
      {:ok, %{short_name: short_name, units: type, min_value: min_value, max_value: max_value}}
    end)

    expected_event_text_initial = "Value: " <> to_string(graph_value) <> " " <> type

    expected_event_text_below_min =
      "Value " <> to_string(graph_value) <> " is below min_value " <> to_string(min_value)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: ^short_name, text: ^expected_event_text_initial} ->
      {:ok, %{}}
    end)
    |> expect(:create_event, fn %{for_graph: ^short_name, text: ^expected_event_text_below_min} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         [^short_name, ^graph_value] ->
      {:ok, %{}}
    end)

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        min_value: min_value,
        max_value: max_value
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "creates event when graph_value is above max_value", %{conn: conn} do
    short_name = "test.metric.above_max"
    graph_value = 150
    type = "g"
    min_value = 10.0
    max_value = 100.0

    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{
                                            "short_name" => ^short_name,
                                            "units" => ^type,
                                            "min_value" => ^min_value,
                                            "max_value" => ^max_value
                                          } ->
      {:ok, %{short_name: short_name, units: type, min_value: min_value, max_value: max_value}}
    end)

    expected_event_text_initial = "Value: " <> to_string(graph_value) <> " " <> type

    expected_event_text_above_max =
      "Value " <> to_string(graph_value) <> " is above max_value " <> to_string(max_value)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: ^short_name, text: ^expected_event_text_initial} ->
      {:ok, %{}}
    end)
    |> expect(:create_event, fn %{for_graph: ^short_name, text: ^expected_event_text_above_max} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         [^short_name, ^graph_value] ->
      {:ok, %{}}
    end)

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        min_value: min_value,
        max_value: max_value
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "does not create extra event when graph_value is within range", %{conn: conn} do
    short_name = "test.metric.within_range"
    graph_value = 50
    type = "g"
    min_value = 10.0
    max_value = 100.0

    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{
                                            "short_name" => ^short_name,
                                            "units" => ^type,
                                            "min_value" => ^min_value,
                                            "max_value" => ^max_value
                                          } ->
      {:ok, %{short_name: short_name, units: type, min_value: min_value, max_value: max_value}}
    end)

    expected_event_text_initial = "Value: " <> to_string(graph_value) <> " " <> type

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: ^short_name, text: ^expected_event_text_initial} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);",
                         [^short_name, ^graph_value] ->
      {:ok, %{}}
    end)

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        min_value: min_value,
        max_value: max_value
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "create sanitizes short_name with dangerous characters", %{conn: conn} do
    short_name = "test-metric/with dangerous characters"
    graph_value = 42
    type = "g"
    reporter = "test_reporter"

    conn =
      post(conn, "/api/v1/metric", %{
        short_name: short_name,
        graph_value: graph_value,
        type: type,
        reporter: reporter
      })

    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}

    sanitized_short_name = "testmetricwithdangerouscharacters"

    # Verify data in the Graph database
    graph = Angel.Repo.get_by(Angel.Graphs.Index, short_name: sanitized_short_name)
    assert graph.short_name == sanitized_short_name

    # Verify data in the metrics table
    {:ok, %{rows: rows}} =
      Angel.Repo.query("SELECT name, value FROM metrics WHERE name = $1 AND value = $2;", [
        sanitized_short_name,
        graph_value
      ])

    assert length(rows) == 1
    assert List.first(rows) == [sanitized_short_name, graph_value]
  end
end
