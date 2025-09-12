defmodule Angel.Telemetry do
  @moduledoc """
  This module is responsible for setting up telemetry handlers.
  """

  def setup do
    :telemetry.attach(
      "phoenix-endpoint-stop",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_endpoint_stop/4,
      nil
    )
  end

  def handle_endpoint_stop(_event, measurements, _metadata, _config) do
    duration_in_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Angel.Junior.trace("angel_request_process", duration_in_ms)
  end
end
