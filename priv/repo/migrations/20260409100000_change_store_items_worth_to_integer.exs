defmodule Vibeflow.Repo.Migrations.ChangeStoreItemsWorthToInteger do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE store_items ALTER COLUMN worth TYPE integer USING worth::integer"
  end

  def down do
    execute "ALTER TABLE store_items ALTER COLUMN worth TYPE varchar USING worth::varchar"
  end
end
