defmodule Angel.MetricsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Angel.Metrics` context.
  """
  alias Angel.Metrics

  def metric_fixture(attrs \\ %{}) do
    {:ok, metric} =
      %Metrics{}
      |> Metrics.changeset(
        Enum.into(attrs, %{
          name: "test_metric",
          value: :rand.uniform() * 100,
          timestamp: NaiveDateTime.utc_now() |> DateTime.from_naive!("Etc/UTC")
        })
      )
      |> Angel.Repo.insert()

    metric
  end
end
