defmodule Vibeflow.Repo.Migrations.CreatePermissionsStructure do
  use Ecto.Migration

  def change do
    # 1. REMOVE the old array column (Switching strategies)
    alter table(:roles) do
      remove :permissions
    end

    # 2. CREATE the Permissions definition table
    create table(:permissions) do
      # e.g. "post-new"
      add :slug, :string, null: false
      # e.g. "Can create new posts"
      add :description, :string

      timestamps()
    end

    # Ensure slugs are unique (can't have two "post-new")
    create unique_index(:permissions, [:slug])

    # 3. CREATE the Join Table (Role <-> Permission)
    create table(:role_permissions) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
    end

    # Ensure a role doesn't get the same permission twice
    create unique_index(:role_permissions, [:role_id, :permission_id])
  end
end
