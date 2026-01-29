defmodule Zchat.Repo.Migrations.CreateWaveViews do
  use Ecto.Migration

  def change do
    create table(:wave_views) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :wave_id, references(:waves, on_delete: :delete_all)
      timestamps(updated_at: false)
    end

    create unique_index(:wave_views, [:user_id, :wave_id])
  end
end
