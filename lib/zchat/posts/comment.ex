defmodule Zchat.Posts.Comment do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Zchat.Repo

  schema "comments" do
    field :content, :string
    field :likes_count, :integer, default: 0
    belongs_to :user, Zchat.Accounts.User
    belongs_to :post, Zchat.Posts.Post
    belongs_to :parent, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_id
    has_many :likes, Zchat.Posts.Like,
  foreign_key: :likeable_id,
  on_replace: :delete,
  where: [likeable_type: "Comment"]

    timestamps()
  end

  @doc """
  Builds a changeset for a comment.
  """
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :user_id, :post_id, :parent_id, :likes_count])
    |> validate_required([:content, :user_id, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:parent_id)
  end

  @doc """
  Builds a query for listing comments with optional preloading.
  """
  def list_comments_query(opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes])
    post_id = Keyword.get(opts, :post_id)
    parent_id = Keyword.get(opts, :parent_id)
    order_by = Keyword.get(opts, :order_by, [desc: :inserted_at])

    query = from(c in __MODULE__)

    query =
      case {post_id, parent_id} do
        {nil, nil} ->
          query
        {post_id, nil} ->
          from c in query, where: c.post_id == ^post_id and is_nil(c.parent_id)
        {nil, parent_id} ->
          from c in query, where: c.parent_id == ^parent_id
        {post_id, parent_id} ->
          from c in query, where: c.post_id == ^post_id and c.parent_id == ^parent_id
      end

    from c in query,
      order_by: ^order_by,
      preload: ^preload
  end

  @doc """
  Returns the base query for listing comments.
  """
  def base_query do
    from(c in __MODULE__)
  end

  @doc """
  Preloads associations for the given comment or comments.
  """
  def preload_assocs(comments_or_comment, assocs \\ [:user, :replies, :likes])

  def preload_assocs(comments, assocs) when is_list(comments) do
    Repo.preload(comments, assocs)
  end

  def preload_assocs(comment, assocs) do
    Repo.preload(comment, assocs)
  end
end
