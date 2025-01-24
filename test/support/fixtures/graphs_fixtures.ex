defmodule Angel.GraphsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Angel.Graphs` context.
  """

  @doc """
  Generate a index.
  """
  def index_fixture(attrs \\ %{}) do
    {:ok, index} =
      attrs
      |> Enum.into(%{
        short_name: "some short_name"
      })
      |> Angel.Graphs.create_index()

    index
  end
end
