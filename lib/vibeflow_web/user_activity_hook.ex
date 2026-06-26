defmodule VibeflowWeb.UserActivityHook do
  require Logger
  import Phoenix.LiveView
  import Phoenix.Component
  alias VibeflowWeb.Presence
  alias Vibeflow.Chat
  alias Vibeflow.Notifications
  alias Vibeflow.Repo
  alias Vibeflow.Accounts
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
              # We don't need to subscribe here; Presence.track is enough
              # to make the user appear in the Presence list.
              # Only subscribe if the hook itself needs to handle presence_diff.
              :ok

            other ->
              # Log non-fatal unexpected results; do not crash the LiveView
              Logger.warning("Presence.track returned: #{inspect(other)} for user=#{user.id}")
          end
        rescue
          e ->
            Logger.error("Failed to track presence for user=#{user.id}: #{inspect(e)}")
        end
      end

      # 4. Subscribe to Calls
      if !socket.assigns[:calls_subscribed] do
        Phoenix.PubSub.subscribe(Vibeflow.PubSub, "user_calls:#{user.id}")
      end

      unread_chats_count = Chat.count_unread_conversations(user.id)

      socket =
        socket
        |> assign(:presenced_tracked, true)
        |> assign(:sidebar_subscribed, true)
        |> assign(:notifications_subscribed, true)
        |> assign_new(:calls_subscribed, fn -> true end)
        |> assign(:unread_chats_count, unread_chats_count)
        |> assign_new(:active_call, fn -> nil end)
        # Attach the universal handlers
        |> attach_hook(:global_popups, :handle_info, &handle_global_info/2)
        |> attach_hook(:global_call_events, :handle_event, &handle_global_event/3)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  # --- GLOBAL EVENT HANDLER (FOR UI CLICKS) ---
  def handle_global_event("accept_call", _params, socket) do
    case socket.assigns[:active_call] do
      %{conversation_uuid: uuid} = call ->
        VibeflowWeb.Endpoint.broadcast("conversation:#{uuid}", "call_accepted", %{
          from_user_id: socket.assigns.current_user.id
        })
        
        new_call = call
                   |> Map.put(:status, :ongoing)
                   |> Map.put(:start_time, System.system_time(:second))

        {:halt, 
          socket 
          |> assign(:active_call, new_call)
          |> push_event("init_peer_connection", %{is_initiator: false})}

      _ ->
        {:cont, socket}
    end
  end

  def handle_global_event("decline_call", _params, socket) do
    case socket.assigns[:active_call] do
      %{conversation_uuid: uuid} ->
        VibeflowWeb.Endpoint.broadcast("conversation:#{uuid}", "call_ended", %{})
        {:halt, assign(socket, :active_call, nil)}
      _ ->
        {:cont, socket}
    end
  end

  def handle_global_event("signal", payload, socket) do
    case socket.assigns[:active_call] do
      %{conversation_uuid: uuid} ->
        VibeflowWeb.Endpoint.broadcast_from(self(), "conversation:#{uuid}", "webrtc_signal", %{
          from_user_id: socket.assigns.current_user.id,
          signal: payload
        })
        {:halt, socket}
      _ ->
        {:cont, socket}
    end
  end

  def handle_global_event("call_error", %{"reason" => reason}, socket) do
    {:halt, 
     socket 
     |> put_flash(:error, "Call error: #{reason}")
     |> assign(:active_call, nil)
     |> push_event("call_ended", %{})}
  end

  def handle_global_event(_event, _params, socket), do: {:cont, socket}

  # --- GLOBAL INFO HANDLER ---
  def handle_global_info({:new_sidebar_message, message}, socket) do
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
          cond do
            Map.get(message, :is_bottle) ->
              "A message in a bottle washed up on your shore."

            Map.get(message, :shared_post_id) ->
              "#{username} shared a post with you 🚀"

            true ->
              "Message from #{username}: #{truncate(Map.get(message, :content) || "")}"
          end

        # If the user is currently viewing the conversation, just update the
        # unread count silently (the Chat LiveView will handle inserting the
        # message). Otherwise, show the popup.
        if socket.assigns[:conversation] &&
             socket.assigns.conversation.uuid == message.conversation_uuid do
          socket = assign(socket, :unread_chats_count, new_count)

          socket =
            if Map.get(message, :is_bottle) do
              push_event(socket, "bottle_arrived", %{url: chat_url_for_message(message)})
            else
              socket
            end

          {:cont, socket}
        else
          browser_notification =
            if Map.get(message, :is_bottle) do
              %{
                title: "Message in a Bottle",
                body: "A kind anonymous note found its way to you.",
                url: chat_url_for_message(message),
                tag: "bottle-#{Map.get(message, :id)}"
              }
            else
              %{
                title: "New message from #{username}",
                body: truncate(Map.get(message, :content) || "Tap to open chat"),
                url: chat_url_for_message(message),
                tag: "chat-#{Map.get(message, :id)}",
                icon: message_user && message_user.avatar_url
              }
            end

          socket =
            socket
            |> assign(:unread_chats_count, new_count)
            |> push_event("new_notification", %{notification: browser_notification})

          socket =
            if Map.get(message, :is_bottle) do
              push_event(socket, "bottle_arrived", %{url: chat_url_for_message(message)})
            else
              socket
            end

          {:cont, put_flash(socket, :info, popup_text)}
        end
      else
        {:cont, socket}
      end
    rescue
      e ->
        Logger.error(
          "UserActivityHook handle_global_info new_sidebar_message error: #{inspect(e)}"
        )

        {:cont, socket}
    end
  end

  # --- HANDLER 2: NEW NOTIFICATION (Likes, Follows, etc) ---
  def handle_global_info({:new_notification, notif}, socket) do
    try do
      # Format the text like "Batman liked your post" (defensive)
      text = format_notification_text(notif)

      browser_notification =
        build_browser_notification(notif, text, socket.assigns[:current_user])

      # We use :cont so the specific page (Feed/Chat) can also update its UI if needed
      {:cont,
       socket
       |> push_event("new_notification", %{notification: browser_notification})
       |> put_flash(:info, text)}
    rescue
      e ->
        Logger.error("UserActivityHook handle_global_info new_notification error: #{inspect(e)}")
        {:cont, socket}
    end
  end

  # --- HANDLER 3: Sidebar Read Update (Just clear badge, no popup) ---
  def handle_global_info(:update_sidebar, socket) do
    try do
      new_count = Chat.count_unread_conversations(socket.assigns.current_user.id)
      {:cont, assign(socket, :unread_chats_count, new_count)}
    rescue
      e ->
        Logger.error("UserActivityHook handle_global_info update_sidebar error: #{inspect(e)}")
        {:cont, socket}
    end
  end

  # --- HANDLER 4: POINTS AWARDED ---
  def handle_global_info({:points_awarded, %{amount: amount}}, socket) do
    # Update the user points in the current socket if needed
    user = socket.assigns.current_user
    new_points = (user.points || 0) + amount
    updated_user = %{user | points: new_points}

    {:cont,
     socket
     |> assign(:current_user, updated_user)
     |> put_flash(:info, "You earned +#{amount} points! ✨")}
  end

  # --- HANDLER 5: CALL EVENTS ---
  def handle_global_info(%Phoenix.Socket.Broadcast{event: "incoming_call", payload: payload}, socket) do
    if payload.from_user_id != socket.assigns.current_user.id do
      # Subscribe to the conversation topic for signaling
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "conversation:#{payload.conversation_uuid}")
      
      from_user = Vibeflow.Accounts.get_user!(payload.from_user_id)
      active_call = %{
        status: :ringing,
        display_user: from_user,
        conversation_uuid: payload.conversation_uuid,
        start_time: nil
      }
      {:halt, assign(socket, :active_call, active_call)}
    else
      {:halt, socket}
    end
  end

  def handle_global_info(%Phoenix.Socket.Broadcast{event: "call_accepted", payload: _payload}, socket) do
    case socket.assigns[:active_call] do
      %{status: :calling} = call ->
        new_call = call
                   |> Map.put(:status, :ongoing)
                   |> Map.put(:start_time, System.system_time(:second))
        {:halt, 
         socket 
         |> assign(:active_call, new_call)
         |> push_event("init_peer_connection", %{is_initiator: true})}
      _ -> {:cont, socket}
    end
  end

  def handle_global_info(%Phoenix.Socket.Broadcast{event: "call_ended", payload: _payload}, socket) do
    {:halt, 
     socket 
     |> assign(:active_call, nil)
     |> push_event("call_ended", %{})}
  end

  def handle_global_info(%Phoenix.Socket.Broadcast{event: "webrtc_signal", payload: payload}, socket) do
    {:halt, push_event(socket, "webrtc_signal", payload)}
  end

  def handle_global_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    online_users = VibeflowWeb.Presence.list("users:online")
    
    # Auto-hangup if other user leaves during a call
    socket = if socket.assigns[:active_call] do
      other_user_id = to_string(socket.assigns.active_call.display_user.id)
      if !Map.has_key?(online_users, other_user_id) do
        # Trigger local cleanup
        Process.send(self(), %Phoenix.Socket.Broadcast{event: "call_ended", payload: %{}}, [])
        put_flash(socket, :info, "Call ended: User disconnected.")
      else
        socket
      end
    else
      socket
    end

    {:cont, assign(socket, :online_users, online_users)}
  end

  # Catch-all
  def handle_global_info(_event, socket), do: {:cont, socket}

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
      "post_ready" -> "Your post is live! 🎉"
      _ -> "You have a new notification 🔔"
    end
  end

  defp build_browser_notification(notif, text, current_user) do
    actor = Map.get(notif || %{}, :actor) || %{}

    url =
      try do
        VibeflowWeb.Components.NotificationsModal.notification_link(notif, current_user)
      rescue
        _ -> "/notifications"
      end

    %{
      title: "Vibeflow",
      body: text,
      url: url,
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
