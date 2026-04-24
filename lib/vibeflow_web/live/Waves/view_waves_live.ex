defmodule VibeflowWeb.Waves.ViewWavesLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Waves
  alias Vibeflow.Chat
  alias Vibeflow.Accounts
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       waves: [],
       wave_groups: [],
       group_index: 0,
       current_index: 0,
       timer_ref: nil,
       is_muted: false,
       is_paused: false,
       message: ""
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    username = params["username"]
    user = Vibeflow.Accounts.get_user_by_username(username)
    waves = if user, do: Waves.list_user_waves(user.id), else: []

    wave_groups =
      if socket.assigns.current_user do
        Waves.list_active_waves(socket.assigns.current_user.id)
      else
        []
      end

    group_index =
      wave_groups
      |> Enum.find_index(fn g -> g.user.username == username end)
      |> case do
        nil -> 0
        idx -> idx
      end

    if waves == [] do
      {:noreply,
       socket
       |> assign(:wave_groups, wave_groups)
       |> assign(:group_index, group_index)
       |> go_next_user_or_feed()}
    else
      socket =
        socket
        |> assign(:waves, waves)
        |> assign(:wave_groups, wave_groups)
        |> assign(:group_index, group_index)
        |> assign(:current_index, 0)
        |> assign(:timer_ref, nil)
        |> assign(:hide_bottom_nav, true)
        |> assign(:is_muted, false)
        |> assign(:is_paused, false)
        |> assign(:message, "")

      {:noreply, schedule_timer(socket)}
    end
  end

  # --- RENDER ---
  @impl true
  def render(assigns) do
    ~H"""
    <div id="wave-viewer" class="fixed inset-0 bg-black z-50 flex flex-col text-white select-none">

    <!-- Top Controls (Mute, Pause, Three Dots) -->
      <div class="absolute top-0 left-0 right-0 z-20 flex justify-between items-center p-4 pt-8">
        <div class="flex items-center gap-4">
          <button
            phx-click="toggle_mute"
            class="wave-control-btn w-10 h-10 rounded-full bg-black/50 backdrop-blur-md flex items-center justify-center hover:bg-black/70"
          >
            <%= if @is_muted do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="w-5 h-5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M17.25 9.75 19.5 12m0 0 2.25 2.25M19.5 12l2.25-2.25M19.5 12l-2.25 2.25m-10.5-6 4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z"
                />
              </svg>
            <% else %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="w-5 h-5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.114 5.636a9 9 0 0 0 0 12.728M16.463 8.288a5.25 5.25 0 0 0 0 7.424M6.75 8.25l4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.506-1.938-1.354A9.01 9.01 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z"
                />
              </svg>
            <% end %>
          </button>

          <button
            phx-click="toggle_pause"
            class="wave-control-btn w-10 h-10 rounded-full bg-black/50 backdrop-blur-md flex items-center justify-center hover:bg-black/70"
          >
            <%= if @is_paused do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="w-5 h-5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z"
                />
              </svg>
            <% else %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="w-5 h-5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 5.25v13.5m-7.5-13.5v13.5"
                />
              </svg>
            <% end %>
          </button>
        </div>

        <button
          phx-click="show_options"
          class="wave-control-btn w-10 h-10 rounded-full bg-black/50 backdrop-blur-md flex items-center justify-center hover:bg-black/70"
        >
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2zm0 2c-2.7 0-8 1.3-8 4v2h16v-2c0-2.7-5.3-4-8-4z" />
            <circle cx="12" cy="12" r="1" />
            <circle cx="12" cy="5" r="1" />
            <circle cx="12" cy="19" r="1" />
          </svg>
        </button>
      </div>

    <!-- Progress Bars -->
      <div class="absolute top-0 left-0 right-0 z-20 flex gap-1 p-2 pt-4">
        <%= for {_, index} <- Enum.with_index(@waves) do %>
          <div class="h-1 flex-1 rounded-full bg-gray-600/50 overflow-hidden">
            <div class={"h-full transition-all duration-300 " <> bar_style(index, @current_index)}>
            </div>
          </div>
        <% end %>
      </div>

      <% current_wave = Enum.at(@waves, @current_index) %>

    <!-- User Info -->
      <div class="absolute top-20 left-4 right-4 z-20 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <div class={"w-10 h-10 rounded-full border-2 border-white overflow-hidden " <> VibeflowWeb.CoreComponents.avatar_frame_class(current_wave.user)}>
            <img
              src={current_wave.user.avatar_url || "/images/default_avatar.png"}
              class="w-full h-full object-cover"
            />
          </div>
          <div class="flex flex-col">
            <span class={"font-bold text-sm shadow-black drop-shadow-md flex items-center gap-1 " <> VibeflowWeb.CoreComponents.username_glow_class(current_wave.user)}>
              {current_wave.user.username}
              <.verified_badge user={current_wave.user} class="h-4 w-4" />
            </span>
            <span class="text-xs text-white/70">
              <span
                id={"timestamp-#{current_wave.id}"}
                phx-hook="LocalTime"
                data-timestamp={current_wave.inserted_at}
                class="invisible"
              >
                {Calendar.strftime(current_wave.inserted_at, "%H:%M")}
              </span>
            </span>
          </div>
        </div>
      </div>

    <!-- Main Content Area -->
      <div
        id="media-control-container"
        class="flex-1 flex items-center justify-center relative bg-black"
        phx-hook="MediaControl"
      >
        <%= if current_wave.media_type == "video" do %>
          <video
            id={"video-#{current_wave.id}"}
            src={current_wave.media_url}
            autoplay
            playsinline
            muted={@is_muted}
            class="max-h-full max-w-full object-contain"
            phx-hook="WaveVideo"
          >
          </video>
        <% else %>
          <img src={current_wave.media_url} class="max-h-full max-w-full object-contain" />
        <% end %>

    <!-- Navigation Areas -->
        <div phx-click="prev" class="absolute inset-y-0 left-0 w-[30%] z-10 cursor-pointer"></div>
        <div phx-click="next" class="absolute inset-y-0 right-0 w-[70%] z-10 cursor-pointer"></div>
      </div>

    <!-- Music Info with Animated Bars -->
      <%= if current_wave.music_track do %>
        <div class="absolute bottom-24 left-1/2 -translate-x-1/2 w-[90%] max-w-sm z-20">
          <div class="bg-black/40 backdrop-blur-lg rounded-full flex items-center gap-3 p-3 border border-white/10 shadow-lg">
            <!-- Animated Music Bars -->
            <div class="flex gap-1 items-center">
              <div class="w-1 bg-white rounded-full music-bar-1"></div>
              <div class="w-1 bg-white rounded-full music-bar-2"></div>
              <div class="w-1 bg-white rounded-full music-bar-3"></div>
              <div class="w-1 bg-white rounded-full music-bar-4"></div>
              <div class="w-1 bg-white rounded-full music-bar-5"></div>
            </div>

            <div class="flex-1 min-w-0">
              <div class="font-bold text-white text-sm truncate">
                {current_wave.music_track.title}
              </div>
              <div class="text-gray-300 text-xs truncate">{current_wave.music_track.artist}</div>
            </div>
          </div>
        </div>
        <audio
          id={"audio-player-#{current_wave.id}"}
          src={current_wave.music_track.audio_url}
          autoplay
          phx-hook="WaveAudio"
          class="hidden"
        >
        </audio>
      <% end %>

    <!-- Bottom Message Input -->
      <div class="absolute bottom-0 left-0 right-0 z-20 p-4 pb-8">
        <form phx-submit="send_message" class="flex items-center gap-3">
          <input
            type="text"
            name="message"
            value={@message}
            phx-change="update_message"
            placeholder="Send a message..."
            class="wave-message-input flex-1 bg-white/10 border border-white/20 rounded-full px-4 py-3 text-white placeholder-white/50 focus:outline-none focus:border-white/40"
          />
          <button
            type="submit"
            class="w-12 h-12 bg-white rounded-full flex items-center justify-center hover:bg-gray-200 transition-colors"
          >
            <svg class="w-5 h-5 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
              />
            </svg>
          </button>
        </form>
      </div>
    </div>
    """
  end

  # --- EVENTS ---

  @impl true
  def handle_event("next", _, socket), do: {:noreply, go_next(socket)}
  @impl true
  def handle_event("prev", _, socket), do: {:noreply, go_prev(socket)}

  @impl true
  def handle_event("toggle_mute", _, socket) do
    current_wave = Enum.at(socket.assigns.waves, socket.assigns.current_index)
    video_element = "video-#{current_wave.id}"
    audio_element = "audio-player-#{current_wave.id}"

    new_muted = !socket.assigns.is_muted

    {:noreply,
     socket
     |> assign(:is_muted, new_muted)
     |> push_event("toggle_media", %{
       "video_id" => video_element,
       "audio_id" => audio_element,
       "muted" => new_muted
     })}
  end

  @impl true
  def handle_event("toggle_pause", _, socket) do
    current_wave = Enum.at(socket.assigns.waves, socket.assigns.current_index)
    video_element = "video-#{current_wave.id}"

    new_paused = !socket.assigns.is_paused

    {:noreply,
     socket
     |> assign(:is_paused, new_paused)
     |> push_event("toggle_video", %{"video_id" => video_element, "paused" => new_paused})}
  end

  @impl true
  def handle_event("show_options", _, socket) do
    # TODO: Show options menu (share, report, etc.)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message", %{"message" => value}, socket) do
    {:noreply, assign(socket, :message, value)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    current_user = socket.assigns.current_user
    current_wave = Enum.at(socket.assigns.waves, socket.assigns.current_index)
    wave_owner = current_wave.user

    if String.trim(message) == "" do
      {:noreply, socket}
    else
      # Find or create conversation between viewer and wave owner
      case Chat.find_or_create_direct_conversation(current_user.id, wave_owner.id) do
        {:ok, conversation} ->
          # Create message with wave reference
          case Chat.create_message(%{
            content: message,
            user_id: current_user.id,
            conversation_id: conversation.id,
            shared_wave_id: current_wave.id
          }) do
            {:ok, _message} ->
              # Broadcast to update sidebar for both sender and wave owner
              Phoenix.PubSub.broadcast(
                Vibeflow.PubSub,
                "user_sidebar:#{wave_owner.id}",
                {:update_sidebar, %{conversation_id: conversation.id}}
              )

              Phoenix.PubSub.broadcast(
                Vibeflow.PubSub,
                "user_sidebar:#{current_user.id}",
                {:update_sidebar, %{conversation_id: conversation.id}}
              )

              {:noreply,
               socket
               |> assign(:message, "")
               |> put_flash(:info, "Message sent to #{wave_owner.username}")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to send message")}
          end

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not start conversation")}
      end
    end
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply,
     socket
     |> cancel_timer()
     |> push_navigate(to: ~p"/feed")}
  end

  def handle_event("video_ended", _, socket), do: {:noreply, go_next(socket)}

  def handle_info(:next_slide, socket), do: {:noreply, go_next(socket)}

  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  # --- HELPERS ---

  defp go_next(socket) do
    current = socket.assigns.current_index
    total = length(socket.assigns.waves)

    if current + 1 >= total do
      socket
      |> cancel_timer()
      |> go_next_user_or_feed()
    else
      socket
      |> assign(:current_index, current + 1)
      |> schedule_timer()
    end
  end

  defp go_next_user_or_feed(socket) do
    groups = socket.assigns.wave_groups || []
    idx = socket.assigns.group_index || 0
    next_idx = idx + 1

    if next_idx < length(groups) do
      next_user = Enum.at(groups, next_idx).user

      socket
      |> assign(:group_index, next_idx)
      |> push_navigate(to: ~p"/waves/view/#{next_user.username}")
    else
      socket
      |> push_navigate(to: ~p"/feed")
    end
  end

  defp go_prev(socket) do
    current = socket.assigns.current_index

    if current > 0 do
      socket
      |> assign(:current_index, current - 1)
      |> schedule_timer()
    else
      schedule_timer(socket)
    end
  end

  # 1. Timer Logic
  defp schedule_timer(socket) do
    # Cancel old timer
    socket = cancel_timer(socket)

    current_wave = Enum.at(socket.assigns.waves, socket.assigns.current_index)

    # --- NEW: MARK AS SEEN ---
    # We do this in a fire-and-forget task so we don't block the UI
    if socket.assigns.current_user do
      Task.start(fn ->
        Vibeflow.Waves.mark_wave_as_seen(socket.assigns.current_user.id, current_wave.id)
      end)
    end

    # -------------------------

    if current_wave.media_type != "video" and current_wave.music_track do
      # Cap image with music to 7 seconds or song duration (whichever is shorter)
      delay = min(current_wave.music_track.duration_ms || 7000, 7000)
      timer_ref = Process.send_after(self(), :next_slide, delay)
      assign(socket, :timer_ref, timer_ref)
    else
      if current_wave.media_type != "video" do
        # If image without music, 5 seconds
        timer_ref = Process.send_after(self(), :next_slide, 5000)
        assign(socket, :timer_ref, timer_ref)
      else
        socket
      end
    end
  end

  defp cancel_timer(socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    assign(socket, :timer_ref, nil)
  end

  defp bar_style(index, current) when index < current, do: "bg-white w-full"
  defp bar_style(index, current) when index == current, do: "bg-white w-full animate-pulse"
  defp bar_style(_, _), do: "bg-transparent w-0"
end
