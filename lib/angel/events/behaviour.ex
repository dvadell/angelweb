defmodule Angel.Events.Behaviour do
  @moduledoc "Behaviour for Events"
  @callback create_event(map()) :: {:ok, map()} | {:error, any()}
end
