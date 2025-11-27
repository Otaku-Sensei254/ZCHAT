defmodule Zchat.Posts do
  @moduledoc """
  The Posts context for handling blog posts, comments, and likes.
  """
  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Notifications
  alias Zchat.Posts.{Post, Like, Comment}

  # --- TRENDING ---

  @doc """
  Returns a list of trending posts from the last 24 hours.
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

  # --- MAIN FEED ---

  @doc """
  Returns a paginated list of posts with optional filtering.
  """
  def list_posts(opts \\ []) do
    page = opts[:page] || 1
    per_page = opts[:per_page] || opts[:limit] || 10 # Support 'limit' from profile    search_term = opts[:search]
    category = opts[:category]
    user_id = opts[:user_id]
    search_term = opts[:search]
    base_query =
      Post
      |> join(:inner, [p], u in assoc(p, :user)) # Join User table
      |> order_by([p], desc: p.inserted_at)

    base_query
    |> apply_filters(search_term, category)
    |> filter_by_user(user_id)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
    |> Repo.preload(opts[:preload] || [])
  end

  # --- DROPDOWN SEARCH ---

  @doc """
  Searches posts by title and content, returns up to 5 results.
  Used for the live search dropdown logic.
  """
  def search_posts(query) do
    pattern = "%#{query}%"

    from(p in Post,
      join: u in assoc(p, :user),
      # Searching Title or Content (using 'content' column)
      where: ilike(p.title, ^pattern) or ilike(p.content, ^pattern),
      preload: [:user],
      order_by: [desc: p.inserted_at],
      limit: 5
    )
    |> Repo.all()
  end

  # --- FILTER LOGIC ---

  defp apply_filters(query, search_term, category) do
    query
    |> filter_by_search(search_term)
    |> filter_by_category(category)
  end

  defp filter_by_user(query, nil), do: query
  defp filter_by_user(query, user_id) do
    from [p, u] in query, where: p.user_id == ^user_id
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query
  defp filter_by_search(query, term) do
    pattern = "%#{term}%"

    # Search: Title OR Content OR Username
    from [p, u] in query,
      where: ilike(p.title, ^pattern) or
             ilike(p.content, ^pattern) or
             ilike(u.username, ^pattern)
  end

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, ""), do: query
  defp filter_by_category(query, category) do
    # FIX: Use ilike so "Tech" matches "tech"
    from [p, u] in query, where: ilike(p.category, ^category)
  end

  # --- GETTING POSTS ---

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
  def get_post!(id, opts \\ []) do
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
    ["Tech", "Drama", "Fiction", "Fitness", "Sports", "Science", "Fashion", "Food", "Politics", "Business", "Nature", "Couples", "Kids"]
  end

  @doc """
  Gets a post with its associated data.
  """
  def get_post_with_associations(id) do
    Post
    |> Repo.get(id)
    |> Repo.preload([:user, :likes, comments: :user])
  end


  # --- POST CRUD ---

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


  # --- COMMENTS ---

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
    post_id = Keyword.get(opts, :post_id)
    parent_id = Keyword.get(opts, :parent_id)
    preload = Keyword.get(opts, :preload, [:user, :likes])

    query = from(c in Comment)
    query = if post_id, do: from(c in query, where: c.post_id == ^post_id), else: query
    query = if parent_id, do: from(c in query, where: c.parent_id == ^parent_id), else: query

    query
    |> preload(^preload)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a new comment and broadcasts the event.
  """
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


  # --- LIKES ---

  @doc """
  Creates a like for a post or comment and broadcasts the event.
  """
  def create_like(attrs \\ %{}) do
    %Like{}
    |> Like.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, like} ->
        update_like_count(like)

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
        update_like_count(like)

        like = Repo.preload(like, :user)

        cond do
          like.likeable_type == "Post" ->
            Phoenix.PubSub.broadcast(Zchat.PubSub, "post:#{like.likeable_id}", {:post_unliked, %{post_id: like.likeable_id, user_id: like.user_id}})
            Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:post_unliked, %{post_id: like.likeable_id, user_id: like.user_id}})
          like.likeable_type == "Comment" ->
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
  """
  def toggle_like(user_id, likeable_type, likeable_id) do
    case get_like_by_user_and_target(user_id, likeable_type, likeable_id) do
      nil ->
        create_like(%{
          user_id: user_id,
          likeable_type: likeable_type,
          likeable_id: likeable_id
        })

      like ->
        delete_like(like)
    end
  end


  # --- ANALYTICS / STATS ---

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
  """
  def count_top_tags(limit \\ 10) do
    from(p in Post,
      select: {fragment("unnest(?)", p.tags), count(p.id)},
      group_by: fragment("unnest(?)", p.tags),
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


  # --- PRIVATE HELPERS ---

  # Updates the likes_count on a Post
  defp update_like_count(%Like{likeable_type: "Post", likeable_id: post_id}) do
    count = Repo.aggregate(from(l in Like, where: l.likeable_id == ^post_id and l.likeable_type == "Post"), :count)
    from(p in Post, where: p.id == ^post_id) |> Repo.update_all(set: [likes_count: count])
    :ok
  end

  # Updates the likes_count on a Comment
  defp update_like_count(%Like{likeable_type: "Comment", likeable_id: comment_id}) do
    count = Repo.aggregate(from(l in Like, where: l.likeable_id == ^comment_id and l.likeable_type == "Comment"), :count)
    from(c in Comment, where: c.id == ^comment_id) |> Repo.update_all(set: [likes_count: count])
    :ok
  end

  defp update_like_count(_), do: :ok

  # View tracking functions
  def track_view(post_id, user_id) do
    case Repo.get(Post, post_id) do
      nil -> :ok
      post ->
        if post.user_id != user_id do
          from(p in Post, where: p.id == ^post_id)
          |> Repo.update_all(inc: [view_count: 1])
        else
          :ok
        end
    end
  end
end
