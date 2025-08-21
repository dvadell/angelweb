defmodule Angel.Graphs do
  @behaviour Angel.Graphs.Behaviour
  @moduledoc """
  The Graphs context.
  """

  import Ecto.Query, warn: false
  alias Angel.Graphs.Index
  alias Angel.Metrics # Add this alias
  alias Angel.Repo
  alias Decimal

  require Logger

  @doc """
  Returns the list of graphs with their latest status.

  ## Examples

      iex> list_graphs()
      [%Index{status: :ok}, ...]

  """
  def list_graphs do
    Repo.all(Index)
    |> Enum.map(fn graph ->
      latest_metric = get_latest_metric(graph.short_name)
      status = calculate_status(latest_metric, graph.min_value, graph.max_value)
      Map.put(graph, :status, status)
    end)
  end

  defp get_latest_metric(graph_name) do
    Angel.Metrics
    |> select([m], m.value) # Explicitly select only the 'value' field
    |> where([m], m.name == ^graph_name)
    |> order_by([m], desc: m.timestamp)
    |> limit(1)
    |> Repo.one()
    |> case do
      value when is_number(value) -> value # Change to is_number(value)
      _ -> nil # No metric found
    end
  end

  defp calculate_status(latest_metric, min_value, max_value) do
    cond do
      is_nil(latest_metric) -> :no_data
      is_nil(min_value) && latest_metric <= max_value -> :ok
      is_nil(max_value) && latest_metric >= min_value -> :ok
      latest_metric >= min_value  && latest_metric <= max_value -> :ok
      true -> :not_ok
    end
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
    query = "SELECT * FROM get_metrics($1, $2, $3);"

    case Repo.query(query, [graph_name_with_prefix, start_time, end_time]) do
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
        Logger.error("Error fetching data from TimescaleDB: #{inspect(e)}")
        {:error, e}
    end
  end

  def create_or_update_graph(attrs) do
    sanitized_attrs = Map.update!(attrs, "short_name", &sanitize_short_name/1)

    case Repo.get_by(Index, short_name: sanitized_attrs["short_name"]) do
      nil ->
        create_index(sanitized_attrs)

      graph ->
        update_index(graph, sanitized_attrs)
    end
  end

  def sanitize_short_name(short_name) do
    Regex.replace(~r/[^a-zA-Z0-9_]/, short_name, "")
  end
end
