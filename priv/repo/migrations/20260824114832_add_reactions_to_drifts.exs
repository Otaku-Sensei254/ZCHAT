defmodule Vibeflow.Repo.Migrations.AddReactionsToDrifts do
  use Ecto.Migration

  def change do
    alter table(:drifts) do
      add :reactions, {:array, :map}, default: []
    end
  end
end
