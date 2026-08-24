defmodule Vibeflow.Repo.Migrations.CreateDriftInteractions do
  use Ecto.Migration

  def change do
    create table(:drift_interactions) do
      add :drift_id, references(:drifts, on_delete: :delete_all), null: false
      add :actor_id, references(:users, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :payload, :map, default: %{}
      timestamps()
    end

    create index(:drift_interactions, [:drift_id, :actor_id])
    create index(:drift_interactions, [:actor_id])
    create index(:drift_interactions, [:drift_id, :type])
  end
end