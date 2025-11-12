defmodule Zchat.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Posts.Post

  @doc """
  Returns the list of posts.
  """
  def list_posts do
    Post
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Gets a single post.
  """
  def get_post!(id) do
    Post
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  @doc """
  Creates a post.
  """
def create_post(user, attrs) do
  user
  |> Ecto.build_assoc(:posts)
  |> Post.changeset(attrs)
  |> Repo.insert()
end

  @doc """
  Updates a post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end
end
