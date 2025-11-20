defmodule ZchatWeb.HomeLive do
  use ZchatWeb, :live_view

  def mount(socket) do
    {:ok, socket}
  end

  def handle_event("toggle_theme", _params, socket) do
    # This is handled client-side, so we just return the socket
    {:noreply, socket}
  end
end
