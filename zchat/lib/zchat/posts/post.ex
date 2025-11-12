defmodule Zchat.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :content, :string
    field :media_url, :string
    field :media_type, :string
    field :tags, {:array, :string}, default: []

    belongs_to :user, Zchat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :content, :media_url, :media_type, :tags])
    |> validate_required([:title])
    |> validate_length(:title, min: 3, max: 200)
    |> validate_inclusion(:media_type, ["image", "video", nil])
    |> validate_tags()
  end

  defp validate_tags(changeset) do
    case get_change(changeset, :tags) do
      nil -> changeset
      tags when is_list(tags) ->
        if Enum.all?(tags, &is_binary/1) do
          changeset
        else
          add_error(changeset, :tags, "must be a list of strings")
        end
      _ ->
        add_error(changeset, :tags, "must be a list")
    end
  end
end
