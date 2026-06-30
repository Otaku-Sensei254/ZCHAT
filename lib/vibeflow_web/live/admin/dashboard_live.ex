defmodule VibeflowWeb.Admin.DashboardLive do
  use VibeflowWeb, :live_view
  alias Vibeflow.Posts

  @impl true
  def mount(_params, _session, socket) do
    # 👇 1. Subscribe to the topic if connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "admin:stats")
    end

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:stats, Posts.get_system_stats())
     |> assign(:categories, Posts.count_posts_by_category())
     |> assign(:tags, Posts.count_top_tags())}
  end

  # --- Handle POST updates ---
  @impl true
  def handle_info({:post_created, _post}, socket) do
    # Increment post count by 1
    new_stats = Map.update!(socket.assigns.stats, :total_posts, &(&1 + 1))
    {:noreply, assign(socket, :stats, new_stats)}
  end

  @impl true
  def handle_info({:post_deleted, _post}, socket) do
    # Decrement post count by 1
    new_stats = Map.update!(socket.assigns.stats, :total_posts, &(&1 - 1))
    {:noreply, assign(socket, :stats, new_stats)}
  end

  # --- Handle COMMENT updates ---
  @impl true
  def handle_info({:comment_created, _comment}, socket) do
    new_stats = Map.update!(socket.assigns.stats, :total_comments, &(&1 + 1))
    {:noreply, assign(socket, :stats, new_stats)}
  end

  # --- Handle USER updates ---
  @impl true
  def handle_info({:user_created, _user}, socket) do
    new_stats = Map.update!(socket.assigns.stats, :total_users, &(&1 + 1))
    {:noreply, assign(socket, :stats, new_stats)}
  end
end
