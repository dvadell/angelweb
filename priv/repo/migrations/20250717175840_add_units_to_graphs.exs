defmodule Angel.Repo.Migrations.AddUnitsToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :units, :string
    end
  end
end
