defmodule VibeflowWeb.Api.V1.MusicController do
  use VibeflowWeb, :controller

  def create_track(conn, %{"music_track" => track_params}) do
    # Convert string keys to atoms and ensure itunes_track_id is integer
    attrs = %{
      title: track_params["title"],
      artist: track_params["artist"],
      audio_url: track_params["audio_url"],
      cover_art: track_params["cover_art"],
      itunes_track_id: String.to_integer(track_params["itunes_track_id"]),
      duration_ms: track_params["duration_ms"] && String.to_integer(track_params["duration_ms"])
    }

    case Vibeflow.Music.get_or_create_music_track(attrs) do
      {:ok, track} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{music_track: track_json(track)}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  defp track_json(track) do
    %{
      id: track.id,
      title: track.title,
      artist: track.artist,
      audio_url: track.audio_url,
      cover_art: track.cover_art,
      itunes_track_id: track.itunes_track_id,
      duration_ms: track.duration_ms
    }
  end

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", format_error_value(value))
      end)
    end)
  end

  defp format_error_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_error_value(value), do: to_string(value)
end
