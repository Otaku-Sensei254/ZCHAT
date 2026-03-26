defmodule Vibeflow.Posts.Seeder do
  @moduledoc """
  Handles Ripple Effect seeding and expansion for posts.
  """
  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Accounts.User
  alias Vibeflow.Socials.Follow
  alias Vibeflow.Posts.PostSeed

  @default_seed_count 15

  def assign_initial_seeds(post_id, creator_id) do
    user_ids =
      from(f in Follow,
        where: f.following_id == ^creator_id,
        join: u in User,
        on: u.id == f.follower_id,
        order_by: fragment("RANDOM()"),
        limit: ^@default_seed_count,
        select: u.id
      )
      |> Repo.all()

    insert_seeds(post_id, user_ids)
  end

  def expand_seeds(post_id, creator_id, count) do
    expand_seeds(post_id, creator_id, creator_id, count)
  end

  def expand_seeds(post_id, creator_id, source_user_id, count) when is_integer(count) and count > 0 do
    existing_ids =
      from(ps in PostSeed,
        where: ps.post_id == ^post_id,
        select: ps.user_id
      )

    new_user_ids =
      from(f in Follow,
        where: f.following_id == ^source_user_id,
        join: u in User,
        on: u.id == f.follower_id,
        where: u.id != ^creator_id and u.id not in subquery(existing_ids),
        order_by: fragment("RANDOM()"),
        limit: ^count,
        select: u.id
      )
      |> Repo.all()

    insert_seeds(post_id, new_user_ids)
  end

  def expand_seeds(_post_id, _creator_id, _source_user_id, _count), do: {:ok, 0}

  def backfill_followed_posts_for_user(user_id, limit \\ 50) do
    followed_ids =
      from(f in Follow,
        where: f.follower_id == ^user_id,
        select: f.following_id
      )

    post_ids =
      from(p in Vibeflow.Posts.Post,
        where: p.user_id in subquery(followed_ids),
        left_join: ps in PostSeed,
        on: ps.post_id == p.id and ps.user_id == ^user_id,
        where: is_nil(ps.user_id),
        order_by: [desc: p.inserted_at],
        limit: ^limit,
        select: p.id
      )
      |> Repo.all()

    insert_seeds_for_user(user_id, post_ids)
  end

  defp insert_seeds(_post_id, []), do: {:ok, 0}

  defp insert_seeds(post_id, user_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(user_ids, fn user_id ->
        %{
          post_id: post_id,
          user_id: user_id,
          rippled: false,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(PostSeed, entries,
        on_conflict: :nothing,
        conflict_target: [:post_id, :user_id]
      )

    {:ok, count}
  end

  defp insert_seeds_for_user(_user_id, []), do: {:ok, 0}

  defp insert_seeds_for_user(user_id, post_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(post_ids, fn post_id ->
        %{
          post_id: post_id,
          user_id: user_id,
          rippled: false,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(PostSeed, entries,
        on_conflict: :nothing,
        conflict_target: [:post_id, :user_id]
      )

    {:ok, count}
  end
end
