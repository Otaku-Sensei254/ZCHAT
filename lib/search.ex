defmodule Vibeflow.Search do
  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Accounts.User
  alias Vibeflow.Posts.Post

  def global_search(query) when byte_size(query) < 2, do: []

  def global_search(query) do
    search_term = "%#{query}%"

    # 1. Search Users
    users = from(u in User,
      where: ilike(u.username, ^search_term),
      limit: 5,
      select: %{
        type: :user,
        id: u.id,
        title: u.username,
        image: u.avatar_url,
        sub: u.bio,
        is_verified: u.is_verified
      }
    )
    |> Repo.all()

    # 2. Search Posts by content/title
    content_posts = from(p in Post,
      join: u in assoc(p, :user),
      where: ilike(p.title, ^search_term) or ilike(p.content, ^search_term),
      limit: 3,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(fn post ->
      thumbnail_url = extract_thumbnail_url(post.media_files)
      media_type = extract_media_type(post.media_files)
      %{type: :post, id: post.id, uuid: post.uuid, title: post.title, image: thumbnail_url, media_type: media_type, sub: post.user.username}
    end)

    # 3. Search Posts by username
    username_posts = from(p in Post,
      join: u in assoc(p, :user),
      where: ilike(u.username, ^search_term),
      limit: 3,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(fn post ->
      thumbnail_url = extract_thumbnail_url(post.media_files)
      media_type = extract_media_type(post.media_files)
      %{type: :post_by_user, id: post.id, uuid: post.uuid, title: post.title, image: thumbnail_url, media_type: media_type, sub: post.user.username}
    end)

    users ++ content_posts ++ username_posts
  end

  # Helper function to extract thumbnail URL from media_files
  defp extract_thumbnail_url(nil), do: nil
  defp extract_thumbnail_url([]), do: nil
  defp extract_thumbnail_url(media_files) when is_list(media_files) do
    case Enum.at(media_files, 0) do
      %{"url" => url} -> url
      _ -> nil
    end
  end
  defp extract_thumbnail_url(_), do: nil

  # Helper function to extract media type from media_files
  defp extract_media_type(nil), do: nil
  defp extract_media_type([]), do: nil
  defp extract_media_type(media_files) when is_list(media_files) do
    case Enum.at(media_files, 0) do
      %{"type" => type} -> type
      _ -> nil
    end
  end
  defp extract_media_type(_), do: nil
end
