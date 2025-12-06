defmodule ZchatWeb.UserActivityHook do
  import Phoenix.LiveView
  import Phoenix.Component
  alias ZchatWeb.Presence
  alias Zchat.Chat

  def on_mount(:default, _params, _session, socket) do
    if socket.assigns[:current_user] do
      user = socket.assigns.current_user
      topic = "users:online"
      unread_chats_count = Chat.count_unread_conversations(user.id)


  if !socket.assigns[:sidebar_subscribed] do
    Phoenix.PubSub.subscribe(Zchat.PubSub, "user_sidebar:#{user.id}")

  end
      # Only track if not already tracking (to prevent duplicate noise)
      if !socket.assigns[:presenced_tracked] do
        {:ok, _} = Presence.track(self(), topic, user.id, %{
          online_at: inspect(System.system_time(:second)),
          username: user.username,
          avatar: user.avatar_url
        })
      end

      # Subscribe so this socket knows about others
      ZchatWeb.Endpoint.subscribe(topic)

      socket =
        socket
        |> assign(:presenced_tracked, true)
        |> assign(:sidebar_subscribed, true)
        |> assign(:unread_chats_count, unread_chats_count)
        |> attach_hook(:global_sidebar_update, :handle_info, &handle_sidebar_event/2)

      {:cont, socket }
    else
      {:cont, socket}
    end
  end
  defp handle_sidebar_event(:update_sidebar, socket) do
    user_id = socket.assigns.current_user.id
    new_count = Chat.count_unread_conversations(user_id)

    {:cont, assign(socket, :unread_chats_count, new_count)}
  end

  # Ignore other messages
  defp handle_sidebar_event(_event, socket), do: {:cont, socket}

end
