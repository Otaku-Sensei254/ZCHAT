defmodule Vibeflow.Repo.Migrations.FixRolesAndPermissions do
  use Ecto.Migration

  def up do
    # 1. FIX THE COLUMN TYPE
    # We remove the existing JSON column and replace it with a Postgres Array
    alter table(:roles) do
      remove :permissions
      add :permissions, {:array, :string}, default: []
    end

    # 2. POPULATE DATA (Now the Array syntax '{}' will work!)
    # Admin gets everything
    execute "UPDATE roles SET permissions = '{\"post-new\", \"post-edit\", \"post-delete\", \"user-ban\"}' WHERE name = 'admin'"

    # Moderator gets management
    execute "UPDATE roles SET permissions = '{\"post-edit\", \"post-delete\"}' WHERE name = 'moderator'"

    # User gets creation
    execute "UPDATE roles SET permissions = '{\"post-new\", \"post-edit\"}' WHERE name = 'user'"
  end

  def down do
    # Revert if needed
    alter table(:roles) do
      remove :permissions
      add :permissions, :jsonb, default: "[]" # Assuming previous type was jsonb/json
    end
  end
end
