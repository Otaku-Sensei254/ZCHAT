defmodule VibeflowWeb.Api.V1.PostController do
  use VibeflowWeb, :controller
  import Ecto.Query

  def show(conn, %{"uuid" => uuid}) do
    current_user = conn.assigns[:current_user]
    case Vibeflow.Posts.get_post_by_uuid(uuid, preload: [:user, :likes, :reposts, comments: [:user, :likes]]) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        is_liked = current_user && Enum.any?(post.likes || [], &(&1.user_id == current_user.id))
        is_reposted = current_user && Enum.any?(post.reposts || [], &(&1.user_id == current_user.id))
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
          post_detail_json(post, current_user)
          |> Map.merge(%{
            is_liked: is_liked || false,
            is_reposted: is_reposted || false,
            is_saved: is_saved || false,
            is_following: is_following || false,
            seed_count: seed.seed_count,
            rippled_count: seed.rippled_count
          })
        }})
    end
  end

  def create(conn, %{"post" => post_params}) do
    user = conn.assigns.current_user
    params = Map.put(post_params, "user_id", user.id)

    case Vibeflow.Posts.create_post(user, params) do
      {:ok, post} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{post: post_json(post)}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  def update(conn, %{"uuid" => uuid, "post" => post_params}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        if post.user_id == user.id do
          case Vibeflow.Posts.update_post(post, post_params) do
            {:ok, updated} ->
              json(conn, %{data: %{post: post_json(updated)}})
            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{errors: format_changeset(changeset)})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Not your post"})
        end
    end
  end

  def delete(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        if post.user_id == user.id do
          {:ok, _} = Vibeflow.Posts.delete_post(post)
          json(conn, %{data: %{message: "Post deleted"}})
        else
          conn |> put_status(:forbidden) |> json(%{error: "Not your post"})
        end
    end
  end

  def like(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        {:ok, _} = Vibeflow.Posts.toggle_like(user.id, "Post", post.id)
        json(conn, %{data: %{liked: true}})
    end
  end

  def repost(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        {:ok, {status, _}} = Vibeflow.Posts.toggle_repost(user.id, post.id)
        json(conn, %{data: %{reposted: status == :reposted}})
    end
  end

  def save(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        {:ok, result} = Vibeflow.Posts.toggle_save_post(user.id, post.id)
        json(conn, %{data: %{saved: elem(result, 0) == :saved}})
    end
  end

  def share(conn, %{"uuid" => uuid, "recipient_ids" => recipient_ids, "message" => message}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        result = Vibeflow.Chat.share_post_to_friends(user.id, post.id, recipient_ids, message)
        case result do
          {:ok, _messages} ->
            json(conn, %{data: %{shared: true}})
          {:error, reason} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: reason})
        end
    end
  end

  def share(conn, %{"uuid" => uuid, "recipient_ids" => recipient_ids}) do
    share(conn, %{"uuid" => uuid, "recipient_ids" => recipient_ids, "message" => ""})
  end

  def track_view(conn, %{"uuid" => uuid}) do
    user_id = if conn.assigns[:current_user], do: conn.assigns[:current_user].id
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        Vibeflow.Posts.track_view(post.id, user_id)
        json(conn, %{data: %{viewed: true}})
    end
  end

  def create_comment(conn, %{"uuid" => uuid, "comment" => comment_params}) do
    user = conn.assigns.current_user
    case Vibeflow.Posts.get_post_by_uuid(uuid) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
      post ->
        params = Map.merge(comment_params, %{"user_id" => user.id, "post_id" => post.id})
        case Vibeflow.Posts.create_comment(params) do
          {:ok, comment} ->
            conn
            |> put_status(:created)
            |> json(%{data: %{comment: comment_json(comment)}})
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_changeset(changeset)})
        end
    end
  end

  def delete_comment(conn, %{"comment_id" => comment_id}) do
    user = conn.assigns.current_user
    comment = Vibeflow.Posts.get_comment!(comment_id, preload: [:user, post: :user])
    post = Vibeflow.Posts.get_post!(comment.post_id)
    if comment.user_id == user.id || post.user_id == user.id do
      {:ok, _} = Vibeflow.Posts.delete_comment(comment)
      json(conn, %{data: %{message: "Comment deleted"}})
    else
      conn |> put_status(:forbidden) |> json(%{error: "Not your comment"})
    end
  end

  def update_comment(conn, %{"comment_id" => comment_id, "comment" => params}) do
    user = conn.assigns.current_user
    comment = Vibeflow.Posts.get_comment!(comment_id, preload: [:user])
    if comment.user_id == user.id do
      case Vibeflow.Posts.update_comment(comment, params) do
        {:ok, updated} ->
          json(conn, %{data: %{comment: comment_json(updated)}})
        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: format_changeset(changeset)})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Not your comment"})
    end
  end

  def like_comment(conn, %{"comment_id" => comment_id}) do
    user = conn.assigns.current_user
    {:ok, _} = Vibeflow.Posts.toggle_like(user.id, "Comment", comment_id)
    json(conn, %{data: %{liked: true}})
  end

  def pin_comment(conn, %{"comment_id" => comment_id}) do
    user = conn.assigns.current_user
    comment = Vibeflow.Posts.get_comment!(comment_id, preload: [:user, post: :user])
    if comment.post.user_id == user.id do
      case Vibeflow.Posts.pin_comment(comment) do
        {:ok, pinned} ->
          json(conn, %{data: %{comment: comment_json(pinned)}})
        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: format_changeset(changeset)})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Not your post"})
    end
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
      user: user_json(post.user),
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp post_detail_json(post, current_user \\ nil) do
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
      likes_count: length(post.likes || []),
      comments_count: length(post.comments || []),
      user: user_json(post.user),
      comments: Enum.map(post.comments || [], &comment_json(&1, current_user)),
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp comment_json(comment, current_user \\ nil) do
    likes_list = Map.get(comment, :likes, []) || []
    is_liked = current_user && Enum.any?(likes_list, &(&1.user_id == current_user.id))
    %{
      id: comment.id,
      content: comment.content,
      user: user_json(comment.user),
      parent_id: comment.parent_id,
      pinned: comment.pinned,
      likes_count: Map.get(comment, :likes_count, 0),
      inserted_at: comment.inserted_at,
      is_liked: is_liked || false
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

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", format_error_value(value))
      end)
    end)
  end

  defp format_error_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_error_value(value), do: to_string(value)

  defp clean_media_files(nil), do: []
  defp clean_media_files(files) do
    Enum.filter(files, fn f ->
      url = f["url"] || f[:url] || ""
      url != "" && !String.contains?(url, "cloudinary.com")
    end)
  end
end
