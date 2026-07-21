defmodule VibeflowWeb.Api.V1.CurrentController do
  use VibeflowWeb, :controller
  import Ecto.Query

  def index(conn, params) do
    current_user = conn.assigns[:current_user]
    tab = params["tab"] || "all"
    page = String.to_integer(params["page"] || "1")
    per_page = String.to_integer(params["per_page"] || "20")

    posts = cond do
      tab == "following" and current_user ->
        Vibeflow.Posts.list_currents_for_user(current_user.id, page: page, per_page: per_page)
      true ->
        Vibeflow.Posts.list_currents(page: page, per_page: per_page)
    end

    enriched = enrich_currents(posts, current_user)

    json(conn, %{
      data: %{
        posts: enriched,
        page: page
      }
    })
  end

  def show(conn, %{"uuid" => uuid}) do
    current_user = conn.assigns[:current_user]

    case Vibeflow.Posts.get_post_by_uuid(uuid, preload: [:user, :likes, :reposts, comments: [:user, :likes]]) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Current not found"})
      post ->
        if post.content_type != "current" do
          conn |> put_status(:not_found) |> json(%{error: "Current not found"})
        else
          is_liked = current_user && Enum.any?(post.likes || [], &(&1.user_id == current_user.id))
          is_saved = current_user && Vibeflow.Repo.exists?(
            from(sp in Vibeflow.Posts.SavedPosts,
              where: sp.user_id == ^current_user.id and sp.post_id == ^post.id
            )
          )
          is_following = current_user && Vibeflow.Socials.following?(current_user.id, post.user_id)

          seed = Vibeflow.Repo.one(
            from(ps in Vibeflow.Posts.PostSeed,
              where: ps.post_id == ^post.id,
              select: %{
                seed_count: count(ps.user_id, :distinct),
                rippled_count: count(ps.user_id, :distinct) |> filter(ps.rippled == true)
              }
            )
          ) || %{seed_count: 0, rippled_count: 0}

          json(conn, %{data: %{post:
            post_json(post)
            |> Map.merge(%{
              is_liked: is_liked || false,
              is_saved: is_saved || false,
              is_following: is_following || false,
              seed_count: seed.seed_count,
              rippled_count: seed.rippled_count
            })
          }})
        end
    end
  end

  def create(conn, %{"current" => current_params}) do
    user = conn.assigns.current_user
    params = Map.put(current_params, "user_id", user.id)
    params = Map.put(params, "content_type", "current")

    case Vibeflow.Posts.create_post(user, params) do
      {:ok, post} ->
        post = Vibeflow.Repo.preload(post, [:user])
        conn
        |> put_status(:created)
        |> json(%{data: %{post: post_json(post)}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not create current", errors: changeset_errors(changeset)})
    end
  end

  defp enrich_currents(posts, nil), do: Enum.map(posts, &post_json/1)

  defp enrich_currents(posts, current_user) do
    post_ids = Enum.map(posts, & &1.id)

    saved_post_ids = if post_ids != [] do
      Vibeflow.Repo.all(
        from(sp in Vibeflow.Posts.SavedPosts,
          where: sp.user_id == ^current_user.id and sp.post_id in ^post_ids,
          select: sp.post_id
        )
      ) |> MapSet.new()
    else
      MapSet.new()
    end

    author_ids = Enum.map(posts, & &1.user_id) |> Enum.uniq()

    followed_author_ids = if author_ids != [] do
      Vibeflow.Repo.all(
        from f in Vibeflow.Socials.Follow,
          where: f.follower_id == ^current_user.id and f.following_id in ^author_ids,
          select: f.following_id
      )
      |> MapSet.new()
    else
      MapSet.new()
    end

    Enum.map(posts, fn post ->
      is_liked = Enum.any?(post.likes || [], &(&1.user_id == current_user.id))
      is_saved = MapSet.member?(saved_post_ids, post.id)
      is_following = MapSet.member?(followed_author_ids, post.user_id)

      post_json(post)
      |> Map.put(:is_liked, is_liked)
      |> Map.put(:is_saved, is_saved)
      |> Map.put(:is_following, is_following)
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
      content_type: post.content_type,
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

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
