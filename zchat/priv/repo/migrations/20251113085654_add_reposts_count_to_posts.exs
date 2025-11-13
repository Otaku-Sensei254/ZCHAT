defmodule Zchat.Repo.Migrations.AddRepostsCountToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :reposts_count, :integer, default: 0, null: false
    end
  end
end
