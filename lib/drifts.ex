defmodule Vibeflow.Drifts do
  import Ecto.Query, warn: false
  alias Vibeflow.Accounts
  alias Vibeflow.Repo
  alias Vibeflow.Notifications
  alias Vibeflow.Drifts.{Drifts, DriftInteraction}
  alias Vibeflow.Socials

  # --- FEED ---

  @doc """
  Gets live drifts (last 24h) for a user's feed: their drifts + friends' drifts.
  """
  def get_feed_drifts(user) do
    user_id = if is_map(user) and user.__struct__ == Vibeflow.Accounts.User do
      user.id
    else
      user
    end

    friend_ids = get_friend_ids(user_id)

    query = from d in Drifts,
      where: d.inserted_at > ^DateTime.add(DateTime.utc_now(), -1, :day),
      where: d.user_id in ^([user_id | friend_ids]),
      order_by: [desc: d.inserted_at],
      preload: [:user, interactions: [:actor]],
      limit: 50

    Repo.all(query)
  end

  # --- SINGLE DRIFT ---

  @doc """
  Gets a drift by integer ID or UUID string.
  """
  def get_drift!(id_or_uuid) do
    cond do
      is_integer(id_or_uuid) ->
        Repo.get!(Drifts, id_or_uuid) |> Repo.preload([:user, interactions: [:actor]])

      is_binary(id_or_uuid) ->
        case Ecto.UUID.cast(id_or_uuid) do
          {:ok, uuid} ->
            Repo.get_by!(Drifts, uuid: uuid) |> Repo.preload([:user, interactions: [:actor]])
          :error ->
            Repo.get!(Drifts, String.to_integer(id_or_uuid)) |> Repo.preload([:user, interactions: [:actor]])
        end

      true ->
        raise ArgumentError, "invalid drift id"
    end
  end

  # --- CREATE ---

  @doc """
  Creates a new drift for the given user.
  """
  def create_drift(user, attrs) do
    %Drifts{}
    |> Drifts.changeset(Map.put(attrs || %{}, :user_id, user.id))
    |> Repo.insert()
  end

  # --- UPDATE ---

  @doc """
  Updates a drift with the given attributes.
  """
  def update_drift(drift, attrs) do
    drift
    |> Drifts.changeset(attrs)
    |> Repo.update()
  end

  # --- DELETE ---

  @doc """
  Deletes a drift.
  """
  def delete_drift(drift) do
    Repo.delete(drift)
  end

  # --- INTERACTIONS ---

  @doc """
  Reacts to a drift with an emoji. Creates interaction, updates cached reactions, notifies author.
  """
  def react_to_drift(drift, actor, emoji) when is_binary(emoji) do
    Repo.transaction(fn ->
      # 1. Create interaction record
      %DriftInteraction{}
      |> DriftInteraction.changeset(%{
        drift_id: drift.id,
        actor_id: actor.id,
        type: "reaction",
        payload: %{emoji: emoji}
      })
      |> Repo.insert!()

      # 2. Update cached reactions on drift
      update_drift_reactions(drift)

      # 3. Notify author (if not self)
      if drift.user_id != actor.id do
        Notifications.create_notification(%{
          type: "drift_reaction",
          user_id: drift.user_id,
          actor_id: actor.id,
          data: %{drift_id: drift.id, drift_uuid: drift.uuid, emoji: emoji}
        })
      end
    end)
  end

  @doc """
  Removes a reaction from a drift (actor removes their own reaction).
  """
  def remove_reaction(drift, actor, emoji) do
    Repo.transaction(fn ->
      # Delete the specific reaction interaction
      Repo.delete_all(from i in DriftInteraction,
        where: i.drift_id == ^drift.id and i.actor_id == ^actor.id and i.type == "reaction" and i.payload["emoji"] == ^emoji
      )

      # Update cached reactions
      update_drift_reactions(drift)
    end)
  end

  @doc """
  Records a view interaction (for analytics).
  """
  def record_view(drift, actor) do
    %DriftInteraction{}
    |> DriftInteraction.changeset(%{
      drift_id: drift.id,
      actor_id: actor.id,
      type: "view",
      payload: %{}
    })
    |> Repo.insert()
  end

  @doc """
  Replies to a drift. Creates interaction, notifies author.
  """
  def reply_to_drift(drift, actor, params) do
    content = params["content"] || params[:content]
    if content && content != "" do
      Repo.transaction(fn ->
        %DriftInteraction{}
        |> DriftInteraction.changeset(%{
          drift_id: drift.id,
          actor_id: actor.id,
          type: "reply",
          payload: %{content: content}
        })
        |> Repo.insert!()

        if drift.user_id != actor.id do
          Notifications.create_notification(%{
            type: "drift_reply",
            user_id: drift.user_id,
            actor_id: actor.id,
            data: %{drift_id: drift.id, drift_uuid: drift.uuid, content: content}
          })
        end
      end)
    else
      {:error, "Reply content required"}
    end
  end

  # --- PRIVATE ---

  defp get_friend_ids(user_id) do
    user_id = if is_map(user_id) and user_id.__struct__ == Vibeflow.Accounts.User do
      user_id.id
    else
      user_id
    end

    Socials.list_following(user_id)
    |> Enum.map(& &1.id)
  end

  defp update_drift_reactions(drift) do
    reactions = Repo.all(from i in DriftInteraction,
      where: i.drift_id == ^drift.id and i.type == "reaction",
      select: i.payload["emoji"]
    )
    |> Enum.frequencies()
    |> Enum.map(fn {emoji, count} -> %{"emoji" => emoji, "count" => count} end)

    Drifts.changeset(drift, %{reactions: reactions})
    |> Repo.update!()
  end
end