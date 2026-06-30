defmodule Vibeflow.Repo.Migrations.AddMediaFilesToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :media_files, {:array, :jsonb}, default: []
    end
  end
end
