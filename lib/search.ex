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
      select: %{type: :user, id: u.id, title: u.username, image: u.avatar_url, sub: u.bio}
    )
    |> Repo.all()

    # 2. Search Posts
    # FIXED: Using 'content' here
    posts = from(p in Post,
      join: u in assoc(p, :user),
      where: ilike(p.title, ^search_term) or ilike(p.content, ^search_term),
      limit: 5,
      select: %{type: :post, id: p.id, title: p.title, image: nil, sub: u.username}
    )
    |> Repo.all()

    users ++ posts
  end
end
