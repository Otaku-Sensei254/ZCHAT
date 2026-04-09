defmodule Vibeflow.Repo.Migrations.CreateStoreItems do
  use Ecto.Migration

  def change do
    create table(:store_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :item_name, :string
      add :item_slug, :string
      add :worth, :string #say maybe 500pts

    end
  end
end
