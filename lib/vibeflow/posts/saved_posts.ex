defmodule Vibeflow.Posts.SavedPosts do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "saved_posts" do
    belongs_to :user, Vibeflow.Accounts.User
    belongs_to :post, Vibeflow.Posts.Post

    timestamps()
  end

  def changeset(saved_post, attrs) do
    saved_post
    |> cast(attrs, [:user_id, :post_id])
    |> validate_required([:user_id, :post_id])
    |> unique_constraint([:user_id, :post_id])
  end
end
