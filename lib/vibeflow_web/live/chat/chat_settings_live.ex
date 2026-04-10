defmodule VibeflowWeb.Chat.ChatSettingsLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Store
  alias Vibeflow.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:active_message_skin, current_user.active_message_skin || "default")
     |> assign(:notifications_enabled, true)
     |> assign(:sound_enabled, true)
     |> assign(:online_status_enabled, true)}
  end

  @impl true
  def handle_event("select_message_skin", %{"skin" => skin_name}, socket) do
    user_id = socket.assigns.current_user.id

    case Store.get_user_item(user_id, skin_name) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't own this skin. Purchase it from the Wave Store first!")
         |> push_patch(to: ~p"/wave-store")}

      _item ->
        case Store.activate_cosmetic(user_id, "message_skin", skin_name) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(:current_user, updated_user)
             |> assign(:active_message_skin, skin_name)
             |> put_flash(:info, "Message skin activated successfully!")}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to activate skin: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    new_state = !socket.assigns.notifications_enabled
    {:noreply, assign(socket, :notifications_enabled, new_state)}
  end

  @impl true
  def handle_event("toggle_sound", _params, socket) do
    new_state = !socket.assigns.sound_enabled
    {:noreply, assign(socket, :sound_enabled, new_state)}
  end

  @impl true
  def handle_event("toggle_online_status", _params, socket) do
    new_state = !socket.assigns.online_status_enabled
    {:noreply, assign(socket, :online_status_enabled, new_state)}
  end
end
