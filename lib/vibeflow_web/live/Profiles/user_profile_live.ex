defmodule VibeflowWeb.Profiles.UserProfileLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts
  alias Vibeflow.Posts
  alias Vibeflow.Socials
  alias Vibeflow.Chat

  @impl true
  def mount(%{"username" => username}, session, socket) do
    socket = VibeflowWeb.UserAuth.mount_current_user(socket, session)

    if connected?(socket) && socket.assigns.current_user do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "notifications:#{socket.assigns.current_user.id}")
    end

    # Preload roles and social accounts
    case Accounts.get_user_by_username(username)
         |> Vibeflow.Repo.preload([:roles, :social_accounts]) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> redirect(to: ~p"/feed")}

      user ->
        posts = Posts.list_posts(user_id: user.id, limit: 20)
        saved_posts =
          if socket.assigns.current_user && socket.assigns.current_user.id == user.id do
            Posts.list_saved_posts(user.id, limit: 20)
          else
            []
          end

        follow_stats = Socials.get_follow_stats(user.id)

        {is_following, _is_followed_by, follow_state} =
          follow_relationship(socket.assigns.current_user, user)

        # Check for pending verification request if it's the current user's profile
        pending_verification =
          if socket.assigns.current_user && socket.assigns.current_user.id == user.id do
            Accounts.check_verification_status(user)
          else
            nil
          end

        {:ok,
         socket
         |> assign(:page_title, "#{user.username}'s Profile")
         |> assign(:user, user)
         |> assign(:posts, posts)
         |> assign(:saved_posts, saved_posts)
         |> assign(:follow_stats, follow_stats)
         |> assign(:is_following, is_following)
         |> assign(:follow_state, follow_state)
         |> assign(:hide_bottom_nav, true)
         |> assign(:show_followers_modal, false)
         |> assign(:show_following_modal, false)
         |> assign(:show_verification_modal, false)
         |> assign(:pending_verification, pending_verification)
         |> assign(:social_form, to_form(%{"platform" => "youtube", "username" => ""}))
         |> assign(:followers, [])
         |> assign(:following, [])
         |> assign(:search_query, "")
         |> assign(:modal_type, nil)
         |> assign(:active_tab, "posts")}
    end
  end

  @impl true
  def handle_event("open_verification_modal", _, socket) do
    {:noreply, assign(socket, show_verification_modal: true)}
  end

  @impl true
  def handle_event("close_verification_modal", _, socket) do
    {:noreply, assign(socket, show_verification_modal: false)}
  end

  @impl true
  def handle_event("validate_social", %{"platform" => platform, "username" => username}, socket) do
    {:noreply, assign(socket, social_form: to_form(%{"platform" => platform, "username" => username}))}
  end

  @impl true
  def handle_event("add_social", %{"platform" => platform, "username" => username}, socket) do
    case Socials.create_social_account(socket.assigns.current_user, %{
           "platform" => platform,
           "username" => username
         }) do
      {:ok, _social} ->
        # Refresh user with new social accounts
        user = Accounts.get_user!(socket.assigns.user.id) |> Vibeflow.Repo.preload([:roles, :social_accounts])

        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:social_form, to_form(%{"platform" => platform, "username" => ""}))
         |> put_flash(:info, "Social account added successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, social_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("remove_social", %{"id" => id}, socket) do
    case Socials.delete_social_account(id) do
      {:ok, _} ->
        user = Accounts.get_user!(socket.assigns.user.id) |> Vibeflow.Repo.preload([:roles, :social_accounts])
        {:noreply, assign(socket, :user, user) |> put_flash(:info, "Social account removed")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not remove social account")}
    end
  end

  @impl true
  def handle_event("submit_verification", _, socket) do
    user = socket.assigns.user

    if Enum.empty?(user.social_accounts) do
      {:noreply, put_flash(socket, :error, "Please add at least one social account first")}
    else
      case Accounts.get_verified(user) do
        {:ok, _msg} ->
          pending = Accounts.check_verification_status(user)

          {:noreply,
           socket
           |> assign(:pending_verification, pending)
           |> assign(:show_verification_modal, false)
           |> put_flash(:info, "Verification request submitted! Our team will contact you soon.")}

        {:error, :pending} ->
          {:noreply,
           socket
           |> assign(:show_verification_modal, false)
           |> put_flash(:info, "Your verification request is already pending.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not submit verification request")}
      end
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
          {is_following, _is_followed_by, follow_state} =
            follow_relationship(current_user, profile_user)

          send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
          send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")

          {:noreply,
           assign(socket, is_following: is_following, follow_state: follow_state, follow_stats: follow_stats)}

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
          {is_following, _is_followed_by, follow_state} =
            follow_relationship(current_user, profile_user)

          send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
          send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")

          {:noreply,
           assign(socket, is_following: is_following, follow_state: follow_state, follow_stats: follow_stats)}

        {:error, :not_found} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp follow_relationship(nil, _profile_user), do: {false, false, "follow"}

  defp follow_relationship(current_user, profile_user) do
    is_following = Socials.following?(current_user.id, profile_user.id)
    is_followed_by = Socials.following?(profile_user.id, current_user.id)

    follow_state =
      cond do
        current_user.id == profile_user.id -> "self"
        is_followed_by && !is_following -> "follow_back"
        is_following -> "following"
        true -> "follow"
      end

    {is_following, is_followed_by, follow_state}
  end

  defp linkify_bio(nil), do: nil

  defp linkify_bio(text) when is_binary(text) do
    regex = ~r/(https?:\/\/[^\s<]+|www\.[^\s<]+)/i

    regex
    |> Regex.split(text, include_captures: true, trim: true)
    |> Enum.map(fn part ->
      if Regex.match?(regex, part) do
        url = if String.starts_with?(part, "http"), do: part, else: "https://" <> part

        Phoenix.HTML.Tag.content_tag(
          :a,
          part,
          href: url,
          target: "_blank",
          rel: "noopener noreferrer",
          class: "text-indigo-600 hover:text-indigo-700 underline underline-offset-2"
        )
      else
        Phoenix.HTML.html_escape(part)
      end
    end)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> Phoenix.HTML.raw()
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
  def handle_info({:new_notification, notif}, socket) do
    if socket.assigns.current_user && notif.user_id == socket.assigns.current_user.id and
         notif.type in ["verification_approved", "verification_rejected"] do
      user = Accounts.get_user!(socket.assigns.user.id) |> Vibeflow.Repo.preload([:roles, :social_accounts])
      pending = Accounts.check_verification_status(user)

      {:noreply, assign(socket, user: user, pending_verification: pending)}
    else
      {:noreply, socket}
    end
  end


end
