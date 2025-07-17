defmodule Angel.Graphs.Index do
  use Ecto.Schema
  import Ecto.Changeset

  schema "graphs" do
    field :short_name, :string
    field :units, :string
    field :title, :string, default: ""
    field :notes, :string, default: ""

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(index, attrs) do
    index
    |> cast(attrs, [:short_name, :units, :title, :notes])
    |> validate_required([:short_name])
  end
end
