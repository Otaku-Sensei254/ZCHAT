defmodule Zchat.Posts do
  @modledoc """
  The Posts context for handling blog posts, comments, and likes.
  """
  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Notifications
  alias Zchat.Posts.{Post, Like, Comment}
  # Removed unused alias Zchat.Accounts.User

  @doc """
  Returns a list of trending posts from the last 24 hours, ordered by number of likes.
  ...
  """
  def list_trending_posts(limit \\ 5)

  def list_trending_posts(limit) when is_integer(limit) and limit > 0 do
    one_day_ago = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)

    from(p in Post,
      where: p.inserted_at >= ^one_day_ago,
      left_join: l in assoc(p, :likes),
      group_by: p.id,
      order_by: [desc: count(l.id), desc: p.inserted_at],
      limit: ^limit,
      preload: [:user, :likes]
    )
    |> Repo.all()
  end

  def list_trending_posts(opts) when is_list(opts) do
    opts
    |> Keyword.get(:limit, 5)
    |> list_trending_posts()
  end

  @doc """
  Returns a paginated list of posts with optional filtering.
  """
  def list_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    category = Keyword.get(opts, :category)
    user_id = Keyword.get(opts, :user_id)
    preload = Keyword.get(opts, :preload, [:user])
    search_term = Keyword.get(opts, :search)

    query = from p in Post,
      order_by: [desc: p.inserted_at],
      preload: ^preload

    query = if category do
      from p in query, where: p.category == ^category
    else
      query
    end

    query = if user_id do
      from p in query, where: p.user_id == ^user_id
    else
      query
    end

    query = if search_term && search_term != "" do
      search_pattern = "%#{search_term}%"
      from p in query,
        left_join: u in assoc(p, :user),
        where:
          ilike(fragment("COALESCE(?, '')", p.title), ^search_pattern) or
          ilike(fragment("COALESCE(?, '')", u.username), ^search_pattern) or
          fragment("EXISTS (SELECT 1 FROM unnest(?) AS tag WHERE tag ILIKE ?)", p.tags, ^search_pattern),
        distinct: true
    else
      query
    end

    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
    |> Repo.all()
  end


  @doc """
  Gets a single post and increments its view count.
  """
  def get_post_with_views!(id) do
    post =
      Post
      |> Repo.get!(id)
      |> Repo.preload([:user, :likes, comments: :user])
      |> Post.ensure_media_files()

    # Increment view count
    from(p in Post, where: p.id == ^id)
    |> Repo.update_all(inc: [view_count: 1])

    post
  end

  @doc """
  Gets a single post with preloaded associations.
  """
  def get_post!(id, opts \\ [])

  def get_post!(id, opts) do
    preload = Keyword.get(opts, :preload, [:user, :likes, comments: :user])

    Post
    |> Repo.get!(id)
    |> Repo.preload(preload)
    |> Post.ensure_media_files()
  end

  @doc """
  Gets all categories.
  """
  def categories do
    ["Tech", "Drama", "Fiction", "Fitness", "Science", "Fashion", "Food", "Politics", "Nature", "Couples", "Kids"]
  end

  @doc """
  Gets a post with its associated data.
  """
  def get_post_with_associations(id) do
    Post
    |> Repo.get(id)
    |> Repo.preload([:user, :likes, comments: :user])
  end


  @doc """
  Creates a post, associating it with the user and broadcasting the event.
  """
  def create_post(user, attrs) do
    user
    |> Ecto.build_assoc(:posts)
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, post} ->
        post = Repo.preload(post, :user)
        # Notify followers of new post
        Notifications.notify_followers_of_new_post(post)
        Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:new_post, post})
        Phoenix.PubSub.broadcast(Zchat.PubSub, "admin:stats", {:post_created, post})
        {:ok, post}
      error -> error
    end
  end

  @doc """
  Updates a post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.
  """
