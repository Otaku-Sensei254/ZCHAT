defmodule VibeflowWeb.Chat.ChatSettingsLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Store
  alias Vibeflow.Accounts
  alias Vibeflow.Chat

  @impl true
  def mount(%{"uuid" => conversation_uuid}, _session, socket) do
    current_user = socket.assigns.current_user
    conversation = Chat.get_conversation!(conversation_uuid)

    # Get the user's skin for this specific conversation
    conversation_skin = get_user_skin_for_conversation(conversation, current_user.id)

    {:ok,
     socket
     |> assign(:conversation, conversation)
     |> assign(:active_message_skin, conversation_skin)
     |> assign(:global_skin, current_user.active_message_skin || "default")
     |> assign(:notifications_enabled, true)
     |> assign(:sound_enabled, true)
     |> assign(:online_status_enabled, true)}
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:active_message_skin, current_user.active_message_skin || "default")
     |> assign(:global_skin, current_user.active_message_skin || "default")
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
        # Check if this is for a specific conversation or global setting
        if socket.assigns[:conversation] do
          # Set skin for this specific conversation
          conversation = socket.assigns.conversation
          case update_conversation_skin(conversation, user_id, skin_name) do
            {:ok, _} ->
              # Broadcast the skin change to the conversation
              VibeflowWeb.Endpoint.broadcast_from(
                self(),
                "conversation:#{conversation.uuid}",
                "skin_changed",
                %{
                  user_id: user_id,
                  skin: skin_name,
                  username: socket.assigns.current_user.username
                }
              )

              {:noreply,
               socket
               |> assign(:active_message_skin, skin_name)
               |> put_flash(:info, "Message skin updated for this conversation!")}

            {:error, reason} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to update skin: #{inspect(reason)}")}
          end
        else
          # Set global skin
          case Store.activate_cosmetic(user_id, "message_skin", skin_name) do
            {:ok, updated_user} ->
              {:noreply,
               socket
               |> assign(:current_user, updated_user)
               |> assign(:active_message_skin, skin_name)
               |> assign(:global_skin, skin_name)
               |> put_flash(:info, "Global message skin activated successfully!")}

            {:error, reason} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to activate skin: #{inspect(reason)}")}
          end
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

  # Helper functions
  defp get_user_skin_for_conversation(conversation, user_id) do
    case Enum.find(conversation.conversation_members, fn m -> m.user_id == user_id end) do
      nil -> "default"
      member -> member.message_skin || "default"
    end
  end

  defp update_conversation_skin(conversation, user_id, skin_name) do
    # Find the conversation member for this user
    case Enum.find(conversation.conversation_members, fn m -> m.user_id == user_id end) do
      nil ->
        {:error, "User not in conversation"}

      member ->
        # Update the conversation member's skin preference
        member
        |> Ecto.Changeset.change(%{message_skin: skin_name})
        |> Vibeflow.Repo.update()
    end
  end
end
