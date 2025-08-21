defmodule Angel.Metrics do
  @moduledoc "Schema for metrics"
  use Ecto.Schema
  import Ecto.Changeset

  # Use no_primary_key for schemas without a primary key
  @primary_key false
  schema "metrics" do
    field :timestamp, :utc_datetime
    field :name, :string
    field :value, :float # Change to :float
  end

  def changeset(changeset \\ %__MODULE__{}, attrs) do
    changeset
    |> cast(attrs, [:timestamp, :name, :value])
    |> validate_required([:timestamp, :name, :value])
    |> validate_number(:value, greater_than_or_equal_to: 0)
  end
end
