defmodule VibeflowWeb.UI.SinglePostLive do
  use VibeflowWeb, :live_view

  # Only import the functions you need from Ecto.Query to avoid conflicts
  import Ecto.Query, only: [from: 2]

  alias Vibeflow.Posts
  alias Vibeflow.Posts.Comment
  alias Vibeflow.Accounts
  alias Vibeflow.Socials
  alias VibeflowWeb.UserAuth

  # Use the app layout
  def layout(_assigns), do: {VibeflowWeb.Layouts, :app}

  @impl true
  def mount(_params, session, socket) do
    socket = UserAuth.mount_current_user(socket, session)

    {:ok,
     socket
     |> assign(:replying_to, nil)
     |> assign(:open_comment_menu_id, nil)
     |> assign(:editing_comment_id, nil)
     |> assign(:comment_form, to_form(Posts.change_comment(%Comment{})))
     |> assign(:current_like, nil)
     |> assign(:like_count, 0)
     |> assign(:wide_layout, true)
    #  |> assign(:hide_bottom_nav, true)
     |> assign(:show_comments_modal, false)
     |> assign(:current_media_index, 0)
     |> assign(:show_mention_modal, false)
     |> assign(:mention_search_results, [])
     |> assign(:mention_search_query, "")
    #  FIX: Initialize BOTH streams here
     |> stream(:comments, [])

     |> stream(:mobile_comments, [])}
  end

  @impl true
  def handle_params(%{"uuid" => uuid}, _uri, socket) do
    post = Posts.get_post!(uuid, preload: [:user, :likes, comments: :user])

    # Ensure your Posts.list_comments returns newest first (inserted_at: :desc)
    # so it matches the prepend behavior of stream_insert
    comments = Posts.list_comments(post_id: post.id, preload: [:user])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "post:#{post.id}")
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "post_comments:#{post.id}")
      if socket.assigns.current_user && socket.assigns.current_user.id != post.user_id do
        Posts.track_view(post.id, socket.assigns.current_user.id)
      end
    end

    current_like =
      if socket.assigns.current_user do
        Posts.get_like_by_user_and_target(socket.assigns.current_user.id, "Post", post.id)
      else
        nil
      end

    current_repost =
      if socket.assigns.current_user do
        Posts.get_repost_by_user_and_post(socket.assigns.current_user.id, post.id)
      else
        nil
      end

    current_save =
      if socket.assigns.current_user do
        Posts.get_saved_post_by_user_and_post(socket.assigns.current_user.id, post.id)
      else
        nil
      end

    seeded_users =
      if socket.assigns.current_user &&
           (Accounts.user_has_role?(socket.assigns.current_user, "admin") ||
              Accounts.user_has_role?(socket.assigns.current_user, "moderator")) do
        Posts.list_seeded_users_for_post(post.id, 50)
      else
        []
      end

    is_following =
      if socket.assigns.current_user do
        Socials.following?(socket.assigns.current_user.id, post.user.id)
      else
        false
      end

    {:noreply,
     socket
     |> assign(:post, post)
     |> assign(:seeded_users, seeded_users)
     |> assign(:current_media_index, 0)
     |> assign(:like_count, post.likes_count || 0)
     |> assign(:repost_count, post.reposts_count || 0)
     |> assign(:current_like, current_like)
     |> assign(:current_repost, current_repost)
     |> assign(:current_save, current_save)
     |> assign(:comment_count, length(comments))
     |> assign(:is_following, is_following)

     # 1. Desktop Stream: Uses standard IDs (e.g., "comments-1")
     |> stream(:comments, comments, reset: true)

     # 2. Mobile Stream: Uses custom IDs (e.g., "mobile-comment-1") to prevent DOM conflicts
     |> stream(:mobile_comments, comments, reset: true, dom_id: fn c -> "mobile-comment-#{c.id}" end)}
  end

  # --- MEDIA CAROUSEL ---

  @impl true
  def handle_event("next_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    new_index = rem(socket.assigns.current_media_index + 1, total_media)
    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("prev_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    current = socket.assigns.current_media_index
    new_index = if current == 0, do: total_media - 1, else: current - 1
    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("go_to_media", %{"index" => index}, socket) do
    {:noreply, assign(socket, :current_media_index, String.to_integer(index))}
  end

  # --- INTERACTIONS ---

  @impl true
  def handle_event("validate", %{"comment" => params}, socket) do
    changeset =
      %Comment{}
      |> Posts.change_comment(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :comment_form, to_form(changeset))}
  end

  @impl true
  def handle_event("add_comment", %{"comment" => comment_params}, socket) do
    if socket.assigns.current_user do
      attrs = Map.merge(comment_params, %{
          "user_id" => socket.assigns.current_user.id,
          "post_id" => socket.assigns.post.id,
          "parent_id" => socket.assigns.replying_to
        })

      case Posts.create_comment(attrs) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:comment_form, to_form(Posts.change_comment(%Comment{})))
           |> assign(:replying_to, nil)
           |> put_flash(:info, "Comment posted!")}
        {:error, changeset} ->
          {:noreply, assign(socket, :comment_form, to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "Login required")}
    end
  end

  @impl true
  def handle_event("toggle_like", _, socket) do
    if socket.assigns.current_user do
      Posts.toggle_like(socket.assigns.current_user.id, "Post", socket.assigns.post.id)
      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("toggle_save", _, socket) do
    if socket.assigns.current_user do
      Posts.toggle_save_post(socket.assigns.current_user.id, socket.assigns.post.id)
      {:noreply, assign(socket, :current_save, !socket.assigns.current_save)}
    else
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    end
  end

 @impl true
 def handle_event("share_post", _, socket) do
   post_url = VibeflowWeb.Endpoint.url() <> "/posts/#{socket.assigns.post.uuid}"
   {:noreply,
     socket
     |> push_event("share_post", %{
         title: "Check out this post by #{socket.assigns.post.user.username}",
         text: socket.assigns.post.content,
         url: post_url
       })}
 end

  @impl true
  def handle_event("toggle_follow", %{"user-id" => user_id}, socket) do
    if socket.assigns.current_user do
      # Prevent following yourself
      if String.to_integer(user_id) == socket.assigns.current_user.id do
        {:noreply, put_flash(socket, :error, "You cannot follow yourself")}
      else
        if socket.assigns.is_following do
          case Socials.delete_follow(socket.assigns.current_user.id, String.to_integer(user_id)) do
            {:ok, _} -> {:noreply, assign(socket, :is_following, false)}
            _ -> {:noreply, put_flash(socket, :error, "Unable to unfollow")}
          end
        else
          case Socials.create_follow(%{
                 follower_id: socket.assigns.current_user.id,
                 following_id: String.to_integer(user_id)
               }) do
            {:ok, _} -> {:noreply, assign(socket, :is_following, true)}
            _ -> {:noreply, put_flash(socket, :error, "Unable to follow")}
          end
        end
      end
    else
      {:noreply, put_flash(socket, :error, "Login required to follow users")}
    end
  end

  @impl true
  def handle_event("repost_post", _, socket) do
    if socket.assigns.current_user do
      case Posts.toggle_repost(socket.assigns.current_user.id, socket.assigns.post.id) do
        {:ok, {:reposted, _repost}} ->
          {:noreply, put_flash(socket, :info, "You reposted this post!")}

        {:ok, {:unreposted, _post}} ->
          {:noreply, put_flash(socket, :info, "You removed your repost")}

        {:error, :post_not_found} ->
          {:noreply, put_flash(socket, :error, "Post not found")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to repost post")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Log in to repost")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("show_comments", _, socket) do
    comments = Posts.list_comments(post_id: socket.assigns.post.id, preload: [:user])

    {:noreply,
     socket
     |> assign(:show_comments_modal, true)
     |> stream(:mobile_comments, comments, reset: true, dom_id: fn c -> "mobile-comment-#{c.id}" end)}
  end

  @impl true
  def handle_event("close_comments_modal", _, socket), do: {:noreply, assign(socket, :show_comments_modal, false)}

  @impl true
  def handle_event("toggle_comment_menu", %{"comment-id" => comment_id}, socket) do
    id = String.to_integer(comment_id)
    new_id = if socket.assigns.open_comment_menu_id == id, do: nil, else: id
    comment = Posts.get_comment!(comment_id, preload: [:user])

    {:noreply,
     socket
     |> assign(:open_comment_menu_id, new_id)
     |> stream_insert(:comments, comment)
     |> stream_insert(:mobile_comments, comment)}
  end

  @impl true
  def handle_event("close_comment_menu", _params, socket) do
    socket =
      if socket.assigns.open_comment_menu_id do
        comment =
          Posts.get_comment!(socket.assigns.open_comment_menu_id, preload: [:user])

        socket
        |> stream_insert(:comments, comment)
        |> stream_insert(:mobile_comments, comment)
      else
        socket
      end

    {:noreply, assign(socket, :open_comment_menu_id, nil)}
  end

  @impl true
  def handle_event("delete_comment", %{"comment-id" => comment_id}, socket) do
    comment = Posts.get_comment!(comment_id)

    if socket.assigns.current_user && (socket.assigns.current_user.id == comment.user_id || Accounts.user_has_role?(socket.assigns.current_user, "admin")) do
      case Posts.delete_comment(comment) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Comment deleted successfully")
           |> stream_delete(:comments, comment)}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete comment")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("edit_comment", %{"comment-id" => comment_id, "content" => new_content}, socket) do
    update_comment_content(comment_id, new_content, socket)
  end

  @impl true
  def handle_event("edit_comment", %{"comment-id" => comment_id, "edit_comment" => %{"content" => new_content}}, socket) do
    update_comment_content(comment_id, new_content, socket)
  end

  @impl true
  def handle_event("edit_comment", %{"comment-id" => comment_id}, socket) do
    comment = Posts.get_comment!(comment_id, preload: [:user])

    {:noreply,
     socket
     |> assign(:editing_comment_id, comment.id)
     |> stream_insert(:comments, comment)
     |> stream_insert(:mobile_comments, comment)}
  end

  @impl true
  def handle_event("cancel_edit", %{"comment-id" => comment_id}, socket) do
    comment = Posts.get_comment!(comment_id, preload: [:user])

    {:noreply,
     socket
     |> assign(:editing_comment_id, nil)
     |> stream_insert(:comments, comment)
     |> stream_insert(:mobile_comments, comment)}
  end

  @impl true
  def handle_event("pin_comment", %{"comment-id" => comment_id}, socket) do
    comment = Posts.get_comment!(comment_id, preload: [:user])
    if socket.assigns.current_user && (socket.assigns.current_user.id == socket.assigns.post.user_id || Accounts.user_has_role?(socket.assigns.current_user, "admin")) do
      case Posts.pin_comment(comment) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Comment pinned successfully")
           |> assign(:open_comment_menu_id, nil)
           |> stream_insert(:comments, comment)
           |> stream_insert(:mobile_comments, comment)}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not pin comment")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("reply_to_comment", %{"comment-id" => comment_id}, socket) do
    {:noreply, assign(socket, :replying_to, String.to_integer(comment_id))}
  end

  @impl true
  def handle_event("cancel_edit_comment", _params, socket) do
    {:noreply, assign(socket, :editing_comment_id, nil)}
  end

  @impl true
  def handle_event("show_mention_modal", _, socket) do
    {:noreply, assign(socket, show_mention_modal: true)}
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # --- MENTION MODAL EVENTS ---
  @impl true
  def handle_event("close_mention_modal", _, socket) do
    {:noreply, assign(socket, show_mention_modal: false, mention_search_results: [], mention_search_query: "")}
  end

  @impl true
  def handle_event("search_mentions", %{"query" => query}, socket) do
    if String.length(query) >= 2 do
      users = search_users_by_username(query)
      {:noreply, assign(socket, mention_search_results: users, mention_search_query: query)}
    else
      {:noreply, assign(socket, mention_search_results: [])}
    end
  end

  @impl true
  def handle_event("select_mention", %{"username" => _username}, socket) do
    # This will be handled by JavaScript to insert the username
    {:noreply, assign(socket, show_mention_modal: false)}
  end

  @impl true
  def handle_event("stop_propagation", _, socket) do
    # Prevent modal from closing when clicking inside
    {:noreply, socket}
  end

  # --- HELPER FUNCTIONS ---
  defp search_users_by_username(query) do
    query_prefix = query <> "%"
    from(u in Vibeflow.Accounts.User,
      where: ilike(u.username, ^query_prefix),
      limit: 10,
      select: [:id, :username, :avatar_url, :bio]
    )
    |> Vibeflow.Repo.all()
  end

  @impl true
  def handle_info({:repost_added, repost}, socket) do
    if socket.assigns.post.id == repost.post_id do
      {:noreply,
       socket
       |> assign(:repost_count, socket.assigns.repost_count + 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:unreposted, post_struct}, socket) do
    if socket.assigns.post.id == post_struct.id do
      {:noreply,
       socket
       |> assign(:repost_count, max(0, socket.assigns.repost_count - 1))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_liked, like}, socket) do
    if like.likeable_id == socket.assigns.post.id do
      new_count = socket.assigns.like_count + 1
      current_like =
        if socket.assigns.current_user && like.user_id == socket.assigns.current_user.id do
          like
        else
          socket.assigns.current_like
        end
      {:noreply, assign(socket, like_count: new_count, current_like: current_like)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_unliked, %{post_id: pid, user_id: uid}}, socket) do
    if pid == socket.assigns.post.id do
      current_like =
        if socket.assigns.current_user && uid == socket.assigns.current_user.id do
          nil
        else
          socket.assigns.current_like
        end
      {:noreply, assign(socket, like_count: max(0, socket.assigns.like_count - 1), current_like: current_like)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_comment, comment}, socket) do
    if comment.post_id == socket.assigns.post.id do
      socket =
        socket
        |> stream_insert(:comments, comment, at: 0)
        |> stream_insert(:mobile_comments, comment, at: 0)
        |> Phoenix.Component.update(:comment_count, &(&1 + 1))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:comment_updated, comment}, socket) do
    socket =
      socket
      |> stream_insert(:comments, comment)
      |> stream_insert(:mobile_comments, comment)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:comment_pinned, comment}, socket) do
    socket =
      socket
      |> stream_insert(:comments, comment)
      |> stream_insert(:mobile_comments, comment)

    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  # --- HELPERS ---

  defp update_comment_content(comment_id, new_content, socket) do
    comment = Posts.get_comment!(comment_id, preload: [:user])
    trimmed = String.trim(new_content || "")

    can_edit =
      socket.assigns.current_user &&
        (socket.assigns.current_user.id == comment.user_id ||
           Accounts.user_has_role?(socket.assigns.current_user, "admin") ||
           Accounts.user_has_role?(socket.assigns.current_user, "moderator"))

    if can_edit do
      if trimmed == "" do
        {:noreply, put_flash(socket, :error, "Comment cannot be blank")}
      else
        case Posts.update_comment(comment, %{"content" => trimmed}) do
        {:ok, updated_comment} ->
          {:noreply,
           socket
           |> put_flash(:info, "Comment updated successfully")
           |> assign(:editing_comment_id, nil)
           |> stream_insert(:comments, updated_comment)
           |> stream_insert(:mobile_comments, updated_comment)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update comment")}
      end
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp assign_current_repost(socket) do
    current_user = socket.assigns[:current_user]
    post = socket.assigns[:post]

    # Example logic: check if current_user has reposted this post
    has_reposted =
      if current_user && post && Map.has_key?(post, :reposts) && is_list(post.reposts) do
        Enum.any?(post.reposts, fn r -> r.user_id == current_user.id end)
      else
        false
      end

    assign(socket, :current_repost, has_reposted)
  end
end
