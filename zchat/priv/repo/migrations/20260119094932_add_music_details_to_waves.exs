defmodule Zchat.Repo.Migrations.AddMusicDetailsToWaves do
  use Ecto.Migration

  def change do
    alter table(:waves) do
      add :music_preview_url, :string
      add :music_title, :string
      add :music_artist, :string
      add :music_cover_url, :string
      # You might want to remove the old column if you aren't using it anymore
      # remove :music_track_id
    end
  end
end
