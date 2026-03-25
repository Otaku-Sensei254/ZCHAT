defmodule Vibeflow.Posts.Repost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reposts" do
    belongs_to :user, Vibeflow.Accounts.User
    belongs_to :post, Vibeflow.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a repost.
  """
  def changeset(repost, attrs) do
    repost
    |> cast(attrs, [:user_id, :post_id])
    |> validate_required([:user_id, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:user_id, :post_id], name: :user_id_post_id_unique_index)
  end
end
