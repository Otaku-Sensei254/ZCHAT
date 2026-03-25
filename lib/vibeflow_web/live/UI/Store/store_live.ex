defmodule VibeflowWeb.UI.Store.StoreLive do
  use VibeflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  # @impl true
  # def render(assigns) do
  #   ~H"""
  #   <div>
  #       <h1>Hello</h1>

  #   </div>
  #   """
  # end
end
