defmodule AngelWeb.IndexLiveTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Angel.GraphsFixtures

  describe "Index" do
    test "lists all graphs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Graphs"
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
