defmodule VibeflowWeb.UserActivityHook do
  require Logger
  import Phoenix.LiveView
  import Phoenix.Component
  alias VibeflowWeb.Presence
  alias Vibeflow.Chat
  alias Vibeflow.Notifications
  alias Vibeflow.Repo
  alias Vibeflow.Accounts.User

  def on_mount(:default, _params, _session, socket) do
    if socket.assigns[:current_user] do
      user = socket.assigns.current_user

      # 1. Subscribe to Chat Sidebar (For Messages)
      if !socket.assigns[:sidebar_subscribed] do
        Phoenix.PubSub.subscribe(Vibeflow.PubSub, "user_sidebar:#{user.id}")
      end

      # 2. Subscribe to Notifications (For Shares/Likes)
      if !socket.assigns[:notifications_subscribed] do
        Phoenix.PubSub.subscribe(Vibeflow.PubSub, "notifications:#{user.id}")
      end

      # 3. Track Presence
      if !socket.assigns[:presenced_tracked] do
        topic = "users:online"
        try do
          case Presence.track(self(), topic, user.id, %{
                 online_at: inspect(System.system_time(:second)),
                 username: user.username,
                 avatar: user.avatar_url
               }) do
            {:ok, _meta} ->
              VibeflowWeb.Endpoint.subscribe(topic)
            other ->
              # Log non-fatal unexpected results; do not crash the LiveView
              Logger.warning("Presence.track returned: #{inspect(other)} for user=#{user.id}")
          end
        rescue
          e ->
            Logger.error("Failed to track presence for user=#{user.id}: #{inspect(e)}")
        end
      end

      unread_chats_count = Chat.count_unread_conversations(user.id)

      socket =
        socket
        |> assign(:presenced_tracked, true)
        |> assign(:sidebar_subscribed, true)
        |> assign(:notifications_subscribed, true)
        |> assign(:unread_chats_count, unread_chats_count)
        # Attach the universal handler
        |> attach_hook(:global_popups, :handle_info, &handle_global_event/2)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  # --- HANDLER 1: NEW CHAT MESSAGE ---
  defp handle_global_event({:new_sidebar_message, message}, socket) do
    try do
      current_user_id = socket.assigns.current_user.id

      # Don't show popup if I sent the message myself
      if message.user_id != current_user_id do

        # 1. Update the Header Badge Count
        new_count = Chat.count_unread_conversations(current_user_id)

        # 2. Determine Text (Is it text or a shared post?)
        # Ensure we have a username available even if message.user wasn't preloaded
        message_user =
          case message.user do
            %User{} = u -> u
            _ -> Repo.get(User, message.user_id)
          end

        username = (message_user && message_user.username) || "Someone"

        popup_text =
          if Map.get(message, :shared_post_id) do
            "#{username} shared a post with you 🚀"
          else
            "Message from #{username}: #{truncate(Map.get(message, :content) || "") }"
          end

        # If the user is currently viewing the conversation, just update the
        # unread count silently (the Chat LiveView will handle inserting the
        # message). Otherwise, show the popup.
        if socket.assigns[:conversation] && socket.assigns.conversation.uuid == message.conversation_uuid do
          {:cont, assign(socket, :unread_chats_count, new_count)}
        else
          browser_notification = %{
            title: "New message from #{username}",
            body: truncate(Map.get(message, :content) || "Tap to open chat"),
            url: chat_url_for_message(message),
            tag: "chat-#{Map.get(message, :id)}",
            icon: message_user && message_user.avatar_url
          }

          {:cont,
           socket
           |> assign(:unread_chats_count, new_count)
           |> push_event("new_notification", %{notification: browser_notification})
           |> put_flash(:info, popup_text)}
        end
      else
        {:cont, socket}
      end
    rescue
      e ->
        Logger.error("UserActivityHook handle_global_event new_sidebar_message error: #{inspect(e)}")
        {:cont, socket}
    end
  end

  # --- HANDLER 2: NEW NOTIFICATION (Likes, Follows, etc) ---
  defp handle_global_event({:new_notification, notif}, socket) do
    try do
      # Format the text like "Batman liked your post" (defensive)
      text = format_notification_text(notif)
      browser_notification = build_browser_notification(notif, text)

      # We use :cont so the specific page (Feed/Chat) can also update its UI if needed
      {:cont,
       socket
       |> push_event("new_notification", %{notification: browser_notification})
       |> put_flash(:info, text)}
    rescue
      e ->
        Logger.error("UserActivityHook handle_global_event new_notification error: #{inspect(e)}")
        {:cont, socket}
    end
  end

  # --- HANDLER 3: Sidebar Read Update (Just clear badge, no popup) ---
  defp handle_global_event(:update_sidebar, socket) do
    try do
      new_count = Chat.count_unread_conversations(socket.assigns.current_user.id)
      {:cont, assign(socket, :unread_chats_count, new_count)}
    rescue
      e ->
        Logger.error("UserActivityHook handle_global_event update_sidebar error: #{inspect(e)}")
        {:cont, socket}
    end
  end

  # Catch-all
  defp handle_global_event(_event, socket), do: {:cont, socket}

  # --- HELPERS ---

  defp truncate(text) do
    if String.length(text) > 30, do: String.slice(text, 0, 30) <> "...", else: text
  end

  defp format_notification_text(n) do
    # FIX: Use Map.get instead of get_in.
    # get_in fails on Structs because they don't implement the Access behaviour.

    actor_obj = Map.get(n || %{}, :actor)
    actor = (actor_obj && Map.get(actor_obj, :username)) || "Someone"

    case Map.get(n || %{}, :type, "notification") do
      "like" -> "#{actor} liked your post ❤️"
      "comment" -> "#{actor} commented on your post 💬"
      "follow" -> "#{actor} started following you 👤"
      "shared_post" -> "#{actor} shared a post with you 🚀"
      _ -> "You have a new notification 🔔"
    end
  end

  defp build_browser_notification(notif, text) do
    actor = Map.get(notif || %{}, :actor) || %{}

    %{
      title: "Vibeflow",
      body: text,
      url: "/notifications",
      tag: "notif-#{Map.get(notif || %{}, :id, System.unique_integer([:positive]))}",
      icon: Map.get(actor, :avatar_url)
    }
  end

  defp chat_url_for_message(message) do
    case Map.get(message, :conversation_uuid) do
      uuid when is_binary(uuid) and uuid != "" -> "/chat/#{uuid}"
      _ -> "/chat"
    end
  end
end
