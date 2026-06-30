defmodule VibeflowWeb.Sales.DashboardLive do
  use VibeflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sales Dashboard")}
  end
end
