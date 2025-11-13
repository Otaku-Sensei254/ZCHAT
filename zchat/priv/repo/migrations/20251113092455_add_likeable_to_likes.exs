defmodule Zchat.Repo.Migrations.AddLikeableToLikes do
  use Ecto.Migration

  def change do
    alter table(:likes) do
      # Add the new polymorphic columns
      add :likeable_type, :string, null: false
      add :likeable_id, :bigint, null: false

      # Remove the old, separate columns
      remove :post_id
      remove :comment_id
    end

    # Create a new unique index for the polymorphic fields
    create unique_index(:likes, [:user_id, :likeable_type, :likeable_id], name: :user_likeable_unique_index)
  end
end
