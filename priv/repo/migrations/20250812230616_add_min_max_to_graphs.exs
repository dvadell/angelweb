defmodule Angel.Repo.Migrations.AddMinMaxToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :min_value, :float
      add :max_value, :float
    end
  end
end
