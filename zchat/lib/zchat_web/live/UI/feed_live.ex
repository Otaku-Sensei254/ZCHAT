defmodule FeedLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
