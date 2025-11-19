#----------NOTIFICATIONS CONTEXT MODULE -----------

defmodule Zchat.Notifications do
  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Notifications.Notification

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

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notif} ->
        # Broadcast to the specific user's topic
        notif = Repo.preload(notif, [:actor, :post])
        Phoenix.PubSub.broadcast(Zchat.PubSub, "notifications:#{notif.user_id}", {:new_notification, notif})
        {:ok, notif}
      error -> error
    end
  end

    def mark_all_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: NaiveDateTime.utc_now()])

    Phoenix.PubSub.broadcast(Zchat.PubSub, "notifications:#{user_id}", :notifications_read)
  end

  def list_unread_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      preload: [:actor, :post]
    )
    |> Repo.all()
  end

  def get_unread_count(user_id) do
    Repo.aggregate(
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      :count
    )
  end

  def mark_as_read(notification_id) do
    from(n in Notification, where: n.id == ^notification_id)
    |> Repo.update_all(set: [read_at: NaiveDateTime.utc_now()])
    |> case do
      {1, _} -> {:ok, :marked}
      {0, _} -> {:error, :not_found}
    end
  end

  def mark_all_as_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: NaiveDateTime.utc_now()])

    Phoenix.PubSub.broadcast(Zchat.PubSub, "notifications:#{user_id}", :notifications_read)
  end

  @doc """
  Creates notifications for all followers of a user when they make a new post
  """
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
