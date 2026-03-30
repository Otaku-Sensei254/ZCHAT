defmodule VibeflowWeb.HomeLive do
  use VibeflowWeb, :live_view

  def mount(socket) do
    {:ok, socket |> assign(:hide_bottom_nav, true)}
  end

  @impl true
  def handle_event("toggle_theme", _params, socket) do
    # This is handled client-side, so we just return the socket
    {:noreply, socket}
  end
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}
end
