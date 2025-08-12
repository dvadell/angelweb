defmodule Angel.Repo.Behaviour do
  @callback query(String.t(), list()) :: {:ok, map()} | {:error, any()}
end