defmodule Vibeflow.Repo.Migrations.AddSharedWaveToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :shared_wave_id, references(:waves, on_delete: :nothing)
    end

    create index(:messages, [:shared_wave_id])
  end
end
