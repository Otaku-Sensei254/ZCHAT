defmodule Zchat.Socials.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, Zchat.Accounts.User
    belongs_to :following, Zchat.Accounts.User

    timestamps()
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :following_id])
    |> validate_required([:follower_id, :following_id])
    |> unique_constraint([:follower_id, :following_id], name: :follows_follower_id_following_id_index)
    |> validate_different_accounts()
  end

  defp validate_different_accounts(changeset) do
    follower_id = get_field(changeset, :follower_id)
    following_id = get_field(changeset, :following_id)

    if follower_id == following_id do
      add_error(changeset, :following_id, "You cannot follow yourself")
    else
      changeset
    end
  end
end
