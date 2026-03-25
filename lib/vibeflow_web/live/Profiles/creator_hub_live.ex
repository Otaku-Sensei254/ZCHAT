defmodule VibeflowWeb.Profiles.CreatorHubLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts
  alias Vibeflow.Posts
  alias VibeflowWeb.UserAuth

  def layout(_assigns), do: {VibeflowWeb.Layouts, :app}

  @impl true
  def mount(_params, session, socket) do
    socket = UserAuth.mount_current_user(socket, session)
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"username" => username}, _uri, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/")}

      user ->
        if socket.assigns.current_user && socket.assigns.current_user.id == user.id do
          posts = Posts.list_creator_hub_posts(user.id)

          totals = %{
            views: Enum.reduce(posts, 0, fn p, acc -> acc + (p.post.view_count || 0) end),
            likes: Enum.reduce(posts, 0, fn p, acc -> acc + (p.likes_count || 0) end),
            comments: Enum.reduce(posts, 0, fn p, acc -> acc + (p.comments_count || 0) end),
            reach: Enum.reduce(posts, 0, fn p, acc -> acc + (p.seed_count || 0) end),
            rippled: Enum.reduce(posts, 0, fn p, acc -> acc + (p.rippled_count || 0) end)
          }

          {:noreply,
           socket
           |> assign(:user, user)
           |> assign(:posts, posts)
           |> assign(:totals, totals)}
        else
          {:noreply, push_navigate(socket, to: ~p"/users/#{username}")}
        end
    end
  end
end
