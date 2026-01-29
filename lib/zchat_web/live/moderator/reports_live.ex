defmodule ZchatWeb.Moderator.ReportsLive do
  use ZchatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")}
  end
end
