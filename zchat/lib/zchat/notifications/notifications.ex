defmodule Zchat.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :read_at, :naive_datetime

    belongs_to :user, Zchat.Accounts.User
    belongs_to :actor, Zchat.Accounts.User
    belongs_to :post, Zchat.Posts.Post

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :read_at, :user_id, :actor_id, :post_id])
    |> validate_required([:type, :user_id, :actor_id])
  end
end
