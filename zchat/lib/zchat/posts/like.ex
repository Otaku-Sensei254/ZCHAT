defmodule Zchat.Posts.Like do
  use Ecto.Schema
  import Ecto.Changeset

  alias Zchat.Accounts.User

  schema "likes" do
    field :likeable_type, :string
    field :likeable_id, :id

    belongs_to :user, User

    # We remove belongs_to :post and belongs_to :comment
    # because :likeable_id and :likeable_type replace them.

    timestamps()
  end

  @doc false
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :likeable_type, :likeable_id])
    |> validate_required([:user_id, :likeable_type, :likeable_id])
    |> foreign_key_constraint(:user_id)
    # This ensures a user can only like a specific item (post or comment) once
    |> unique_constraint([:user_id, :likeable_type, :likeable_id], name: :user_likeable_unique_index)
  end

  # We remove the after_insert and after_delete callbacks
  # because that logic is already (and more correctly) handled
  # in your Zchat.Posts context (the file that is crashing).
end
