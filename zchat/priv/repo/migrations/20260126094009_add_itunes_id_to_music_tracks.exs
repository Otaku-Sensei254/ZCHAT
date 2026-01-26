defmodule Zchat.Repo.Migrations.AddItunesIdToMusicTracks do
  use Ecto.Migration

  def change do
    alter table(:music_tracks) do
      # Using bigint is safer for external IDs in case they get very large
      add :itunes_track_id, :bigint
    end

    # Optional: Add an index if you plan to search by this ID often (which your query is doing)
    create index(:music_tracks, [:itunes_track_id])
  end
end
