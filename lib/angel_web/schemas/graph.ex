defmodule AngelWeb.Schemas.Graph do
  use Ecto.Schema
  import Ecto.Changeset

  schema "metric" do
    field :short_name, :string
    field :units, :string, default: ""
    field :graph_value, :integer
    field :type, :string, default: "g"
    field :reporter, :string
    field :message, :string
  end

  def changeset(changeset \\ %__MODULE__{}, attrs) do
    changeset
    |> cast(attrs, [:short_name, :units, :graph_value, :type, :reporter, :message])
    |> validate_required([:short_name, :graph_value])
    |> validate_inclusion(:type, ["g", "c"], message: "must be 'g' or 'c'")
    |> validate_number(:graph_value, greater_than_or_equal_to: 0)
  end
end
