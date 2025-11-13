defmodule Zchat.Repo.Migrations.AddLikesCountToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :likes_count, :integer, null: false, default: 0
    end
  end
end
