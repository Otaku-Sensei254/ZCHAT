defmodule ZchatWeb.Moderator.DashboardLive do
  use ZchatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Moderator Dashboard")}
  end
end
