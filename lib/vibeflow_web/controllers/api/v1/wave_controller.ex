defmodule VibeflowWeb.Api.V1.WaveController do
  use VibeflowWeb, :controller

  def index(conn, _params) do
    user = conn.assigns[:current_user]
    if user do
      waves = Vibeflow.Waves.list_active_waves(user.id)
      json(conn, %{data: %{groups: Enum.map(waves, &group_json(&1, user))}})
    else
      json(conn, %{data: %{groups: []}})
    end
  end

  def create(conn, %{"wave" => wave_params}) do
    user = conn.assigns.current_user
    params = Map.put(wave_params, "user_id", user.id)

    case Vibeflow.Waves.create_wave(params) do
      {:ok, wave} ->
        wave = Vibeflow.Repo.preload(wave, [:user, :music_track])
        conn
        |> put_status(:created)
        |> json(%{data: %{wave: wave_json(wave, user)}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  def show_user_waves(conn, %{"username" => username}) do
    user = conn.assigns[:current_user]
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      target_user ->
        waves = Vibeflow.Waves.list_user_waves(target_user.id)
        json(conn, %{data: %{waves: Enum.map(waves, &wave_json(&1, user))}})
    end
  end

  def mark_viewed(conn, %{"uuid" => uuid}) do
    current_user = conn.assigns.current_user
    case Vibeflow.Waves.get_wave_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Wave not found"})
      wave ->
        Vibeflow.Waves.mark_wave_as_seen(current_user.id, wave.id)
        json(conn, %{data: %{viewed: true}})
    end
  end

  def like(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user
    wave = Vibeflow.Waves.get_wave_by_uuid(uuid)

    if wave do
      {status, _} = Vibeflow.Posts.toggle_like(user.id, "Wave", wave.id)
      likes_count = Vibeflow.Posts.count_likes("Wave", wave.id)
      json(conn, %{data: %{liked: status == :liked, likes_count: likes_count}})
    else
      conn |> put_status(:not_found) |> json(%{error: "Wave not found"})
    end
  end

  defp group_json(group, user) do
    %{
      user: user_json(group.user),
      waves: Enum.map(group.waves, &wave_json(&1, user)),
      has_unseen: Map.get(group, :has_unseen, true)
    }
  end

  defp wave_json(wave, user) do
    %{
      id: wave.id,
      uuid: wave.uuid,
      media_url: wave.media_url,
      media_type: wave.media_type || "image",
      caption: wave.caption,
      user: user_json(wave.user),
      inserted_at: wave.inserted_at,
      expires_at: wave.expires_at,
      is_liked: user && Vibeflow.Posts.is_liked?(user.id, "Wave", wave.id) || false,
      likes_count: Vibeflow.Posts.count_likes("Wave", wave.id),
      music_track: music_track_json(wave.music_track)
    }
  end

  defp music_track_json(nil), do: nil

  defp music_track_json(track) do
    %{
      id: track.id,
      title: track.title,
      artist: track.artist,
      audio_url: track.audio_url,
      cover_art: track.cover_art
    }
  end

  defp user_json(user) do
    %{
      id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      is_verified: user.is_verified
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
