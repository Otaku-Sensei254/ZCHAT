defmodule VibeflowWeb.Api.V1.DriftController do
  use VibeflowWeb, :controller
  alias Vibeflow.Drifts

  def index(conn, _params) do
    user = conn.assigns[:current_user]
    drifts = if user, do: Drifts.get_feed_drifts(user), else: []
    json(conn, %{data: %{drifts: Enum.map(drifts, &drift_json/1)}})
  end

  def show(conn, %{"id" => id}) do
    drift = Drifts.get_drift!(id)
    json(conn, %{data: %{drift: drift_detail_json(drift)}})
  end

  def create(conn, %{"drift" => drift_params}) do
    user = conn.assigns.current_user
    case Drifts.create_drift(user, drift_params) do
      {:ok, drift} ->
        json(conn, %{data: %{drift: drift_json(drift)}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  def react(conn, %{"id" => id, "emoji" => emoji}) do
    user = conn.assigns.current_user
    drift = Drifts.get_drift!(id)
    case Drifts.react_to_drift(drift, user, emoji) do
      :ok ->
        drift = Drifts.get_drift!(id)
        json(conn, %{data: %{drift: drift_detail_json(drift)}})
      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not react"})
    end
  end

  def remove_reaction(conn, %{"id" => id, "emoji" => emoji}) do
    user = conn.assigns.current_user
    drift = Drifts.get_drift!(id)
    case Drifts.remove_reaction(drift, user, emoji) do
      :ok ->
        drift = Drifts.get_drift!(id)
        json(conn, %{data: %{drift: drift_detail_json(drift)}})
      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not remove reaction"})
    end
  end

  def reply(conn, %{"id" => id, "reply" => reply_params}) do
    user = conn.assigns.current_user
    drift = Drifts.get_drift!(id)
    case Drifts.reply_to_drift(drift, user, reply_params) do
      {:ok, interaction} ->
        drift = Drifts.get_drift!(id)
        json(conn, %{data: %{drift: drift_detail_json(drift)}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    drift = Drifts.get_drift!(id)
    if drift.user_id == user.id do
      Drifts.delete_drift(drift)
      json(conn, %{data: %{message: "Drift deleted successfully"}})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "You can only delete your own drifts"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    drift = Drifts.get_drift!(id)
    if drift.user_id == user.id do
      case Drifts.update_drift(drift, params["drift"] || %{}) do
        {:ok, updated_drift} ->
          json(conn, %{data: %{drift: drift_detail_json(updated_drift)}})
        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset(changeset)})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "You can only edit your own drifts"})
    end
  end

  defp drift_json(drift) do
    %{
      id: drift.id,
      uuid: drift.uuid,
      note: drift.note,
      song_name: drift.song_name,
      reactions: drift.reactions,
      inserted_at: drift.inserted_at,
      user: user_json(drift.user)
    }
  end

  defp drift_detail_json(drift) do
    drift_json(drift)
    |> Map.merge(%{
      interactions: Enum.map(drift.interactions, &interaction_json/1)
    })
  end

  defp interaction_json(interaction) do
    %{
      id: interaction.id,
      type: interaction.type,
      payload: interaction.payload,
      inserted_at: interaction.inserted_at,
      actor: user_json(interaction.actor)
    }
  end

  defp user_json(%Ecto.Association.NotLoaded{}), do: nil
  defp user_json(user) do
    %{
      id: user.id,
      uuid: user.uuid,
      username: user.username,
      avatar_url: user.avatar_url,
      is_verified: user.is_verified,
      username_style: user.username_style
    }
  end

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end