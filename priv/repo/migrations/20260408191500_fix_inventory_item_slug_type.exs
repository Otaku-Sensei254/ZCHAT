defmodule Vibeflow.Repo.Migrations.FixInventoryItemSlugType do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE inventory ALTER COLUMN item_slug TYPE uuid USING item_slug::uuid"
  end

  def down do
    execute "ALTER TABLE inventory ALTER COLUMN item_slug TYPE bigint USING item_slug::bigint"
  end
end
