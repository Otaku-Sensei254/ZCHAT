defmodule Vibeflow.Repo.Migrations.AddSavesCountToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :saves_count, :integer, default: 0
    end
  end
end
