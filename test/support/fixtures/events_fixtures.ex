defmodule Angel.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Angel.Events` context.
  """

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        for_graph: "some for_graph",
        text: "some text"
      })
      |> Angel.Events.create_event()

    event
  end
end