def delete_post(%Post{} = post) do
    Repo.delete(post)
    |> case do
      {:ok, post} ->
        # This triggers the update in FeedLive
        Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:post_deleted, post})
        # This triggers the update in Admin Dashboard
        Phoenix.PubSub.broadcast(Zchat.PubSub, "admin:stats", {:post_deleted, post})
        {:ok, post}
      error -> error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  # Comments

  @doc """
  Gets a single comment.
  """
  def get_comment!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes])

    Comment
    |> Repo.get!(id)
    |> Repo.preload(preload)
  end



  @doc """
  Lists comments with optional filtering.
  """
  def list_comments(opts \\ []) do
    _page = Keyword.get(opts, :page, 1)
    _per_page = Keyword.get(opts, :per_page, 10)
    post_id = Keyword.get(opts, :post_id)
    parent_id = Keyword.get(opts, :parent_id)
    preload = Keyword.get(opts, :preload, [:user, :likes])

    query = from(c in Comment)
    query = if post_id, do: from(c in query, where: c.post_id == ^post_id), else: query
    query = if parent_id, do: from(c in query, where: c.parent_id == ^parent_id), else: query

    query
    |> preload(^preload)
    |> order_by(desc: :inserted_at)
    |> Repo.all() # FIX: Replaced Repo.paginate, which was causing a crash.

  end

  @doc """
  Creates a new comment and broadcasts the event.
  """
 # ... inside lib/posts.ex

  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, :user)
        # This broadcast is what triggers handle_info in SinglePostLive
        Phoenix.PubSub.broadcast(Zchat.PubSub, "post:#{comment.post_id}", {:new_comment, comment})
        Phoenix.PubSub.broadcast(Zchat.PubSub, "admin:stats", {:comment_created, comment})

        unless comment.post_id |> get_post!() |> Map.get(:user_id) == comment.user_id do
          post = get_post!(comment.post_id)
          Notifications.create_notification(%{
            type: "comment",
            user_id: post.user_id,
            actor_id: comment.user_id,
            post_id: post.id
          })
        end

        {:ok, comment}
      error -> error
    end
  end
  @doc """
  Updates a comment.
  """
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a comment.
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Returns a comment changeset.
  """
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end

  #helper function for comments form


  # Likes

  @doc """
  Creates a like for a post or comment and broadcasts the event.
  """
  def create_like(attrs \\ %{}) do
    %Like{}
    |> Like.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, like} ->
        # Update the like count on the liked item
        update_like_count(like)

        # Broadcast the like event
        like = Repo.preload(like, :user)

        unless like.likeable_type == "Post" and Repo.get(Post, like.likeable_id) |> Map.get(:user_id) == like.user_id do
          Notifications.create_notification(%{
            type: "like",
            user_id: Repo.get(Post, like.likeable_id) |> Map.get(:user_id),
            actor_id: like.user_id,
            post_id: like.likeable_id
          })
        end

        cond do
          like.likeable_type == "Post" ->
            Phoenix.PubSub.broadcast(Zchat.PubSub, "post:#{like.likeable_id}", {:post_liked, like})
            Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:post_liked, like})
          like.likeable_type == "Comment" ->
            # Get the comment to find its post_id
            comment = Repo.get(Comment, like.likeable_id)
            if comment do
              Phoenix.PubSub.broadcast(Zchat.PubSub, "post:#{comment.post_id}", {:comment_liked, like})
            end
        end

        {:ok, like}
      error -> error
    end
  end

  @doc """
  Removes a like.
  """
  def delete_like(%Like{} = like) do
    Repo.delete(like)
    |> case do
      {:ok, like} ->
        # Update the like count on the unliked item
        update_like_count(like)

        # Broadcast the unlike event
        like = Repo.preload(like, :user)

        cond do
          like.likeable_type == "Post" ->
            Phoenix.PubSub.broadcast(Zchat.PubSub, "post:#{like.likeable_id}", {:post_unliked, %{post_id: like.likeable_id, user_id: like.user_id}})
            Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:post_unliked, %{post_id: like.likeable_id, user_id: like.user_id}})
          like.likeable_type == "Comment" ->
            # Get the comment to find its post_id
            comment = Repo.get(Comment, like.likeable_id)
            if comment do
              Phoenix.PubSub.broadcast(Zchat.PubSub, "post:#{comment.post_id}", {:comment_unliked, %{comment_id: like.likeable_id, user_id: like.user_id}})
            end
        end

        {:ok, like}
      error -> error
    end
  end

  @doc """
  Gets a like by user and target (post or comment).
  """
  def get_like_by_user_and_target(user_id, target_type, target_id) do
    Repo.get_by(Like, user_id: user_id, likeable_type: target_type, likeable_id: target_id)
  end

  @doc """
  Toggles a like for a post or comment.
  Returns {:ok, like} if liked, {:ok, nil} if unliked, or {:error, changeset} if there was an error.
  """
  def toggle_like(user_id, likeable_type, likeable_id) do
    case get_like_by_user_and_target(user_id, likeable_type, likeable_id) do
      nil ->
        # Like doesn't exist, create it
        create_like(%{
          user_id: user_id,
          likeable_type: likeable_type,
          likeable_id: likeable_id
        })

      like ->
        # Like exists, remove it
        delete_like(like)
    end
  end



  #posts analystics for admin dashboard
  @doc """
  Returns a list of tuples: {category_name, count}
  """
  def count_posts_by_category do
    from(p in Post,
      where: not is_nil(p.category),
      group_by: p.category,
      select: {p.category, count(p.id)},
      order_by: [desc: count(p.id)]
    )
    |> Repo.all()
  end

  @doc """
  Returns a list of tuples: {tag_name, count}
  Unnests the tags array to count individual tag usage.
  """
  def count_top_tags(limit \\ 10) do
    from(p in Post,
      # 1. Select the unnested tag and the count of posts
      select: {fragment("unnest(?)", p.tags), count(p.id)},

      # 2. Group by that same unnested value
      group_by: fragment("unnest(?)", p.tags),

      # 3. Order by popularity
      order_by: [desc: count(p.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Get high-level counts for the top of the dashboard.
  """
  def get_system_stats do
    %{
      total_posts: Repo.aggregate(Post, :count),
      total_comments: Repo.aggregate(Comment, :count),
      total_users: Repo.aggregate(Zchat.Accounts.User, :count)
    }
  end

  # Private functions

  # FIX: Correctly updates the likes_count on a Post
  defp update_like_count(%Like{likeable_type: "Post", likeable_id: post_id}) do
    count = Repo.aggregate(from(l in Like, where: l.likeable_id == ^post_id and l.likeable_type == "Post"), :count)
    from(p in Post, where: p.id == ^post_id) |> Repo.update_all(set: [likes_count: count])
    :ok
  end

  # FIX: Correctly updates the likes_count on a Comment
  defp update_like_count(%Like{likeable_type: "Comment", likeable_id: comment_id}) do
    count = Repo.aggregate(from(l in Like, where: l.likeable_id == ^comment_id and l.likeable_type == "Comment"), :count)
    from(c in Comment, where: c.id == ^comment_id) |> Repo.update_all(set: [likes_count: count])
    :ok
  end

  defp update_like_count(_), do: :ok # Catches any other case

  # View tracking functions
  def track_view(post_id, user_id) do
    # Only increment view count if viewer is not the post author
    case Repo.get(Post, post_id) do
      nil ->
        :ok  # Post doesn't exist
      post ->
        if post.user_id != user_id do
          from(p in Post, where: p.id == ^post_id)
          |> Repo.update_all(inc: [view_count: 1])
        else
          :ok  # Don't count views from the author
        end
    end
  end
end
