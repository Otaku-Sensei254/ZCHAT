defmodule ZchatWeb.Profiles.UserProfileLive do
  use ZchatWeb, :live_view

  alias Zchat.Accounts
  alias Zchat.Posts
  alias Zchat.Socials

  @impl true
  def mount(%{"username" => username}, session, socket) do
    socket = ZchatWeb.UserAuth.mount_current_user(socket, session)

    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> redirect(to: ~p"/feed")}

      user ->
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
         |> assign(:current_user, socket.assigns.current_user)}
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

          {:noreply,
           socket
           |> assign(:is_following, true)
           |> assign(:follow_stats, follow_stats)}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Unable to follow user")}
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

          {:noreply,
           socket
           |> assign(:is_following, false)
           |> assign(:follow_stats, follow_stats)}

        {:error, :not_found} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end
end
