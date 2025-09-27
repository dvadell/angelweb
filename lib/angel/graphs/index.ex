defmodule Angel.Graphs.Index do
  @moduledoc "Schema for graphs"
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          short_name: String.t(),
          units: String.t() | nil,
          title: String.t() | nil,
          notes: String.t() | nil,
          min_value: float() | nil,
          max_value: float() | nil,
          graph_type: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

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
