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

  @categories ["Tech", "Drama", "Fiction", "Fitness", "Science", "Fashion", "Food", "Politics", "Nature", "Couples", "Kids"]

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
          updated_at: DateTime.t() | nil,
          media_files: [map()]
        }

  schema "posts" do
    field :title, :string
    field :content, :string
    field :tags, {:array, :string}, default: []
    field :view_count, :integer, default: 0
    field :category, :string
    field :reposts_count, :integer, default: 0
    field :likes_count, :integer, default: 0
    field :is_featured, :boolean, virtual: true, default: false
    field :media_files, {:array, :map}, default: []  # JSON array of media files
    # Keep old fields for backward compatibility
    field :media_url, :string, virtual: true
    field :media_type, :string, virtual: true

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
      :media_files,
      :tags,
      :category,
      :user_id,
      :likes_count,
      :reposts_count
    ])
    |> validate_required([:title, :content, :user_id])
    |> validate_length(:title, min: 3, max: 200)
    |> validate_length(:content, min: 1, max: 10000)
    |> validate_inclusion(:category, @categories, message: "is not a valid category")
    |> validate_tags()
    |> validate_media_files()
    |> unique_constraint(:user_id, name: :posts_user_id_fkey)
  end

  # Validates the tags field.
  #
  # - Must be a list
  # - Each tag must be a string
  # - Each tag must be 20 characters or less
  # - Maximum of 5 tags allowed
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

  # Validates the media_files field.
  #
  # - Must be a list
  # - Each media file must be a map with url and type
  # - Maximum of 20 media files allowed
  @spec validate_media_files(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_media_files(changeset) do
    changeset
    |> get_field(:media_files, [])
    |> case do
      nil ->
        put_change(changeset, :media_files, [])

      media_files when is_list(media_files) ->
        cond do
          length(media_files) > 20 ->
            add_error(changeset, :media_files, "cannot have more than 20 media files")

          Enum.all?(media_files, fn media ->
            is_map(media) and
            is_binary(Map.get(media, "url")) and
            is_binary(Map.get(media, "type")) and
            Map.get(media, "type") in ["image", "video"]
          end) ->
            changeset

          true ->
            add_error(
              changeset,
              :media_files,
              "each media file must have a url and type (image or video)"
            )
        end

      _ ->
        add_error(changeset, :media_files, "must be a list of media objects")
    end
  end

  @doc """
  Ensures backward compatibility by converting old media fields to media_files format.
  This is called after loading a post from the database.
  """
  @spec ensure_media_files(t()) :: t()
  def ensure_media_files(%__MODULE__{} = post) do
    # If media_files is already populated, use it
    if post.media_files && post.media_files != [] do
      %{post | media_url: nil, media_type: nil}
    else
      # Convert old format to new format if present
      case {post.media_url, post.media_type} do
        {nil, _} ->
          %{post | media_files: []}
        {url, type} when is_binary(url) and is_binary(type) ->
          %{post | media_files: [%{"url" => url, "type" => type}], media_url: nil, media_type: nil}
        _ ->
          %{post | media_files: []}
      end
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
