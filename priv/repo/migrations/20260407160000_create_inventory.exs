defmodule Vibeflow.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:inventory, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :id), null: false
      add :item_slug, references(:store_items, on_delete: :delete_all, type: :binary_id), null: false
      add :is_equipped, :boolean, default: false, null: false
      add :metadata, :map

      timestamps()
    end

    create index(:inventory, [:user_id])
    # Prevent a user from "buying" the same permanent item twice
    create unique_index(:inventory, [:user_id, :item_slug])
  end
end
