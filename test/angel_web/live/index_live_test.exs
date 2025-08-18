defmodule AngelWeb.IndexLiveTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Index" do
    test "lists all graphs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Graphs"
    end
  end
end
