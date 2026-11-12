defmodule Angel.Release do
  @moduledoc """
  Tasks run from a Mix release, where Mix isn't available.

      bin/angel eval Angel.Release.migrate
  """
  @app :angel

  # Only Angel.Repo is configured in prod. Angel.NonTransactionalRepo is a
  # test helper and shares the same migrations.
  @repos [Angel.Repo]

  # Creates the database if it doesn't exist yet, like `mix ecto.create`.
  def migrate do
    load_app()

    for repo <- @repos do
      :ok = create_storage(repo)
      {:ok, _migrated, _apps} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _rolled_back, _apps} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp create_storage(repo) do
    case repo.__adapter__().storage_up(repo.config()) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
