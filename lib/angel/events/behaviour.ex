defmodule Angel.Events.Behaviour do
  @moduledoc "Behaviour for Events"
  @callback create_event(map()) :: {:ok, map()} | {:error, any()}
  @callback for_graph(String.t()) :: list()
end
