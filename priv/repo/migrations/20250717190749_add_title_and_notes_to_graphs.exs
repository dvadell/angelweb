defmodule Angel.Repo.Migrations.AddTitleAndNotesToGraphs do
  use Ecto.Migration

  def change do
    alter table(:graphs) do
      add :title, :string, default: ""
      add :notes, :text, default: ""
    end
  end
end
