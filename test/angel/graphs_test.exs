defmodule Angel.GraphsTest do
  use Angel.DataCase

  alias Angel.Graphs

  describe "graphs" do
    alias Angel.Graphs.Index

    import Angel.GraphsFixtures

    @invalid_attrs %{short_name: nil}

    test "list_graphs/0 returns all graphs" do
      index = index_fixture()
      [returned_graph] = Graphs.list_graphs()
      assert returned_graph.id == index.id
      assert returned_graph.short_name == index.short_name
      assert returned_graph.status in [:ok, :not_ok, :no_data]
    end

    test "get_index!/1 returns the index with given id" do
      index = index_fixture()
      assert Graphs.get_index!(index.id) == index
    end

    test "create_index/1 with valid data creates a index" do
      valid_attrs = %{short_name: "some short_name"}

      assert {:ok, %Index{} = index} = Graphs.create_index(valid_attrs)
      assert index.short_name == "some short_name"
    end

    test "create_index/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Graphs.create_index(@invalid_attrs)
    end

    test "update_index/2 with valid data updates the index" do
      index = index_fixture()
      update_attrs = %{short_name: "some updated short_name"}

      assert {:ok, %Index{} = index} = Graphs.update_index(index, update_attrs)
      assert index.short_name == "some updated short_name"
    end

    test "update_index/2 with invalid data returns error changeset" do
      index = index_fixture()
      assert {:error, %Ecto.Changeset{}} = Graphs.update_index(index, @invalid_attrs)
      assert index == Graphs.get_index!(index.id)
    end

    test "delete_index/1 deletes the index" do
      index = index_fixture()
      assert {:ok, %Index{}} = Graphs.delete_index(index)
      assert_raise Ecto.NoResultsError, fn -> Graphs.get_index!(index.id) end
    end

    test "change_index/1 returns a index changeset" do
      index = index_fixture()
      assert %Ecto.Changeset{} = Graphs.change_index(index)
    end
  end
end
