defmodule Zchat.Notifications do
  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Notifications.Notification

  # --- READS ---

  def list_user_notifications(user_id, limit \\ 10) do
    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      preload: [:actor, :post]
    )
    |> Repo.all()
  end

  def unread_count(user_id) do
    Repo.aggregate(
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      :count
    )
  end

  # --- WRITES ---

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notif} ->
        notif = Repo.preload(notif, [:actor, :post])
        # Broadcast generic event to trigger UI refresh
        Phoenix.PubSub.broadcast(Zchat.PubSub, "notifications:#{notif.user_id}", :new_notification)
        {:ok, notif}
      error -> error
    end
  end

  def mark_as_read(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil -> {:error, :not_found}
      notification ->
        {:ok, updated} =
          notification
          |> Ecto.Changeset.change(read_at: NaiveDateTime.utc_now())
          |> Repo.update()

        # Broadcast update
        Phoenix.PubSub.broadcast(Zchat.PubSub, "notifications:#{updated.user_id}", :update_notifications)
        {:ok, updated}
    end
  end

  def mark_all_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: NaiveDateTime.utc_now()])

    Phoenix.PubSub.broadcast(Zchat.PubSub, "notifications:#{user_id}", :update_notifications)
  end

  # --- HELPERS ---

  def notify_followers_of_new_post(post) do
    alias Zchat.Socials
    followers = Socials.get_followers_for_notifications(post.user_id)

    Enum.each(followers, fn follower ->
      create_notification(%{
        type: "new_post",
        user_id: follower.id,
        actor_id: post.user_id,
        post_id: post.id
      })
    end)
  end
end
