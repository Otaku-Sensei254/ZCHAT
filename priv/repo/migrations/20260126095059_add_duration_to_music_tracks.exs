defmodule Zchat.Repo.Migrations.AddDurationToMusicTracks do
  use Ecto.Migration

  def change do
    alter table(:music_tracks) do
      add :duration_ms, :integer
    end
  end
end
