defmodule Vibeflow.Socials.SocialAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  @platforms ~w(youtube instagram x twitch tiktok discord)

  schema "social_accounts" do
    field :platform, :string
    field :url, :string
    field :username, :string
    belongs_to :user, Vibeflow.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(social_account, attrs) do
    social_account
    |> cast(attrs, [:platform, :url, :username, :user_id])
    |> validate_required([:platform, :url, :username, :user_id])
    |> validate_inclusion(:platform, @platforms)
    |> unique_constraint([:user_id, :platform], message: "This platform is already linked.")
  end
end
