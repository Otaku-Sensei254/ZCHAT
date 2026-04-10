defmodule Vibeflow.Music do
  @moduledoc """
  The Music context.
  """

  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Music.MusicTrack

  @doc """
  Returns the list of music_tracks.
  """
  def list_music_tracks do
    Repo.all(MusicTrack)
  end

  @doc """
  Gets a single music_track by its track_id (iTunes track ID).
  """
  def get_music_track_by_itunes_id(itunes_track_id) do
    Repo.get_by(MusicTrack, itunes_track_id: itunes_track_id)
  end

  @doc """
  Creates a music_track.
  """
  def create_music_track(attrs) do
    %MusicTrack{}
    |> MusicTrack.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets or creates a music_track.
  If a music_track with the given iTunes ID already exists, it returns it.
  Otherwise, it creates a new one.
  """
  def get_or_create_music_track(attrs) do
    case get_music_track_by_itunes_id(attrs.itunes_track_id) do
      nil ->
        create_music_track(attrs)

      music_track ->
        # If track exists, update it with new attrs (e.g., duration_ms might be new)
        music_track
        |> MusicTrack.changeset(attrs)
        |> Repo.update()
    end
  end
end
