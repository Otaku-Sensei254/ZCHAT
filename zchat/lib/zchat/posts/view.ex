defmodule Zchat.Posts.View do
  use Ecto.Schema
  import Ecto.Changeset

  schema "views" do
    belongs_to :post, Zchat.Posts.Post
    belongs_to :user, Zchat.Accounts.User

    timestamps()
  end

  def changeset(view, attrs) do
    view
    |> cast(attrs, [:post_id, :user_id])
    |> validate_required([:post_id, :user_id])
    |> unique_constraint([:post_id, :user_id], name: :views_post_id_user_id_index)
  end
end
