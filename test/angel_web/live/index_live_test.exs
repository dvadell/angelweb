defmodule AngelWeb.IndexLiveTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest
  import Angel.GraphsFixtures
  import Angel.MetricsFixtures

  @create_attrs %{short_name: "some_short_name"}
  @update_attrs %{short_name: "some updated short_name"}
  @invalid_attrs %{short_name: nil}

  defp create_index(_) do
    index = index_fixture()
    %{index: index}
  end

  defp create_metric(%{index: index}) do
    metric = metric_fixture(index.short_name)
    %{metric: metric}
  end

  describe "Index" do
    setup [:create_index, :create_metric]

    test "lists all graphs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Graphs"
    end

    test "retrieves metrics for a valid time range", %{conn: conn, index: index} do
      start_time = DateTime.add(DateTime.utc_now(), -3600, :second) # 1 hour ago
      end_time = DateTime.utc_now()

      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      metrics = fetch_timescaledb_data(index.short_name, start_time, end_time)

      assert length(metrics) > 0
    end

    test "retrieves no metrics for an invalid time range", %{conn: conn, index: index} do
      start_time = DateTime.add(DateTime.utc_now(), 3600, :second) # 1 hour from now
      end_time = DateTime.add(start_time, 7200, :second) # 2 hours from now

      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      metrics = fetch_timescaledb_data(index.short_name, start_time, end_time)

      assert length(metrics) == 0
    end

    test "retrieves metrics for a border-case time range", %{conn: conn, index: index} do
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 1, :second)

      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      metrics = fetch_timescaledb_data(index.short_name, start_time, end_time)

      assert length(metrics) == 0
    end

    test "retrieves metrics for a large time range", %{conn: conn, index: index} do
      start_time = DateTime.add(DateTime.utc_now(), -86400, :second) # 24 hours ago
      end_time = DateTime.utc_now()

      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      metrics = fetch_timescaledb_data(index.short_name, start_time, end_time)

      assert length(metrics) > 0
    end

    defp fetch_timescaledb_data(short_name_with_prefix, start_time, end_time) do
      query = "SELECT * FROM get_metrics($1, $2, $3);"
      case Repo.query(query, ["jr." <> short_name_with_prefix, start_time, end_time]) do
        {:ok, %Postgrex.Result{rows: rows}} ->
          Enum.map(rows, fn row -> Map.new(Enum.zip(["short_name", "units", "graph_value", "type", "reporter", "message"], Tuple.to_list(row))) end)
        _ ->
          []
      end
    end
  end
end
