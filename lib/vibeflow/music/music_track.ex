defmodule Vibeflow.Music.MusicTrack do
  use Ecto.Schema
  import Ecto.Changeset

  schema "music_tracks" do
    field :title, :string
    field :artist, :string
    field :audio_url, :string
    field :cover_art, :string
    field :itunes_track_id, :integer # To store the original iTunes track ID
    field :duration_ms, :integer # Duration of the track in milliseconds

    timestamps()
  end

  @doc false
  def changeset(music_track, attrs) do
    music_track
    |> cast(attrs, [:title, :artist, :audio_url, :cover_art, :itunes_track_id, :duration_ms])
    |> validate_required([:title, :artist, :audio_url, :cover_art, :itunes_track_id])
    |> unique_constraint(:itunes_track_id)
  end
end