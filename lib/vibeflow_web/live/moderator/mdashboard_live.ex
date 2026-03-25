defmodule VibeflowWeb.Moderator.DashboardLive do
  use VibeflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Moderator Dashboard")}
  end
end
