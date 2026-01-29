defmodule Zchat.Posts do
  @moduledoc """
  The Posts context for handling blog posts, comments, and likes.
  """
  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Notifications
  alias Zchat.Posts.{Post, Like, Comment}

  # --- TRENDING ---

  def list_trending_posts(limit \\ 5)

  def list_trending_posts(limit) when is_integer(limit) and limit > 0 do
    one_day_ago = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)

    from(p in Post,
      where: p.inserted_at >= ^one_day_ago,
      left_join: l in assoc(p, :likes),
      left_join: c in assoc(p, :comments),
      join: u in assoc(p, :user),
      group_by: [p.id, u.id],
      order_by: [desc: count(l.id, :distinct), desc: p.inserted_at],
      limit: ^limit,
      select_merge: %{
        likes_count: count(l.id, :distinct),
        comments_count: count(c.id, :distinct)
      },
      preload: [:user, :likes, comments: :user]
    )
    |> Repo.all()
  end

  def list_trending_posts(opts) when is_list(opts) do
    opts
    |> Keyword.get(:limit, 5)
    |> list_trending_posts()
  end

  # --- MAIN FEED ---

  def list_posts(opts \\ []) do
    page = opts[:page] || 1
    per_page = opts[:per_page] || opts[:limit] || 10
    search_term = opts[:search]
    category = opts[:category]
    user_id = opts[:user_id]

    base_query =
      from(p in Post,
        join: u in assoc(p, :user),
        left_join: l in assoc(p, :likes),
        left_join: c in assoc(p, :comments),
        group_by: [p.id, u.id],
        order_by: [desc: p.inserted_at],
        select_merge: %{
          likes_count: count(l.id, :distinct),
          comments_count: count(c.id, :distinct)
        }
      )

    query =
      base_query
      |> apply_filters(search_term, category)
      |> filter_by_user(user_id)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))

    posts = Repo.all(query)

    # Preload associations efficiently
    posts
    |> Repo.preload([:user, :likes, comments: :user])
  end

  # --- SEARCH & FILTERS ---

  def search_posts(query) do
    pattern = "%#{query}%"

    from(p in Post,
      join: u in assoc(p, :user),
      where: ilike(p.title, ^pattern) or ilike(p.content, ^pattern),
      preload: [:user],
      order_by: [desc: p.inserted_at],
      limit: 5
    )
    |> Repo.all()
  end

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
    from [p, u] in query,
      where: ilike(p.title, ^pattern) or
             ilike(p.content, ^pattern) or
             ilike(u.username, ^pattern)
  end

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, ""), do: query
  defp filter_by_category(query, category) do
    from [p, u] in query, where: ilike(p.category, ^category)
  end

  # --- GETTING POSTS ---

  def get_post_with_views!(id) do
    post =
      Post
      |> Repo.get!(id)
      |> Repo.preload([:user, :likes, comments: :user])
      |> Post.ensure_media_files()

    from(p in Post, where: p.id == ^id)
    |> Repo.update_all(inc: [view_count: 1])

    post
  end

  def list_fresh_random_posts(limit \\ 20, days_ago \\ 5) do
    cutoff_date =  DateTime.add(DateTime.utc_now(), -days_ago, :day)

    from(p in Post,
              where: p.inserted_at >= ^cutoff_date,
              order_by: fragment("RANDOM()"),
              limit: ^limit,
              preload: [:user, :likes]
          )
          |> Repo.all()
  end

  def get_post!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes, comments: :user])

    Post
    |> Repo.get!(id)
    |> Repo.preload(preload)
    |> Post.ensure_media_files()
  end

  def categories do
    ["Tech", "Drama", "Action", "Fiction", "Music","Fitness", "Sports", "Thrills", "Science", "Fashion", "Beauty","Gossip","Food", "Politics", "Business", "Comedy", "Nature", "Couples", "Kids"]
  end

  def get_post_with_associations(id) do
    Post
    |> Repo.get(id)
    |> Repo.preload([:user, :likes, comments: :user])
  end


  # --- POST CRUD ---

  @doc """
  Creates a post.
  Handles Cloudinary upload for the :media_files list before inserting.
  """
  def create_post(user, attrs) do
    # 1. Process uploads
    attrs = handle_media_files(attrs)

    user
    |> Ecto.build_assoc(:posts)
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, post} ->
        post = Repo.preload(post, :user)
        Notifications.notify_followers_of_new_post(post)
        Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:new_post, post})
        Phoenix.PubSub.broadcast(Zchat.PubSub, "admin:stats", {:post_created, post})
        {:ok, post}
      error -> error
    end
  end

  @doc """
  Updates a post.
  Handles Cloudinary upload for :media_files if new ones are provided.
  """
  def update_post(%Post{} = post, attrs) do
    # 1. Process uploads
    attrs = handle_media_files(attrs)

    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  def delete_post(%Post{} = post) do
    Repo.delete(post)
    |> case do
      {:ok, post} ->
        Phoenix.PubSub.broadcast(Zchat.PubSub, "posts", {:post_deleted, post})
        Phoenix.PubSub.broadcast(Zchat.PubSub, "admin:stats", {:post_deleted, post})
        {:ok, post}
      error -> error
    end
  end

  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end


  # --- COMMENTS ---

  def get_comment!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes])
    Comment |> Repo.get!(id) |> Repo.preload(preload)
  end

  def list_comments(opts \\ []) do
    post_id = Keyword.get(opts, :post_id)
    parent_id = Keyword.get(opts, :parent_id)
    preload = Keyword.get(opts, :preload, [:user, :likes])

    query = from(c in Comment)
    query = if post_id, do: from(c in query, where: c.post_id == ^post_id), else: query
    query = if parent_id, do: from(c in query, where: c.parent_id == ^parent_id), else: query

    query
    |> preload(^preload)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, :user)
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

  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
    |> handle_comment_update()
  end

  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  defp handle_comment_update({:ok, comment}) do
    Phoenix.PubSub.broadcast(Zchat.PubSub, "post_comments:#{comment.post_id}", {:comment_updated, comment})
    {:ok, comment}
  end
  defp handle_comment_update({:error, changeset}), do: {:error, changeset}

  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end


  # --- LIKES ---

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

  def get_like_by_user_and_target(user_id, target_type, target_id) do
    Repo.get_by(Like, user_id: user_id, likeable_type: target_type, likeable_id: target_id)
  end

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

  def count_posts_by_category do
    from(p in Post,
      where: not is_nil(p.category),
      group_by: p.category,
      select: {p.category, count(p.id)},
      order_by: [desc: count(p.id)]
    )
    |> Repo.all()
  end

  def count_top_tags(limit \\ 10) do
    from(p in Post,
      select: {fragment("unnest(?)", p.tags), count(p.id)},
      group_by: fragment("unnest(?)", p.tags),
      order_by: [desc: count(p.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_system_stats do
    %{
      total_posts: Repo.aggregate(Post, :count),
      total_comments: Repo.aggregate(Comment, :count),
      total_users: Repo.aggregate(Zchat.Accounts.User, :count)
    }
  end


  # --- PRIVATE HELPERS ---

  defp update_like_count(%Like{likeable_type: "Post", likeable_id: post_id}) do
    count = Repo.aggregate(from(l in Like, where: l.likeable_id == ^post_id and l.likeable_type == "Post"), :count)
    from(p in Post, where: p.id == ^post_id) |> Repo.update_all(set: [likes_count: count])
    :ok
  end

  defp update_like_count(%Like{likeable_type: "Comment", likeable_id: comment_id}) do
    count = Repo.aggregate(from(l in Like, where: l.likeable_id == ^comment_id and l.likeable_type == "Comment"), :count)
    from(c in Comment, where: c.id == ^comment_id) |> Repo.update_all(set: [likes_count: count])
    :ok
  end

  defp update_like_count(_), do: :ok

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

  # =================================================================
  # CLOUDINARY MEDIA HELPER
  # =================================================================

  defp handle_media_files(attrs) do
    # 1. Grab the media_files input (could be atom or string key)
    # The LiveView upload typically sends a list of upload structs.
    raw_files = attrs["media_files"] || attrs[:media_files]

    case raw_files do
      # 1. List of files (from LiveView multi-upload)
      files when is_list(files) and files != [] ->
        processed_media =
          Enum.map(files, fn
            # A: It's a Plug.Upload struct (Standard)
            %Plug.Upload{path: path} ->
              upload_and_format(path)

            # B: It's a path string (LiveView temp file)
            path when is_binary(path) ->
              if File.exists?(path), do: upload_and_format(path), else: nil

            # C: Already processed map (e.g. edit form keeping old images)
            %{"url" => _url, "type" => _type} = item -> item

            # D: Catch-all for garbage
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1) # Remove failed uploads

        # Replace original list with processed list of maps
        Map.put(attrs, "media_files", processed_media)

      # 2. No files, or empty list -> return attrs untouched
      _ -> attrs
    end
  end

  defp upload_and_format(path) do
    case Zchat.Infrastructure.UploadCloudinary.upload_file(path) do
      {:ok, result} ->
        %{
          "url" => result.secure_url,
          "type" => result.resource_type || "image"
        }
      {:error, reason} ->
        # Log the error so we can see it in Fly logs if it fails again
        IO.inspect(reason, label: "CLOUDINARY UPLOAD ERROR")
        nil
    end
  end
end
