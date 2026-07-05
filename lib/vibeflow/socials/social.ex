defmodule Vibeflow.Socials do
  @moduledoc """
  The Socials context for handling social features like follows.
  """

  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Posts
  alias Vibeflow.Socials.Follow
  alias Vibeflow.Notifications

  @doc """
  Creates a follow relationship.
  """
  def create_follow(%{follower_id: follower_id, following_id: following_id}) do
    %Follow{}
    |> Follow.changeset(%{follower_id: follower_id, following_id: following_id})
    |> Repo.insert()
    |> case do
      {:ok, follow} ->
        # Create notification for the followed user
        Notifications.create_notification(%{
          type: "follow",
          user_id: following_id,
          actor_id: follower_id
        })

        {:ok, follow}

      error ->
        error
    end
  end

  @doc """
  Deletes a follow relationship.
  """
  def delete_follow(follower_id, following_id) do
    from(f in Follow, where: f.follower_id == ^follower_id and f.following_id == ^following_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      follow -> Repo.delete(follow)
    end
  end

  @doc """
  Returns if a user is following another user.
  """
  def following?(follower_id, following_id) do
    Repo.exists?(
      from f in Follow, where: f.follower_id == ^follower_id and f.following_id == ^following_id
    )
  end

  @doc """
  Gets the list of users that a user is following with search functionality.
  """
  def list_following(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    search = Keyword.get(opts, :search, nil)

    query =
      from(f in Follow,
        where: f.follower_id == ^user_id,
        preload: [:following],
        limit: ^limit,
        offset: ^offset
      )

    query =
      if search && search != "" do
        from(f in query,
          join: following in assoc(f, :following),
          where:
            ilike(following.username, ^"%#{search}%") or ilike(following.email, ^"%#{search}%")
        )
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.map(& &1.following)
  end

  @doc """
  Gets the list of users that are following a user with search functionality.
  """
  def list_followers(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    search = Keyword.get(opts, :search, nil)

    query =
      from(f in Follow,
        where: f.following_id == ^user_id,
        preload: [:follower],
        limit: ^limit,
        offset: ^offset
      )

    query =
      if search && search != "" do
        from(f in query,
          join: follower in assoc(f, :follower),
          where: ilike(follower.username, ^"%#{search}%") or ilike(follower.email, ^"%#{search}%")
        )
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.map(& &1.follower)
  end

  @doc """
  Gets follow count for a user.
  """
  def get_follow_stats(user_id) do
    following_count = Repo.aggregate(from(f in Follow, where: f.follower_id == ^user_id), :count)
    followers_count = Repo.aggregate(from(f in Follow, where: f.following_id == ^user_id), :count)

    %{
      following_count: following_count,
      followers_count: followers_count
    }
  end

  @doc """
  Gets users that the current user follows to notify them of new posts
  """
  def get_followers_for_notifications(post_user_id) do
    from(f in Follow,
      where: f.following_id == ^post_user_id,
      preload: [:follower]
    )
    |> Repo.all()
    |> Enum.map(& &1.follower)
  end

  def share(post_id, _user_id) do
    _target_post = Posts.get_post!(post_id)
    # TODO: Implement sharing logic
  end

  # --- SOCIAL ACCOUNTS ---

  alias Vibeflow.Socials.SocialAccount

  def list_social_accounts(user_id) do
    from(sa in SocialAccount, where: sa.user_id == ^user_id)
    |> Repo.all()
  end

  def create_social_account(user, attrs) do
    current_count =
      from(sa in SocialAccount, where: sa.user_id == ^user.id, select: count(sa.id))
      |> Repo.one()

    if current_count >= 3 do
      {:error, :social_limit_reached}
    else
      platform = attrs["platform"] || attrs[:platform]
      username = attrs["username"] || attrs[:username]

      username = normalize_username(platform, username)

      url = build_social_url(platform, username)

      attrs =
        attrs
        |> Map.put("url", url)
        |> Map.put("user_id", user.id)

      %SocialAccount{}
      |> SocialAccount.changeset(attrs)
      |> Repo.insert()
    end
  end

  def get_social_account!(id) do
    Repo.get!(SocialAccount, id)
  end

  def delete_social_account(id) do
    Repo.get!(SocialAccount, id) |> Repo.delete()
  end

  defp build_social_url("youtube", username), do: "https://youtube.com/@#{username}"
  defp build_social_url("instagram", username), do: "https://instagram.com/#{username}"
  defp build_social_url("x", username), do: "https://x.com/#{username}"
  defp build_social_url("twitch", username), do: "https://twitch.tv/#{username}"
  defp build_social_url("tiktok", username), do: "https://tiktok.com/@#{username}"
  # Discord doesn't have a simple public profile URL by username
  defp build_social_url("discord", username), do: username
  defp build_social_url(_, username), do: username

  defp normalize_username(platform, username) do
    username =
      username
      |> to_string()
      |> String.trim()
      |> String.replace_prefix("https://", "")
      |> String.replace_prefix("http://", "")
      |> String.replace_prefix("www.", "")

    username =
      case platform do
        "youtube" ->
          username
          |> String.replace_prefix("youtube.com/@", "")
          |> String.replace_prefix("youtube.com/c/", "")
          |> String.replace_prefix("youtube.com/user/", "")

        "instagram" ->
          String.replace_prefix(username, "instagram.com/", "")

        "x" ->
          String.replace_prefix(username, "x.com/", "")

        "twitch" ->
          String.replace_prefix(username, "twitch.tv/", "")

        "tiktok" ->
          username
          |> String.replace_prefix("tiktok.com/@", "")
          |> String.replace_prefix("tiktok.com/", "")

        _ ->
          username
      end

    String.trim_leading(username, "@")
  end

  def get_social_prefix("youtube"), do: "youtube.com/@"
  def get_social_prefix("instagram"), do: "instagram.com/"
  def get_social_prefix("x"), do: "x.com/"
  def get_social_prefix("twitch"), do: "twitch.tv/"
  def get_social_prefix("tiktok"), do: "tiktok.com/@"
  def get_social_prefix("discord"), do: "Username: "
  def get_social_prefix(_), do: ""
end
