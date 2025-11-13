defmodule Zchat.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, on_delete: :delete_all)

      timestamps()
    end

    create index(:comments, [:user_id])
    create index(:comments, [:post_id])
    create index(:comments, [:parent_id])
  end
end
