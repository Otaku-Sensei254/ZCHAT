defmodule ZchatWeb.HomeLive do
  use ZchatWeb, :live_view

  def mount(socket) do
    {:ok, socket |> assign(:hide_bottom_nav, false)}
  end

  def handle_event("toggle_theme", _params, socket) do
    # This is handled client-side, so we just return the socket
    {:noreply, socket}
  end
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}
end
