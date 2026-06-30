defmodule VibeflowWeb.PostShowLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Posts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Posts.get_post!(id)
    {:ok, assign(socket, :post, post)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>{@post.title}</.header>
    <p><%= @post.content %></p>what
    """
  end
end
