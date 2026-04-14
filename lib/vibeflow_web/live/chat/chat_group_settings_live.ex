defmodule VibeflowWeb.Chat.ChatGroupSettingsLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Chat
  alias Vibeflow.Chat.ConversationMember
  alias Vibeflow.Accounts
  alias Vibeflow.Store

  def mount(%{"uuid" => conversation_uuid}, _session, socket) do
    conversation = Chat.get_conversation_by_uuid!(conversation_uuid)

    if connected?(socket) do
      Chat.subscribe_to_conversation(conversation)
    end

    members = Chat.list_conversation_members(conversation.id)
    current_user = socket.assigns.current_user

    # Check if current user is admin
    current_member = Enum.find(members, fn m -> m.user_id == current_user.id end)
    is_admin = current_member && current_member.role == "admin"

    # Get shared content
    messages = Chat.list_messages(conversation.id)
    media_content = extract_media_content(messages)
    docs_content = extract_docs_content(messages)
    links_content = extract_links_content(messages)

    # Get available message skins
    available_skins = get_available_message_skins()

    {:ok,
     socket
     |> assign(:conversation, conversation)
     |> assign(:members, members)
     |> assign(:is_admin, is_admin)
     |> assign(:current_user, current_user)
     |> assign(:active_tab, :info)
     |> assign(:show_add_member_modal, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:media_content, media_content)
     |> assign(:docs_content, docs_content)
     |> assign(:links_content, links_content)
     |> assign(:available_skins, available_skins)
     |> assign(:selected_skin, current_user.active_message_skin || "default")
     |> assign(:media_tab, :media_files)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  def handle_event("switch_media_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :media_tab, String.to_atom(tab))}
  end

  def handle_event("select_skin", %{"skin" => skin_name}, socket) do
    user_id = socket.assigns.current_user.id
    conversation = socket.assigns.conversation

    # For group chats, update conversation member's skin, not global user skin
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
         |> assign(:selected_skin, skin_name)
         |> put_flash(:info, "Message skin updated for this conversation!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update skin: #{inspect(reason)}")}
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

  def handle_event("update_group_info", %{"conversation" => params}, socket) do
    %{conversation: conversation, is_admin: is_admin} = socket.assigns

    if is_admin do
      case Chat.update_conversation(conversation, params) do
        {:ok, updated_conversation} ->
          {:noreply,
           socket
           |> assign(:conversation, updated_conversation)
           |> put_flash(:info, "Group information updated successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update group information")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can update group information")}
    end
  end

  def handle_event("search_users", %{"query" => query}, socket) do
    %{conversation: conversation} = socket.assigns

    if String.length(query) >= 2 do
      # Get all users, then filter out existing members
      all_users = Accounts.search_users(query)
      existing_member_ids = Enum.map(conversation.conversation_members, & &1.user_id)
      search_results = Enum.reject(all_users, fn user -> user.id in existing_member_ids end)

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, search_results)}
    else
      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, [])}
    end
  end

  def handle_event("toggle_add_member_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_member_modal, !socket.assigns.show_add_member_modal)
     |> assign(:search_query, "")
     |> assign(:search_results, [])}
  end

  def handle_event("add_member", %{"user_id" => user_id}, socket) do
    %{conversation: conversation, is_admin: is_admin, current_user: current_user} = socket.assigns

    if is_admin do
      case Chat.add_user_to_conversation(conversation.id, user_id) do
        {:ok, _member} ->
          # Refresh members list
          updated_members = Chat.list_conversation_members(conversation.id)
          updated_conversation = Chat.get_conversation_by_uuid!(conversation.uuid)

          {:noreply,
           socket
           |> assign(:conversation, updated_conversation)
           |> assign(:members, updated_members)
           |> assign(:search_results, [])
           |> put_flash(:info, "Member added successfully")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to add member")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can add members")}
    end
  end

  def handle_event("remove_member", %{"member_id" => member_id}, socket) do
    %{conversation: conversation, is_admin: is_admin, current_user: current_user} = socket.assigns

    member = Enum.find(socket.assigns.members, fn m -> m.id == member_id end)

    # Can't remove yourself unless you're the last admin
    can_remove = is_admin && (member.user_id != current_user.id || can_remove_self?(conversation, current_user.id))

    if can_remove do
      case Chat.remove_user_from_conversation(conversation.id, member.user_id) do
        {:ok, _} ->
          # Refresh members list
          updated_members = Chat.list_conversation_members(conversation.id)
          updated_conversation = Chat.get_conversation_by_uuid!(conversation.uuid)

          {:noreply,
           socket
           |> assign(:conversation, updated_conversation)
           |> assign(:members, updated_members)
           |> put_flash(:info, "Member removed successfully")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to remove member")}
      end
    else
      {:noreply, put_flash(socket, :error, "Cannot remove this member")}
    end
  end

  def handle_event("leave_group", _params, socket) do
    %{conversation: conversation, current_user: current_user} = socket.assigns

    case Chat.remove_user_from_conversation(conversation.id, current_user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You left the group")
         |> push_navigate(to: ~p"/chat")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end

  def handle_event("select_skin", %{"skin" => skin}, socket) do
    %{current_user: current_user} = socket.assigns

    case Accounts.update_user_message_skin(current_user.id, skin) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> assign(:selected_skin, skin)
         |> put_flash(:info, "Message skin updated successfully")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update message skin")}
    end
  end

  def handle_event("select_skin_by_index", %{"index" => index}, socket) do
    skin_index = String.to_integer(index)
    available_skins = socket.assigns.available_skins

    if skin_index >= 0 and skin_index < length(available_skins) do
      selected_skin = Enum.at(available_skins, skin_index)["id"]
      handle_event("select_skin", %{"skin" => selected_skin}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("previous_skin", _params, socket) do
    current_index = get_skin_index(socket.assigns.selected_skin, socket.assigns.available_skins)
    previous_index = if current_index > 0, do: current_index - 1, else: length(socket.assigns.available_skins) - 1
    previous_skin = Enum.at(socket.assigns.available_skins, previous_index)["id"]
    handle_event("select_skin", %{"skin" => previous_skin}, socket)
  end

  def handle_event("next_skin", _params, socket) do
    current_index = get_skin_index(socket.assigns.selected_skin, socket.assigns.available_skins)
    next_index = if current_index < length(socket.assigns.available_skins) - 1, do: current_index + 1, else: 0
    next_skin = Enum.at(socket.assigns.available_skins, next_index)["id"]
    handle_event("select_skin", %{"skin" => next_skin}, socket)
  end

  # Handle conversation updates
  def handle_info({:conversation_updated, conversation}, socket) do
    {:noreply, assign(socket, :conversation, conversation)}
  end

  def handle_info({:member_added, member}, socket) do
    current_members = socket.assigns.members
    updated_members = [member | current_members]
    {:noreply, assign(socket, :members, updated_members)}
  end

  def handle_info({:member_removed, member_id}, socket) do
    updated_members = Enum.reject(socket.assigns.members, fn m -> m.id == member_id end)
    {:noreply, assign(socket, :members, updated_members)}
  end

  def handle_info({:message_read, _payload}, socket) do
    # Handle message read updates - no action needed for group settings
    {:noreply, socket}
  end

  def handle_info(:update_sidebar, socket) do
    # Handle sidebar update - no action needed for group settings
    {:noreply, socket}
  end

  # Private helper functions
  defp can_remove_self?(conversation, user_id) do
    admin_members = Enum.filter(conversation.conversation_members, fn m ->
      m.role == "admin" and m.user_id != user_id
    end)
    length(admin_members) > 0
  end

  defp extract_media_content(messages) do
    messages
    |> Enum.filter(fn msg ->
      msg.media_files && is_list(msg.media_files) && length(msg.media_files) > 0
    end)
    |> Enum.map(fn msg ->
      # Get the first media file for display
      media_file = List.first(msg.media_files)
      %{
        id: msg.id,
        type: determine_media_type(media_file),
        url: get_media_url(media_file),
        message: msg.content,
        user: msg.user,
        inserted_at: msg.inserted_at
      }
    end)
  end

  defp extract_docs_content(messages) do
    messages
    |> Enum.filter(fn msg ->
      msg.media_files && is_list(msg.media_files) &&
        Enum.any?(msg.media_files, fn media_file ->
          filename = get_media_filename(media_file)
          is_document_file?(filename)
        end)
    end)
    |> Enum.map(fn msg ->
      doc_files = Enum.filter(msg.media_files, fn media_file ->
        filename = get_media_filename(media_file)
        is_document_file?(filename)
      end)

      doc_file = List.first(doc_files)
      %{
        id: msg.id,
        filename: get_media_filename(doc_file),
        url: get_media_url(doc_file),
        message: msg.content,
        user: msg.user,
        inserted_at: msg.inserted_at
      }
    end)
  end

  defp extract_links_content(messages) do
    messages
    |> Enum.filter(fn msg ->
      msg.content && (String.contains?(msg.content, "http://") || String.contains?(msg.content, "https://"))
    end)
    |> Enum.map(fn msg ->
      links = extract_links_from_text(msg.content)
      %{
        id: msg.id,
        links: links,
        message: msg.content,
        user: msg.user,
        inserted_at: msg.inserted_at
      }
    end)
  end

  defp extract_filename(url) when is_binary(url) do
    url
    |> String.split("/")
    |> List.last()
    |> URI.decode()
  end
  defp extract_filename(_), do: "Unknown"

  defp extract_links_from_text(text) do
    Regex.scan(~r/https?:\/\/[^\s]+/, text)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp get_available_message_skins do
    # This should return available message skins from your store/config
    [
      %{"id" => "default", "name" => "Default", "preview" => "/images/skins/default.png"},
      %{"id" => "glassmorphism_pro", "name" => "Glassmorphism Pro", "preview" => "/images/skins/glassmorphism.png"},
      %{"id" => "holographic_foil", "name" => "Holographic Foil", "preview" => "/images/skins/holographic.png"},
      %{"id" => "matrix_rain", "name" => "Matrix Rain", "preview" => "/images/skins/matrix.png"},
      %{"id" => "vantablack", "name" => "Vantablack", "preview" => "/images/skins/vantablack.png"}
    ]
  end

  # Carousel helper functions
  defp get_tab_index(tab) do
    case tab do
      :info -> 0
      :members -> 1
      :media -> 2
      :docs -> 3
      :links -> 4
      :skins -> 5
      _ -> 0
    end
  end

  defp get_tab_by_index(index) do
    case index do
      0 -> :info
      1 -> :members
      2 -> :media
      3 -> :docs
      4 -> :links
      5 -> :skins
      _ -> :info
    end
  end

  defp get_carousel_offset(tab) do
    index = get_tab_index(tab)
    "#{-index * 100}%"
  end

  defp get_skin_index(selected_skin, available_skins) do
    Enum.find_index(available_skins, fn skin -> skin["id"] == selected_skin end) || 0
  end

  defp get_skin_carousel_offset(selected_skin, available_skins) do
    index = get_skin_index(selected_skin, available_skins)
    "#{-index * 100}%"
  end

  # Media file helper functions
  defp determine_media_type(media_file) when is_map(media_file) do
    filename = get_media_filename(media_file)
    cond do
      is_nil(filename) -> "unknown"
      is_image_file?(filename) -> "image"
      is_video_file?(filename) -> "video"
      is_audio_file?(filename) -> "audio"
      true -> "unknown"
    end
  end

  defp determine_media_type(_), do: "unknown"

  defp get_media_url(media_file) when is_map(media_file) do
    Map.get(media_file, "url") || Map.get(media_file, :url) || ""
  end

  defp get_media_filename(media_file) when is_map(media_file) do
    case media_file do
      %{"filename" => filename} -> filename
      %{:filename => filename} -> filename
      _ -> "unknown"
    end
  end

  defp is_image_file?(filename) do
    filename && String.contains?(filename, ".") &&
      (String.contains?(filename, ".jpg") ||
       String.contains?(filename, ".jpeg") ||
       String.contains?(filename, ".png") ||
       String.contains?(filename, ".gif") ||
       String.contains?(filename, ".webp") ||
       String.contains?(filename, ".svg") ||
       String.contains?(filename, ".bmp"))
  end

  defp is_video_file?(filename) do
    filename && String.contains?(filename, ".") &&
      (String.contains?(filename, ".mp4") ||
       String.contains?(filename, ".webm") ||
       String.contains?(filename, ".mov") ||
       String.contains?(filename, ".avi") ||
       String.contains?(filename, ".mkv") ||
       String.contains?(filename, ".flv") ||
       String.contains?(filename, ".wmv"))
  end

  defp is_audio_file?(filename) do
    filename && String.contains?(filename, ".") &&
      (String.contains?(filename, ".mp3") ||
       String.contains?(filename, ".wav") ||
       String.contains?(filename, ".ogg") ||
       String.contains?(filename, ".m4a") ||
       String.contains?(filename, ".flac") ||
       String.contains?(filename, ".aac") ||
       String.contains?(filename, ".wma"))
  end

  defp is_document_file?(filename) do
    filename && String.contains?(filename, ".") &&
      (String.contains?(filename, ".pdf") ||
       String.contains?(filename, ".doc") ||
       String.contains?(filename, ".docx") ||
       String.contains?(filename, ".xls") ||
       String.contains?(filename, ".xlsx") ||
       String.contains?(filename, ".ppt") ||
       String.contains?(filename, ".pptx") ||
       String.contains?(filename, ".txt") ||
       String.contains?(filename, ".zip") ||
       String.contains?(filename, ".rar"))
  end
end
