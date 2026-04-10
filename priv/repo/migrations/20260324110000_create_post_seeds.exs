defmodule Vibeflow.Repo.Migrations.CreatePostSeeds do
  use Ecto.Migration

  def change do
    create table(:post_seeds, primary_key: false) do
      add :post_id, references(:posts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
      add :rippled, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:post_seeds, [:post_id, :user_id],
             name: :post_seeds_post_id_user_id_index
           )

    create index(:post_seeds, [:user_id])
    create index(:post_seeds, [:post_id])
  end
end
