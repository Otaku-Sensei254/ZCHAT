defmodule Vibeflow.Repo.Migrations.AddPinnedToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :pinned, :boolean, default: false, null: false
    end

    create index(:comments, [:post_id, :pinned])
  end
end
