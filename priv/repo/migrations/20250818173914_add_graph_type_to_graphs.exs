defmodule Angel.Repo.Migrations.AddGraphTypeToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :graph_type, :string
    end

    execute """
      ALTER TABLE graphs
      ADD CONSTRAINT graph_type_check CHECK (graph_type IN ('time') OR graph_type IS NULL)
    """
  end
end
