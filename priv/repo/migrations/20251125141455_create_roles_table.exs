# priv/repo/migrations/[timestamp]_create_roles_table.exs
defmodule Vibeflow.Repo.Migrations.CreateRolesTable do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      # Store permissions as JSON
      add :permissions, :map, default: %{}

      timestamps()
    end

    create unique_index(:roles, [:name])
  end
end
