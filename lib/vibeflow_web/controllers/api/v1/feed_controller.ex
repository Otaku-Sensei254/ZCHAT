defmodule VibeflowWeb.Api.V1.FeedController do
  use VibeflowWeb, :controller
  import Ecto.Query

  def index(conn, params) do
    page = params["page"] || "1"
    per_page = params["per_page"] || "20"
    search = params["search"]
    category = params["category"]

    opts = [
      page: String.to_integer(page),
      per_page: String.to_integer(per_page),
      search: search,
      category: category
    ]

    current_user = conn.assigns[:current_user]
    posts = if current_user do
      Vibeflow.Posts.list_feed_for_user(current_user.id, opts)
    else
      Vibeflow.Posts.list_posts(opts)
    end

    json(conn, %{
      data: %{
        posts: enrich_posts(posts, current_user),
        page: String.to_integer(page)
      }
    })
  end

  def trending(conn, params) do
    limit = params["limit"] || "20"
    posts = Vibeflow.Posts.list_trending_posts(String.to_integer(limit))
    json(conn, %{data: %{posts: Enum.map(posts, &post_json/1)}})
  end

  def categories(conn, _params) do
    json(conn, %{data: %{categories: Vibeflow.Posts.categories()}})
  end

  def search_posts(conn, %{"q" => query}) do
    posts = Vibeflow.Posts.search_posts(query)
    json(conn, %{data: %{posts: Enum.map(posts, &post_json/1)}})
  end

  def search_posts(conn, _params) do
    json(conn, %{data: %{posts: []}})
  end

  def tags(conn, _params) do
    tags = Vibeflow.Posts.count_top_tags(20)
    json(conn, %{data: %{tags: Enum.map(tags, fn {tag, count} -> %{name: tag, count: count} end)}})
  end

  def category_counts(conn, _params) do
    counts = Vibeflow.Posts.count_posts_by_category()
    json(conn, %{data: %{categories: Enum.map(counts, fn {cat, count} -> %{name: cat, count: count} end)}})
  end

  def suggestions(conn, _params) do
    user = conn.assigns[:current_user]

    suggested_users = if user do
      following = Vibeflow.Accounts.get_user_following(user.id)
      following_ids = Enum.map(following, & &1.id)
      Vibeflow.Accounts.suggest_users(user.id, following_ids, 5)
    else
      []
    end

    suggested_posts = Vibeflow.Posts.list_trending_posts(5)

    json(conn, %{
      data: %{
        users: Enum.map(suggested_users, &user_json/1),
        posts: Enum.map(suggested_posts, &post_json/1)
      }
    })
  end

  defp enrich_posts(posts, nil), do: Enum.map(posts, &post_json/1)

  defp enrich_posts(posts, current_user) do
    post_ids = Enum.map(posts, & &1.id)

    seed_data = if post_ids != [] do
      Vibeflow.Repo.all(
        from(ps in Vibeflow.Posts.PostSeed,
          where: ps.post_id in ^post_ids,
          group_by: ps.post_id,
          select: %{
            post_id: ps.post_id,
            seed_count: count(ps.user_id, :distinct),
            rippled_count: count(ps.user_id, :distinct) |> filter(ps.rippled == true)
          }
        )
      )
      |> Map.new(fn row -> {row.post_id, row} end)
    else
      %{}
    end

    saved_post_ids = Vibeflow.Repo.all(
      from(sp in Vibeflow.Posts.SavedPosts,
        where: sp.user_id == ^current_user.id and sp.post_id in ^post_ids,
        select: sp.post_id
      )
    ) |> MapSet.new()

    Enum.map(posts, fn post ->
      is_liked = Enum.any?(post.likes || [], &(&1.user_id == current_user.id))
      is_reposted = Enum.any?(post.reposts || [], &(&1.user_id == current_user.id))
      is_saved = MapSet.member?(saved_post_ids, post.id)
      seeds = Map.get(seed_data, post.id, %{seed_count: 0, rippled_count: 0})

      post_json(post)
      |> Map.put(:is_liked, is_liked)
      |> Map.put(:is_reposted, is_reposted)
      |> Map.put(:is_saved, is_saved)
      |> Map.put(:seed_count, seeds.seed_count)
      |> Map.put(:rippled_count, seeds.rippled_count)
    end)
  end

  defp post_json(post) do
    %{
      id: post.id,
      uuid: post.uuid,
      title: post.title,
      content: post.content,
      media_files: clean_media_files(post.media_files),
      tags: post.tags || [],
      category: post.category,
      view_count: post.view_count,
      reposts_count: post.reposts_count,
      saves_count: post.saves_count || 0,
      likes_count: Map.get(post, :likes_count, 0),
      comments_count: Map.get(post, :comments_count, 0),
      is_featured: Map.get(post, :is_featured, false),
      user: user_json(post.user),
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp user_json(user) do
    %{
      id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      bio: user.bio,
      is_verified: user.is_verified,
      username_style: user.username_style
    }
  end

  defp clean_media_files(nil), do: []
  defp clean_media_files(files) do
    Enum.filter(files, fn f ->
      url = f["url"] || f[:url] || ""
      !String.contains?(url, "cloudinary.com")
    end)
  end
end
