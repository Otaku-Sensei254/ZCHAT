defmodule Vibeflow.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :read_at, :naive_datetime

    belongs_to :user, Vibeflow.Accounts.User
    belongs_to :actor, Vibeflow.Accounts.User
    belongs_to :post, Vibeflow.Posts.Post
    belongs_to :conversation, Vibeflow.Chat.Conversation
    timestamps()
  end

  def changeset(notification, attrs) do
    notification
  |> cast(attrs, [:type, :user_id, :actor_id, :post_id, :read_at, :conversation_id])
   |> validate_required([:type, :user_id, :actor_id])
  end
end
