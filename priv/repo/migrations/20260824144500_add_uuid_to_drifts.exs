defmodule Vibeflow.Repo.Migrations.AddUuidToDrifts do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    alter table(:drifts) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end

    create unique_index(:drifts, [:uuid])
  end

  def down do
    alter table(:drifts) do
      remove :uuid
    end
  end
end