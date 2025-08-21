defmodule Angel.Repo.Behaviour do
  @moduledoc "Angel Repo Behaviour"
  @callback query(String.t(), list()) :: {:ok, map()} | {:error, any()}
end
