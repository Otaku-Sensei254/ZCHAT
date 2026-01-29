# priv/repo/migrations/[timestamp]_create_roles_table.exs
defmodule Vibeflow.Repo.Migrations.CreateRolesTable do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :permissions, :map, default: %{}  # Store permissions as JSON

      timestamps()
    end

    create unique_index(:roles, [:name])
  end
end
