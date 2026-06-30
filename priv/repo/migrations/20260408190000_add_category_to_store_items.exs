defmodule Vibeflow.Repo.Migrations.AddCategoryToStoreItems do
  use Ecto.Migration

  def change do
    alter table(:store_items) do
      add :category, :string
    end
  end
end
