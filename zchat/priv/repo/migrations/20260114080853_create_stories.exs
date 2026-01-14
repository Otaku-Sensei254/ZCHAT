defmodule Zchat.Repo.Migrations.CreateStories do
  use Ecto.Migration

  def change do
    create table(:stories) do
      add :media_url, :string
      add :media_type, :string
      add :caption, :string
      add :music_preview_url, :string
      add :music_title, :string
      add :music_artist, :string
      add :music_cover_url, :string
      add :expires_at, :utc_datetime
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:stories, [:user_id])
  end
end
