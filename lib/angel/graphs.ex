defmodule Angel.Graphs do
  @moduledoc """
  The Graphs context.
  """
  @behaviour Angel.Graphs.Behaviour

  import Ecto.Query, warn: false
  alias Angel.Graphs.Index
  alias Angel.Junior
  alias Angel.Repo
  alias Decimal

  require Logger

  @doc """
  Returns the list of graphs with their latest status.

  ## Examples

      iex> list_graphs()
      [%Index{status: :ok}, ...]

  """
  @spec list_graphs() :: [map()]
  def list_graphs do
    graphs = Repo.all(Index)
    graph_names = Enum.map(graphs, & &1.short_name)

    latest_metrics = get_all_latest_metrics(graph_names)
    all_sparklines = get_all_sparkline_data(graph_names)

    Enum.map(graphs, fn graph ->
      latest_metric = latest_metrics[graph.short_name]
      status = calculate_status(latest_metric, graph.min_value, graph.max_value)
      sparkline_data = all_sparklines[graph.short_name] || []

      graph
      |> Map.put(:status, status)
      |> Map.put(:sparkline, sparkline_data)
    end)
  end

  @spec get_all_latest_metrics([String.t()]) :: %{String.t() => number()}
  defp get_all_latest_metrics(graph_names) do
    ranked_metrics =
      from m in Angel.Metrics,
        where: m.name in ^graph_names,
        select: %{
          name: m.name,
          value: m.value,
          row_number: over(row_number(), partition_by: m.name, order_by: [desc: m.timestamp])
        }

    query =
      from m in subquery(ranked_metrics),
        where: m.row_number == 1,
        select: {m.name, m.value}

    query
    |> Repo.all()
    |> Map.new()
  end

  @spec get_all_sparkline_data([String.t()]) :: %{String.t() => [number()]}
  defp get_all_sparkline_data(graph_names) do
    end_time = DateTime.utc_now() |> DateTime.truncate(:second)
    start_time = DateTime.add(end_time, -1, :day)

    case Junior.trace("angel_graphs_fetch_all_timescaledb_data", fn ->
           fetch_sparkline_data_for_graphs(graph_names, start_time, end_time)
         end) do
      {:ok, sparkline_data} ->
        sparkline_data
        |> Enum.group_by(& &1.graph_name, & &1.datapoints)
        |> Enum.map(&format_sparkline_datapoints/1)
        |> Map.new()

      _other ->
        %{}
    end
  end

  @spec format_sparkline_datapoints({String.t(), list()}) :: {String.t(), list()}
  defp format_sparkline_datapoints({graph_name, datapoints_list}) do
    datapoints =
      datapoints_list
      |> List.first()
      |> Enum.map(fn [value, _timestamp] -> value end)
      |> Enum.reject(&is_nil(&1))
      |> Enum.take(-6)

    {graph_name, datapoints}
  end

  # Fetches sparkline data for all graphs in a single database call.
  # It uses `unnest` to expand the list of graph names into a temporary table,
  # and a `LATERAL` join to call the `get_metrics` database function for each graph.
  # This is much more efficient than making N separate calls from the application.
  # sobelow_skip ["SQL.Query"]
  @spec fetch_sparkline_data_for_graphs([String.t()], DateTime.t(), DateTime.t()) :: {:ok, list()} | {:error, any()}
  defp fetch_sparkline_data_for_graphs(graph_names, start_time, end_time) do
    query = """
    SELECT T2.graph_name, T1.*
    FROM unnest($1::text[]) WITH ORDINALITY AS T2(graph_name, ord)
    LEFT JOIN LATERAL get_metrics(T2.graph_name, $2, $3) AS T1 ON true
    ORDER BY T2.ord;
    """

    format_data_from_rows = fn [graph_name, timestamp, avg_value, _max, _min] ->
      unix_timestamp = if timestamp, do: DateTime.to_unix(timestamp, :millisecond), else: nil
      value = if avg_value, do: Decimal.to_float(avg_value), else: nil
      {graph_name, [value, unix_timestamp]}
    end

    case Repo.query(query, [graph_names, start_time, end_time]) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        {:ok,
         rows
         |> Enum.map(format_data_from_rows)
         |> Enum.group_by(
           fn {graph_name, _datapoint} -> graph_name end,
           fn {_graph_name, datapoint} -> datapoint end
         )
         |> Enum.map(fn {graph_name, datapoints} ->
           %{graph_name: graph_name, datapoints: datapoints}
         end)}

      {:error, e} ->
        Logger.error("Error fetching sparkline data from TimescaleDB: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec calculate_status(number() | nil, float() | nil, float() | nil) :: :no_data | :ok | :not_ok
  defp calculate_status(latest_metric, min_value, max_value) do
    cond do
      is_nil(latest_metric) -> :no_data
      is_nil(min_value) && latest_metric <= max_value -> :ok
      is_nil(max_value) && latest_metric >= min_value -> :ok
      latest_metric >= min_value && latest_metric <= max_value -> :ok
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
  @spec get_index!(any()) :: Index.t()
  def get_index!(id), do: Repo.get!(Index, id)

  @spec get_by_short_name(String.t()) :: Index.t() | nil
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
  @spec create_index(map()) :: {:ok, Index.t()} | {:error, Ecto.Changeset.t()}
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
  @spec update_index(Index.t(), map()) :: {:ok, Index.t()} | {:error, Ecto.Changeset.t()}
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
  @spec delete_index(Index.t()) :: {:ok, Index.t()} | {:error, Ecto.Changeset.t()}
  def delete_index(%Index{} = index) do
    Repo.delete(index)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking index changes.

  ## Examples

      iex> change_index(index)
      %Ecto.Changeset{data: %Index{}}

  """
  @spec change_index(Index.t(), map()) :: Ecto.Changeset.t()
  def change_index(%Index{} = index, attrs \\ %{}) do
    Index.changeset(index, attrs)
  end

  @spec count_metrics(String.t()) :: integer()
  def count_metrics(graph_name) do
    Angel.Metrics
    |> where([m], m.name == ^graph_name)
    |> select(count())
    |> Repo.one()
  end

  @spec first_metric_timestamp(String.t()) :: DateTime.t() | nil
  def first_metric_timestamp(graph_name) do
    Angel.Metrics
    |> where([m], m.name == ^graph_name)
    |> order_by([m], asc: m.timestamp)
    |> limit(1)
    |> select([m], m.timestamp)
    |> Repo.one()
  end

  @spec last_metric_timestamp(String.t()) :: DateTime.t() | nil
  def last_metric_timestamp(graph_name) do
    Angel.Metrics
    |> where([m], m.name == ^graph_name)
    |> order_by([m], desc: m.timestamp)
    |> limit(1)
    |> select([m], m.timestamp)
    |> Repo.one()
  end

  # sobelow_skip ["SQL.Query"]
  @spec fetch_timescaledb_data(String.t(), DateTime.t(), DateTime.t()) :: {:ok, list()} | {:error, any()}
  def fetch_timescaledb_data(graph_name_with_prefix, start_time, end_time) do
    query = "SELECT * FROM get_metrics($1, $2, $3);"

    format_data_from_rows = fn [timestamp, avg_value, _max, _min] ->
      # The JS graph wants milliseconds since epoch
      unix_timestamp = DateTime.to_unix(timestamp, :millisecond)
      # Handle nil values for avg_value, which can happen for empty time buckets.
      value = if avg_value, do: Decimal.to_float(avg_value), else: nil
      [value, unix_timestamp]
    end

    case Repo.query(query, [graph_name_with_prefix, start_time, end_time]) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        datapoints = Enum.map(rows, format_data_from_rows)
        {:ok, [%{target: graph_name_with_prefix, datapoints: datapoints}]}

      {:error, e} ->
        Logger.error("Error fetching data from TimescaleDB: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec create_or_update_graph(map()) :: {:ok, Index.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update_graph(attrs) do
    sanitized_attrs = Map.update!(attrs, "short_name", &sanitize_short_name/1)

    case Repo.get_by(Index, short_name: sanitized_attrs["short_name"]) do
      nil ->
        create_index(sanitized_attrs)

      graph ->
        update_index(graph, sanitized_attrs)
    end
  end

  @spec sanitize_short_name(String.t()) :: String.t()
  def sanitize_short_name(short_name) do
    Regex.replace(~r/[^a-zA-Z0-9_]/, short_name, "")
  end
end
