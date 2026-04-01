defmodule Vibeflow.Repo.Migrations.CreateSavedPosts do
  use Ecto.Migration

  def change do
    create table(:saved_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:saved_posts, [:user_id])
    # Prevent saving the same post twice
    create unique_index(:saved_posts, [:user_id, :post_id])
  end
end
