defmodule Vibeflow.Repo.Migrations.AddItemNameToInventory do
  use Ecto.Migration

  def change do
    alter table(:inventory) do
      add :item_name, :string
    end

    # Update existing records to populate item_name from store_items
    execute """
            UPDATE inventory i
            SET item_name = s.item_name
            FROM store_items s
            WHERE i.item_slug = s.id
            """,
            ""
  end
end
