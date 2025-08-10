defmodule Angel.Graphs do
  @moduledoc """
  The Graphs context.
  """

  import Ecto.Query, warn: false
  alias Angel.Repo
  alias Decimal

  alias Angel.Graphs.Index

  @doc """
  Returns the list of graphs.

  ## Examples

      iex> list_graphs()
      [%Index{}, ...]

  """
  def list_graphs do
    Repo.all(Index)
  end

  @doc """
  Gets a single index.

  Raises `Ecto.NoResultsError` if the Index does not exist.

  ## Examples

      iex> get_index!(123)
      %Index{}

      iex> get_index!(456)
      ** (Ecto.NoResultsError)

  """
  def get_index!(id), do: Repo.get!(Index, id)

  def get_by_short_name(short_name) do
    Repo.get_by(Index, short_name: short_name)
  end

  @doc """
  Creates a index.

  ## Examples

      iex> create_index(%{field: value})
      {:ok, %Index{}}

      iex> create_index(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_index(attrs \\ %{}) do
    %Index{}
    |> Index.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a index.

  ## Examples

      iex> update_index(index, %{field: new_value})
      {:ok, %Index{}}

      iex> update_index(index, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_index(%Index{} = index, attrs) do
    index
    |> Index.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a index.

  ## Examples

      iex> delete_index(index)
      {:ok, %Index{}}

      iex> delete_index(index)
      {:error, %Ecto.Changeset{}}

  """
  def delete_index(%Index{} = index) do
    Repo.delete(index)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking index changes.

  ## Examples

      iex> change_index(index)
      %Ecto.Changeset{data: %Index{}}

  """
  def change_index(%Index{} = index, attrs \\ %{}) do
    Index.changeset(index, attrs)
  end

  def fetch_timescaledb_data(graph_name_with_prefix, start_time, end_time) do
    # The name in the metrics table likely has the "jr." prefix, so we use it directly.
    query = "SELECT * FROM get_metrics($1, $2, $3);"

    case Repo.query(query, ["jr." <> graph_name_with_prefix, start_time, end_time]) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        datapoints =
          Enum.map(rows, fn [timestamp, avg_value, _max, _min] ->
            # The JS graph wants milliseconds since epoch
            unix_timestamp = DateTime.to_unix(timestamp, :millisecond)
            # Handle nil values for avg_value, which can happen for empty time buckets.
            value = if avg_value, do: Decimal.to_float(avg_value), else: nil
            [value, unix_timestamp]
          end)

        {:ok, [%{target: graph_name_with_prefix, datapoints: datapoints}]}

      {:error, e} ->
        IO.inspect(e, label: "Error fetching data from TimescaleDB")
        {:error, e}
    end
  end

  def create_or_update_graph(attrs) do
    case Repo.get_by(Index, short_name: attrs["short_name"]) do
      nil ->
        create_index(attrs)
      graph ->
        update_index(graph, attrs)
    end
  end
end
