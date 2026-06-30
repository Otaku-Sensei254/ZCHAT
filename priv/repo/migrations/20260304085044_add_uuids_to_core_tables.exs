defmodule Vibeflow.Repo.Migrations.AddUuidsToCoreTables do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    alter table(:posts) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end

    create unique_index(:posts, [:uuid])

    alter table(:conversations) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end

    create unique_index(:conversations, [:uuid])

    alter table(:waves) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end

    create unique_index(:waves, [:uuid])
  end

  def down do
    alter table(:posts) do
      remove :uuid
    end

    alter table(:conversations) do
      remove :uuid
    end

    alter table(:waves) do
      remove :uuid
    end
  end
end
