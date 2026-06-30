defmodule VibeflowWeb.Moderator.VerificationsLive do
  use VibeflowWeb, :live_view

  @impl true
  def render(assigns), do: VibeflowWeb.Admin.VerificationsLive.render(assigns)

  @impl true
  def mount(params, session, socket),
    do: VibeflowWeb.Admin.VerificationsLive.mount(params, session, socket)

  @impl true
  def handle_event(event, params, socket),
    do: VibeflowWeb.Admin.VerificationsLive.handle_event(event, params, socket)
end
