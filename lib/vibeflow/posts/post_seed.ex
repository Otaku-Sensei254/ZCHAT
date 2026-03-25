defmodule Vibeflow.Posts.PostSeed do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "post_seeds" do
    field :rippled, :boolean, default: false

    belongs_to :post, Vibeflow.Posts.Post
    belongs_to :user, Vibeflow.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(post_seed, attrs) do
    post_seed
    |> cast(attrs, [:post_id, :user_id, :rippled])
    |> validate_required([:post_id, :user_id])
    |> unique_constraint([:post_id, :user_id], name: :post_seeds_post_id_user_id_index)
  end
end
