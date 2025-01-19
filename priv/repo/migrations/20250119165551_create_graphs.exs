defmodule Angel.Repo.Migrations.CreateGraphs do
  use Ecto.Migration

  def change do
    create table(:graphs) do
      add :short_name, :string

      timestamps(type: :utc_datetime)
    end
  end
end
