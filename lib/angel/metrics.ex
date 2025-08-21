defmodule Angel.Metrics do
  @moduledoc "The Metrics context."
  use Ecto.Schema
  import Ecto.Changeset

  alias Angel.Repo

  # Use no_primary_key for schemas without a primary key
  @primary_key false
  schema "metrics" do
    field :timestamp, :utc_datetime
    field :name, :string
    # Change to :float
    field :value, :float
  end

  @doc """
  Creates a metric.

  ## Examples

      iex> add_metric(%{field: value})
      {:ok, %Angel.Metrics{}}

      iex> add_metric(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def add_metric(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def changeset(changeset \\ %__MODULE__{}, attrs) do
    changeset
    |> cast(attrs, [:timestamp, :name, :value])
    |> validate_required([:timestamp, :name, :value])
    |> validate_number(:value, [])
  end
end
