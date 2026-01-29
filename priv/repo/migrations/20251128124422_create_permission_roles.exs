defmodule Vibeflow.Repo.Migrations.CreatePermissionRoles do
  use Ecto.Migration

  def change do
    create table(:permission_roles) do
      add :role_id, :integer
      add :permission_id, :integer
    end
  end
end
