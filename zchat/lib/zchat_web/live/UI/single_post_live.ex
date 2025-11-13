defmodule ZchatWeb.UI.SinglePostLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    post = Posts.get_post!(id)
    {:noreply, assign(socket, :post, post)}
  end



end
