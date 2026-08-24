defmodule Vibeflow.Repo.Migrations.CreateNotesForUsers do
  use Ecto.Migration

  def change do
    create table(:drifts) do
      add :note, :string
      add :song_name, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :actor_id, references(:users, on_delete: :delete_all), null: false
      add :replies, {:array, :map}, default: []

      timestamps()
    end
  end
end
