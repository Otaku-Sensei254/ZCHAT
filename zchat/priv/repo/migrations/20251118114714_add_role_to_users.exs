defmodule Zchat.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "user", null: false
    end

    # Create an index so searching for admins is fast later
    create index(:users, [:role])
  end
end
