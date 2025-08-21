defmodule Angel.Graphs.Index do
  @moduledoc "Schema for graphs"
  use Ecto.Schema
  import Ecto.Changeset

  schema "graphs" do
    field :short_name, :string
    field :units, :string
    field :title, :string, default: ""
    field :notes, :string, default: ""
    field :min_value, :float
    field :max_value, :float
    field :graph_type, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(index, attrs) do
    index
    |> cast(attrs, [:short_name, :units, :title, :notes, :min_value, :max_value, :graph_type])
    |> validate_required([:short_name])
  end
end
