defmodule Vibeflow.Repo.Migrations.AddUuidToUsers do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    alter table(:users) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end

    create unique_index(:users, [:uuid])
  end

  def down do
    alter table(:users) do
      remove :uuid
    end
  end
end