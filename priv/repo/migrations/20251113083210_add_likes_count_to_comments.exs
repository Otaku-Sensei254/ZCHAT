defmodule Zchat.Repo.Migrations.AddLikesCountToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :likes_count, :integer, default: 0, null: false
    end

    # This will update existing records to have 0 likes
    execute "UPDATE comments SET likes_count = 0 WHERE likes_count IS NULL", ""
  end
end
