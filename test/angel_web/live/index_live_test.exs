defmodule AngelWeb.IndexLiveTest do
  use AngelWeb.ConnCase

  import Angel.MetricsFixtures
  import Phoenix.LiveViewTest
  alias Angel.GraphsFixtures

  describe "Index" do
    test "lists all graphs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Graphs"
    end

    test "lists all graphs with sparklines", %{conn: conn} do
      GraphsFixtures.index_fixture(%{short_name: "my_graph"})
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for i <- 1..10 do
        metric_fixture(%{name: "my_graph", value: i, timestamp: DateTime.add(now, -i, :minute)})
      end

      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Graphs List"
      assert html =~ "my_graph"
      assert html =~ "<svg"
      assert html =~ "<polyline"
    end
  end

  describe "Show" do
    test "displays graph and buttons", %{conn: conn} do
      graph = GraphsFixtures.index_fixture(%{title: "My Graph", short_name: "my-graph"})
      {:ok, show_live, html} = live(conn, ~p"/graphs/#{graph.short_name}")

      assert html =~ "My Graph"
      assert has_element?(show_live, "button[phx-click=toggle_form]")
      assert has_element?(show_live, "button[phx-click=toggle_chart_play]")
      assert html =~ "hour"
      assert html =~ "day"
      assert html =~ "week"
      assert html =~ "month"
    end
  end
end
