defmodule Vibeflow.Posts do
  @moduledoc """
  The Posts context for handling blog posts, comments, and likes.
  """
  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Accounts
  alias Vibeflow.Notifications
  alias Vibeflow.Posts.{Post, Like, Comment, PostSeed, View}
  alias Vibeflow.Posts.Seeder
  require Logger

  @post_creation_points 20
  @daily_post_bonus_limit 3
  @like_points 2
  @post_author_like_points 3
  @ripple_points 5
  @post_author_ripple_points 3

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

  def list_feed_for_user(user_id, opts \\ [])

  def list_feed_for_user(nil, _opts), do: []

  def list_feed_for_user(user_id, opts) do
    page = opts[:page] || 1
    per_page = opts[:per_page] || opts[:limit] || 10
    search_term = opts[:search]
    category = opts[:category]

    base_query =
      from(p in Post,
        left_join: ps in PostSeed,
        on: ps.post_id == p.id and ps.user_id == ^user_id,
        join: u in assoc(p, :user),
        left_join: l in assoc(p, :likes),
        left_join: c in assoc(p, :comments),
        where: ps.user_id == ^user_id or p.user_id == ^user_id,
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
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))

    query
    |> Repo.all()
    |> Repo.preload([:user, :likes, comments: :user])
  end

  def list_seeded_users_for_post(post_id, limit \\ 50) do
    from(ps in PostSeed,
      where: ps.post_id == ^post_id,
      join: u in assoc(ps, :user),
      order_by: [desc: ps.inserted_at],
      limit: ^limit,
      select: u
    )
    |> Repo.all()
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

  def get_post!(id_or_uuid, opts \\ []) do
    cond do
      is_integer(id_or_uuid) ->
        get_post_by_id!(id_or_uuid, opts)

      is_binary(id_or_uuid) ->
        case Ecto.UUID.cast(id_or_uuid) do
          {:ok, uuid} -> get_post_by_uuid!(uuid, opts)
          :error -> get_post_by_id!(String.to_integer(id_or_uuid), opts)
        end

      true ->
        raise ArgumentError, "invalid post id"
    end
  end

  def get_post_by_id!(id, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes, comments: :user])

    Post
    |> Repo.get!(id)
    |> Repo.preload(preload)
    |> Post.ensure_media_files()
  end

  def get_post_by_uuid!(uuid, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes, comments: :user])

    Post
    |> Repo.get_by!(uuid: uuid)
    |> Repo.preload(preload)
    |> Post.ensure_media_files()
  end

  def get_post_by_uuid(uuid, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes, comments: :user])

    Post
    |> Repo.get_by(uuid: uuid)
    |> Repo.preload(preload)
    |> Post.ensure_media_files()
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


  def get_post(id_or_uuid, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:user, :likes, comments: :user])

    cond do
      is_integer(id_or_uuid) ->
        Post
        |> Repo.get(id_or_uuid)
        |> Repo.preload(preload)
        |> Post.ensure_media_files()

      is_binary(id_or_uuid) ->
        case Ecto.UUID.cast(id_or_uuid) do
          {:ok, uuid} ->
            Post
            |> Repo.get_by(uuid: uuid)
            |> Repo.preload(preload)
            |> Post.ensure_media_files()

          :error ->
            Post
            |> Repo.get(String.to_integer(id_or_uuid))
            |> Repo.preload(preload)
            |> Post.ensure_media_files()
        end

      true ->
        nil
    end
  rescue
    _ -> nil
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
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "posts", {:new_post, post})
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "admin:stats", {:post_created, post})
        case Seeder.assign_initial_seeds(post.id, post.user_id) do
          {:ok, _} -> :ok
          {:error, reason} -> Logger.error("Post seeding failed: #{inspect(reason)}")
        end
        _ = maybe_award_daily_post_points(post.user_id)
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
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "posts", {:post_deleted, post})
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "admin:stats", {:post_deleted, post})
        {:ok, post}
      error -> error
    end
  end

  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  defp maybe_award_daily_post_points(user_id) do
    if daily_posts_created_today(user_id) <= @daily_post_bonus_limit do
      Accounts.grant_points(user_id, @post_creation_points)
    else
      {:ok, :limit_reached}
    end
  end

  defp daily_posts_created_today(user_id) do
    from(p in Post,
      where: p.user_id == ^user_id and p.inserted_at >= ^today_start()
    )
    |> Repo.aggregate(:count, :id)
  end

  defp today_start do
    Date.utc_today()
    |> NaiveDateTime.new!(~T[00:00:00])
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
    |> order_by([c], [desc: c.pinned, asc: c.inserted_at])
    |> Repo.all()
  end

  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, :user)
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post:#{comment.post_id}", {:new_comment, comment})
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "admin:stats", {:comment_created, comment})

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
    attrs =
      attrs
      |> Map.put_new("user_id", comment.user_id)
      |> Map.put_new("post_id", comment.post_id)
      |> Map.put_new("parent_id", comment.parent_id)

    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
    |> handle_comment_update()
  end

  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  defp handle_comment_update({:ok, comment}) do
    comment = Repo.preload(comment, :user)
    Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post_comments:#{comment.post_id}", {:comment_updated, comment})
    {:ok, comment}
  end
  defp handle_comment_update({:error, changeset}), do: {:error, changeset}

  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end
  def pin_comment(%Comment{} = comment) do
    comment
    |> Comment.changeset(%{pinned: true})
    |> Repo.update()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, :user)
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post_comments:#{comment.post_id}", {:comment_pinned, comment})
        {:ok, comment}
      error -> error
    end
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
            Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post:#{like.likeable_id}", {:post_liked, like})
            Phoenix.PubSub.broadcast(Vibeflow.PubSub, "posts", {:post_liked, like})
          like.likeable_type == "Comment" ->
            comment = Repo.get(Comment, like.likeable_id)
            if comment do
              Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post:#{comment.post_id}", {:comment_liked, like})
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
            Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post:#{like.likeable_id}", {:post_unliked, %{post_id: like.likeable_id, user_id: like.user_id}})
            Phoenix.PubSub.broadcast(Vibeflow.PubSub, "posts", {:post_unliked, %{post_id: like.likeable_id, user_id: like.user_id}})
          like.likeable_type == "Comment" ->
            comment = Repo.get(Comment, like.likeable_id)
            if comment do
              Phoenix.PubSub.broadcast(Vibeflow.PubSub, "post:#{comment.post_id}", {:comment_unliked, %{comment_id: like.likeable_id, user_id: like.user_id}})
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
        case likeable_type do
          "Post" -> like_post(user_id, likeable_id)
          _ ->
            create_like(%{
              user_id: user_id,
              likeable_type: likeable_type,
              likeable_id: likeable_id
            })
        end
      like ->
        delete_like(like)
    end
  end

  def like_post(user_id, post_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:post, fn repo, _ ->
      case repo.get(Post, post_id) do
        nil -> {:error, :post_not_found}
        post -> {:ok, post}
      end
    end)
    |> Ecto.Multi.run(:like, fn _repo, _ ->
      create_like(%{
        user_id: user_id,
        likeable_type: "Post",
        likeable_id: post_id
      })
    end)
    |> Ecto.Multi.run(:ripple, fn repo, %{post: post} ->
      case repo.get_by(PostSeed, post_id: post_id, user_id: user_id) do
        nil ->
          {:ok, :no_seed}

        %PostSeed{rippled: true} ->
          {:ok, :already_rippled}

        %PostSeed{} ->
          {updated, _} =
            repo.update_all(
              from(ps in PostSeed,
                where:
                  ps.post_id == ^post_id and
                    ps.user_id == ^user_id and
                    ps.rippled == false
              ),
              set: [rippled: true]
            )

          if updated > 0 do
            _ = Seeder.expand_seeds(post_id, post.user_id, user_id, 5)
            {:ok, :rippled}
          else
            {:ok, :already_rippled}
          end
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{post: post, like: like, ripple: ripple_status}} ->
        award_like_points(post, user_id, ripple_status)
        {:ok, like}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end


  defp award_like_points(%Post{} = post, user_id, ripple_status) do
    Accounts.grant_points(user_id, @like_points)
    maybe_award_author_points(post.user_id, user_id, @post_author_like_points)

    if ripple_status == :rippled do
      Accounts.grant_points(user_id, @ripple_points)
      maybe_award_author_points(post.user_id, user_id, @post_author_ripple_points)
    end
  end

  defp award_like_points(_, _, _), do: :ok

  defp maybe_award_author_points(nil, _user_id, _points), do: {:ok, :no_author}
  defp maybe_award_author_points(author_id, user_id, _points) when author_id == user_id, do: {:ok, :self_action}
  defp maybe_award_author_points(author_id, _user_id, points) do
    Accounts.grant_points(author_id, points)
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
      total_users: Repo.aggregate(Vibeflow.Accounts.User, :count)
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
    cond do
      is_nil(user_id) ->
        :ok

      true ->
        case Repo.get(Post, post_id) do
          nil ->
            :ok

          post ->
            if post.user_id != user_id do
              # Check if view already exists first
              view_exists = Repo.get_by(View, post_id: post_id, user_id: user_id)

              if view_exists do
                :ok  # Already viewed, don't increment
              else
                # Try to insert the view record
                case %View{}
                     |> View.changeset(%{post_id: post_id, user_id: user_id})
                     |> Repo.insert(on_conflict: :nothing, conflict_target: [:post_id, :user_id]) do
                  {:ok, _} ->
                    # Only increment if this was a new view
                    from(p in Post, where: p.id == ^post_id)
                    |> Repo.update_all(inc: [view_count: 1])

                  {:error, _} ->
                    :ok
                end
              end
            else
              :ok
            end
        end
    end
  end

  def list_creator_hub_posts(user_id) do
    posts =
      from(p in Post,
        where: p.user_id == ^user_id,
        left_join: ps in PostSeed,
        on: ps.post_id == p.id,
        left_join: l in Like,
        on: l.likeable_type == "Post" and l.likeable_id == p.id,
        left_join: c in Comment,
        on: c.post_id == p.id,
        group_by: p.id,
        order_by: [desc: p.inserted_at],
        select: %{
          post: p,
          seed_count: count(ps.user_id, :distinct),
          rippled_count: count(ps.user_id, :distinct) |> filter(ps.rippled == true),
          likes_count: count(l.id, :distinct),
          comments_count: count(c.id, :distinct)
        }
      )
      |> Repo.all()

    Enum.map(posts, fn row ->
      ripplers = list_ripplers_for_post(row.post.id, 6)
      frontier = max(row.seed_count - row.rippled_count, 0)

      %{
        post: row.post,
        seed_count: row.seed_count,
        rippled_count: row.rippled_count,
        frontier_count: frontier,
        likes_count: row.likes_count,
        comments_count: row.comments_count,
        ripplers: ripplers
      }
    end)
  end

  def list_ripplers_for_post(post_id, limit \\ 5) do
    from(ps in PostSeed,
      where: ps.post_id == ^post_id and ps.rippled == true,
      join: u in assoc(ps, :user),
      order_by: [desc: ps.updated_at],
      limit: ^limit,
      select: u
    )
    |> Repo.all()
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
    case Vibeflow.Infrastructure.UploadCloudinary.upload_file(path) do
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
