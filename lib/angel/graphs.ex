defmodule Angel.Graphs do
  @moduledoc """
  The Graphs context.
  """

  import Ecto.Query, warn: false
  alias Angel.Repo

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

  def create_or_update_graph(attrs) do
    case Repo.get_by(Index, short_name: attrs["short_name"]) do
      nil ->
        create_index(attrs)
      graph ->
        update_index(graph, attrs)
    end
  end
end
