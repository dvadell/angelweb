defmodule Angel.Events.Event do
  @moduledoc "Schema for events"
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :text, :string
    field :for_graph, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:text, :for_graph])
    |> validate_required([:text, :for_graph])
  end
end
