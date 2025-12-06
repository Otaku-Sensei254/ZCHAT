defmodule Zchat.Repo.Migrations.AddEditPermissionToUser do
  use Ecto.Migration

  def up do
    # We append 'post-edit' to the existing array for the 'user' role
    execute "UPDATE roles SET permissions = array_append(permissions, 'post-edit') WHERE name = 'user' AND NOT ('post-edit' = ANY(permissions))"
  end

  def down do
    # Remove 'post-edit' if we rollback
    execute "UPDATE roles SET permissions = array_remove(permissions, 'post-edit') WHERE name = 'user'"
  end
end
