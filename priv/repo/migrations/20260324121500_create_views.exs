defmodule Vibeflow.Repo.Migrations.CreateViews do
  use Ecto.Migration

  def change do
    create table(:views) do
      add :post_id, references(:posts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:views, [:post_id, :user_id], name: :views_post_id_user_id_index)
    create index(:views, [:user_id])
    create index(:views, [:post_id])
  end
end
