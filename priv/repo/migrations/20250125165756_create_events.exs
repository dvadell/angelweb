defmodule Angel.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :text, :string
      add :for_graph, :string

      timestamps(type: :utc_datetime)
    end
  end
end
