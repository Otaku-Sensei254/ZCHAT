defmodule Zchat.Socials do
  @moduledoc """
  The Socials context for handling social features like follows.
  """

  import Ecto.Query, warn: false
  alias Zchat.Repo

  alias Zchat.Socials.Follow
  alias Zchat.Notifications

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
      error -> error
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
    Repo.exists?(from f in Follow, where: f.follower_id == ^follower_id and f.following_id == ^following_id)
  end

  @doc """
  Gets the list of users that a user is following.
  """
  def list_following(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(f in Follow,
      where: f.follower_id == ^user_id,
      preload: [:following],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
    |> Enum.map(& &1.following)
  end

  @doc """
  Gets the list of users that are following a user.
  """
  def list_followers(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(f in Follow,
      where: f.following_id == ^user_id,
      preload: [:follower],
      limit: ^limit,
      offset: ^offset
    )
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
end
