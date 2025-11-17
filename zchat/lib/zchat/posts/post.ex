defmodule Zchat.Posts.Post do
  @moduledoc """
  Post schema and changesets for the application.

  Handles:
  - Post creation and updates
  - Validations
  - Associations with users, comments, likes, and reposts
  - Tag management
  - Media handling
  """

  use Ecto.Schema
  import Ecto.Changeset

  @categories ["Tech", "Drama", "Science", "Fashion", "Food", "Politics", "Nature", "Couples", "Kids"]

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          content: String.t() | nil,
          media_url: String.t() | nil,
          media_type: String.t() | nil,
          tags: [String.t()],
          view_count: integer(),
          category: String.t() | nil,
          reposts_count: integer(),
          likes_count: integer(),
          user_id: integer() | nil,
          user: any(),
          comments: [any()],
          likes: [any()],
          reposts: [any()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "posts" do
    field :title, :string
    field :content, :string
    field :media_url, :string
    field :media_type, :string
    field :tags, {:array, :string}, default: []
    field :view_count, :integer, default: 0
    field :category, :string
    field :reposts_count, :integer, default: 0
    field :likes_count, :integer, default: 0
    field :is_featured, :boolean, virtual: true, default: false

    belongs_to :user, Zchat.Accounts.User
    has_many :reposts, Zchat.Posts.Repost, on_delete: :delete_all
    has_many :comments, Zchat.Posts.Comment, on_delete: :delete_all
    has_many :likes, Zchat.Posts.Like,
  foreign_key: :likeable_id,
  on_replace: :delete,
  where: [likeable_type: "Post"]

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid post categories.
  """
  @spec categories() :: [String.t()]
  def categories, do: @categories

  @doc """
  A post changeset for creating and updating posts.

  ## Required Fields
  - title: String (3-200 chars)
  - content: String (1-500 chars)
  - user_id: ID of the user creating the post

  ## Optional Fields
  - media_url: URL to the media content
  - media_type: "image" or "video"
  - tags: List of strings (max 20 chars each)
  - category: Must be one of the predefined categories
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :content,
      :media_url,
      :media_type,
      :tags,
      :category,
      :user_id,
      :likes_count,
      :reposts_count
    ])
    |> validate_required([:title, :content, :user_id])
    |> validate_length(:title, min: 3, max: 200)
    |> validate_length(:content, min: 1, max: 10000)
    |> validate_inclusion(:media_type, ["image", "video", nil])
    |> validate_inclusion(:category, @categories, message: "is not a valid category")
    |> validate_tags()
    |> unique_constraint(:user_id, name: :posts_user_id_fkey)
  end

  @doc """
  Validates the tags field.

  - Must be a list
  - Each tag must be a string
  - Each tag must be 20 characters or less
  - Maximum of 5 tags allowed
  """
  @spec validate_tags(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_tags(changeset) do
    changeset
    |> get_field(:tags, [])
    |> case do
      nil ->
        changeset

      tags when is_list(tags) and length(tags) > 5 ->
        add_error(changeset, :tags, "cannot have more than 5 tags")

      tags when is_list(tags) ->
        if Enum.all?(tags, &(is_binary(&1) and String.length(&1) <= 20)) do
          # Convert all tags to lowercase and trim whitespace
          normalized_tags = Enum.map(tags, &String.trim/1) |> Enum.map(&String.downcase/1)
          put_change(changeset, :tags, normalized_tags)
        else
          add_error(
            changeset,
            :tags,
            "must be a list of strings, each 20 characters or less"
          )
        end

      _ ->
        add_error(changeset, :tags, "must be a list of strings")
    end
  end

  @doc """
  Increments the view count for a post.
  """
  @spec increment_view_count(t()) :: t()
  def increment_view_count(post) do
    post
    |> change(view_count: post.view_count + 1)
  end
end
