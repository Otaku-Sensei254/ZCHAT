defmodule VibeflowWeb.Profiles.UserProfileLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts
  alias Vibeflow.Posts
  alias Vibeflow.Socials
  alias Vibeflow.Chat

  @impl true
  def mount(%{"username" => username}, session, socket) do
    socket = VibeflowWeb.UserAuth.mount_current_user(socket, session)

    # Preload roles to prevent crashes in the template
    case Accounts.get_user_by_username(username)
    |> Vibeflow.Repo.preload(:roles) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> redirect(to: ~p"/feed")}

      user ->
        # This now works because we fixed the Context!
        posts = Posts.list_posts(user_id: user.id, limit: 20)
        follow_stats = Socials.get_follow_stats(user.id)

        is_following =
          if socket.assigns.current_user do
            Socials.following?(socket.assigns.current_user.id, user.id)
          else
            false
          end

  {:ok,
   socket
   |> assign(:page_title, "#{user.username}'s Profile")
   |> assign(:user, user)
   |> assign(:posts, posts)
   |> assign(:follow_stats, follow_stats)
   |> assign(:is_following, is_following)
   |> assign(:hide_bottom_nav, true)
   |> assign(:show_followers_modal, false)
   |> assign(:show_following_modal, false)
   |> assign(:followers, [])
   |> assign(:following, [])
   |> assign(:search_query, "")
   |> assign(:modal_type, nil)}
    end
  end

  @impl true
  def handle_event("follow", _, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.user

    if current_user && current_user.id != profile_user.id do
      case Socials.create_follow(%{
        follower_id: current_user.id,
        following_id: profile_user.id
      }) do
        {:ok, _follow} ->
          follow_stats = Socials.get_follow_stats(profile_user.id)
          {:noreply, assign(socket, is_following: true, follow_stats: follow_stats)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Unable to follow user")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unfollow", _, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.user

    if current_user && current_user.id != profile_user.id do
      case Socials.delete_follow(current_user.id, profile_user.id) do
        {:ok, _follow} ->
          follow_stats = Socials.get_follow_stats(profile_user.id)
          {:noreply, assign(socket, is_following: false, follow_stats: follow_stats)}

        {:error, :not_found} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  #message the user
    @impl true
  def handle_event("message_user", _, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.user

    # Safety check: Don't message yourself
    if current_user && current_user.id != profile_user.id do
      case Chat.get_or_create_private_conversation(current_user.id, profile_user.id) do
        {:ok, conversation} ->
          # Navigate to the chat!
          {:noreply, push_navigate(socket, to: ~p"/chat/#{conversation.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not start conversation")}
      end
    else
      {:noreply, socket}
    end
  end

  # Followers/Following Modal Events
  @impl true
  def handle_event("show_followers", _, socket) do
    profile_user = socket.assigns.user
    followers = Socials.list_followers(profile_user.id)

    {:noreply,
     socket
     |> assign(:show_followers_modal, true)
     |> assign(:show_following_modal, false)
     |> assign(:followers, followers)
     |> assign(:modal_type, "followers")
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("show_following", _, socket) do
    profile_user = socket.assigns.user
    following = Socials.list_following(profile_user.id)

    {:noreply,
     socket
     |> assign(:show_followers_modal, false)
     |> assign(:show_following_modal, true)
     |> assign(:following, following)
     |> assign(:modal_type, "following")
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_followers_modal, false)
     |> assign(:show_following_modal, false)
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("search_follows", %{"search" => search_query}, socket) do
    profile_user = socket.assigns.user
    modal_type = socket.assigns.modal_type

    {followers, following} =
      case modal_type do
        "followers" ->
          {Socials.list_followers(profile_user.id, search: search_query), socket.assigns.following}
        "following" ->
          {socket.assigns.followers, Socials.list_following(profile_user.id, search: search_query)}
        _ ->
          {socket.assigns.followers, socket.assigns.following}
      end

    {:noreply,
     socket
     |> assign(:followers, followers)
     |> assign(:following, following)
     |> assign(:search_query, search_query)}
  end



  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:new_notification, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:notifications_read, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end
    @impl true
  def handle_info(:update_notifications, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end
    @impl true
  def handle_info({:update_sidebar, _message}, socket) do
    {:noreply, socket}
  end
  @impl true
  def handle_info({:new_sidebar_message, _}, socket), do: {:noreply, socket}

    @impl true
    def handle_info({:new_notification,_}, socket) do
      {:noreply, socket}
    end


end
