defmodule Angel.Events.Behaviour do
  @callback create_event(map()) :: {:ok, map()} | {:error, any()}
end
