defmodule Zchat.Repo.Migrations.CreateWavesTables do
  use Ecto.Migration

  def change do
    # 1. Music Tracks Table
    create table(:music_tracks) do
      add :title, :string
      add :artist, :string
      add :audio_url, :string
      add :cover_art, :string
      timestamps()
    end

    # 2. Waves (Stories) Table
    create table(:waves) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :music_track_id, references(:music_tracks)
      add :media_url, :string
      add :media_type, :string, default: "image"
      add :caption, :string
      add :expires_at, :utc_datetime
      add :music_preview_url, :string
      add :music_title, :string
      add :music_artist, :string
      add :music_cover_url, :string
      timestamps()
    end

    create index(:waves, [:user_id])
  end
end
