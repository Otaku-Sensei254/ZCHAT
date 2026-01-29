defmodule VibeflowWeb.Moderator.ReportsLive do
  use VibeflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")}
  end
end
