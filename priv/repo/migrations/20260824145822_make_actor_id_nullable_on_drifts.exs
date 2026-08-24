defmodule Vibeflow.Repo.Migrations.MakeActorIdNullableOnDrifts do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE drifts ALTER COLUMN actor_id DROP NOT NULL"
  end
end