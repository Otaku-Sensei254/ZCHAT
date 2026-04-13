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

    # Check if user is admin of this group
    user_member = Enum.find(conversation.conversation_members, fn m -> m.user_id == current_user.id end)
    is_admin = user_member && (user_member.role == "admin" || user_member.role == nil)

    # For member search
    {:ok,
     socket
     |> assign(:conversation, conversation)
     |> assign(:active_message_skin, conversation_skin)
     |> assign(:global_skin, current_user.active_message_skin || "default")
     |> assign(:notifications_enabled, true)
     |> assign(:sound_enabled, true)
     |> assign(:online_status_enabled, true)
     |> assign(:is_admin, is_admin)
     |> assign(:member_search_query, "")
     |> assign(:member_search_results, [])
     |> assign(:show_add_member_modal, false)}
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

    # Default skin (empty string) doesn't require ownership check
    if skin_name == "" or skin_name == nil do
      # Handle default skin selection
      if socket.assigns[:conversation] do
        # Set default skin for this specific conversation
        conversation = socket.assigns.conversation
        case update_conversation_skin(conversation, user_id, "") do
          {:ok, _} ->
            # Broadcast the skin change to the conversation
            VibeflowWeb.Endpoint.broadcast_from(
              self(),
              "conversation:#{conversation.uuid}",
              "skin_changed",
              %{
                user_id: user_id,
                skin: "",
                username: socket.assigns.current_user.username
              }
            )

            {:noreply,
             socket
             |> assign(:active_message_skin, "")
             |> put_flash(:info, "Switched to default skin")}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to switch skin")}
        end
      else
        # Set global default skin
        case Accounts.update_user_global_skin(user_id, "") do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:active_message_skin, "")
             |> assign(:global_skin, "")
             |> put_flash(:info, "Switched to default skin")}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to switch skin")}
        end
      end
    else
      # Check ownership for premium skins
      case Store.get_user_item(user_id, skin_name) do
        nil ->
          {:noreply,
           socket
           |> put_flash(:error, "You don't own this skin. Purchase it from the Wave Store first!")}

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

  @impl true
  def handle_event("update_group_bio", %{"bio" => bio}, socket) do
    conversation = socket.assigns.conversation

    case Chat.update_conversation(conversation, %{bio: bio}) do
      {:ok, updated_conversation} ->
        {:noreply,
         socket
         |> assign(:conversation, updated_conversation)
         |> put_flash(:info, "Group bio updated successfully")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update group bio")}
    end
  end

  @impl true
  def handle_event("search_members", %{"query" => query}, socket) do
    current_user = socket.assigns.current_user
    conversation = socket.assigns.conversation

    search_results = if String.length(query) >= 2 do
      Accounts.search_users(query, current_user.id)
      |> Enum.reject(fn user ->
        # Exclude users already in the conversation
        Enum.any?(conversation.conversation_members, fn member -> member.user_id == user.id end)
      end)
    else
      []
    end

    {:noreply,
     socket
     |> assign(:member_search_query, query)
     |> assign(:member_search_results, search_results)}
  end

  @impl true
  def handle_event("toggle_add_member_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_member_modal, not socket.assigns.show_add_member_modal)}
  end

  @impl true
  def handle_event("add_member", %{"user_id" => user_id}, socket) do
    conversation = socket.assigns.conversation
    target_user_id = String.to_integer(user_id)

    case Chat.add_user_to_conversation(conversation.id, target_user_id) do
      {:ok, _updated_conversation} ->
        # Refresh conversation data
        updated_conversation = Chat.get_conversation!(conversation.uuid)

        {:noreply,
         socket
         |> assign(:conversation, updated_conversation)
         |> assign(:show_add_member_modal, false)
         |> assign(:member_search_query, "")
         |> assign(:member_search_results, [])
         |> put_flash(:info, "Member added successfully")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to add member: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"user_id" => user_id}, socket) do
    conversation = socket.assigns.conversation
    target_user_id = String.to_integer(user_id)

    # Don't allow removing the admin (creator)
    if target_user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> put_flash(:error, "Cannot remove yourself from the group")}
    else
      case Chat.remove_user_from_conversation(conversation.id, target_user_id) do
        {:ok, _updated_conversation} ->
          # Refresh conversation data
          updated_conversation = Chat.get_conversation!(conversation.uuid)

          {:noreply,
           socket
           |> assign(:conversation, updated_conversation)
           |> put_flash(:info, "Member removed successfully")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to remove member: #{inspect(reason)}")}
      end
    end
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
