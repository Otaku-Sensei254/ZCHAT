defmodule VibeflowWeb.Waves.ViewWavesLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Waves

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, waves: [], current_index: 0, timer_ref: nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user_id = params["user_id"]
    waves = Waves.list_user_waves(user_id)

    if waves == [] do
      {:noreply,
       socket
       |> put_flash(:info, "This user has no active waves.")
       |> push_navigate(to: ~p"/feed")}
    else
      socket =
        socket
        |> assign(:waves, waves)
        |> assign(:current_index, 0)
        |> assign(:timer_ref, nil)
        |> assign(:hide_bottom_nav, true)

      {:noreply, schedule_timer(socket)}
    end
  end

  # --- RENDER ---
  def render(assigns) do
    ~H"""
    <div id="story-viewer" class="fixed inset-0 bg-black z-50 flex flex-col text-white select-none">

      <div class="absolute top-0 left-0 right-0 z-20 flex gap-1 p-2 pt-4">
        <%= for {_, index} <- Enum.with_index(@waves) do %>
           <div class="h-1 flex-1 rounded-full bg-gray-600/50 overflow-hidden">
             <div class={"h-full transition-all duration-300 " <> bar_style(index, @current_index)}></div>
           </div>
        <% end %>
      </div>

      <% current_wave = Enum.at(@waves, @current_index) %>

      <div class="absolute top-8 left-0 right-0 z-20 px-4 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <img
            src={current_wave.user.avatar_url || "/images/default_avatar.png"}
            class="w-8 h-8 rounded-full border border-white object-cover"
          />
          <span class="font-bold text-sm shadow-black drop-shadow-md">
            <%= current_wave.user.username %>
          </span>
          <span class="text-xs text-white/70 ml-2">
            <%= Calendar.strftime(current_wave.inserted_at, "%H:%M") %>
          </span>
        </div>

        <button phx-click="close" class="text-3xl font-bold p-2 hover:text-gray-300 transition-colors">
          &times;
        </button>
      </div>

      <div class="flex-1 flex items-center justify-center relative bg-zinc-900">
        <%= if current_wave.media_type == "video" do %>
          <video
            id={"video-#{current_wave.id}"}
            src={current_wave.media_url}
            autoplay
            playsinline
            muted={false}
            class="max-h-full max-w-full"
            phx-hook="StoryVideo"
          ></video>
        <% else %>
          <img src={current_wave.media_url} class="max-h-full max-w-full object-contain" />
        <% end %>

        <%= if current_wave.caption do %>
          <div class="absolute bottom-20 text-center bg-black/60 px-4 py-2 rounded-xl backdrop-blur-md max-w-[80%] text-sm">
            <%= current_wave.caption %>
          </div>
        <% end %>

        <div phx-click="prev" class="absolute inset-y-0 left-0 w-[30%] z-10 cursor-pointer"></div>
        <div phx-click="next" class="absolute inset-y-0 right-0 w-[70%] z-10 cursor-pointer"></div>
      </div>

      <%= if current_wave.music_track do %>
        <div class="absolute bottom-6 left-1/2 -translate-x-1/2 w-[90%] max-w-sm z-20">
          <div class="bg-black/40 backdrop-blur-lg rounded-full flex items-center gap-3 p-2 border border-white/10 shadow-lg">
            <img src={current_wave.music_track.cover_art} class="w-10 h-10 rounded-full object-cover animate-spin-slow" />
            <div class="flex-1 min-w-0">
              <div class="font-bold text-white text-sm truncate"><%= current_wave.music_track.title %></div>
              <div class="text-gray-300 text-xs truncate"><%= current_wave.music_track.artist %></div>
            </div>
          </div>
        </div>
        <audio src={current_wave.music_track.audio_url} autoplay loop class="hidden"></audio>
      <% end %>
    </div>
    """
  end

  # --- EVENTS ---

  def handle_event("next", _, socket), do: {:noreply, go_next(socket)}
  def handle_event("prev", _, socket), do: {:noreply, go_prev(socket)}

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
      |> push_navigate(to: ~p"/feed")
    else
      socket
      |> assign(:current_index, current + 1)
      |> schedule_timer()
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
      # If image with music, use song duration, with a fallback to 5 seconds
      delay = current_wave.music_track.duration_ms || 5000
      timer_ref = Process.send_after(self(), :next_slide, delay)
      assign(socket, :timer_ref, timer_ref)
    else if current_wave.media_type != "video" do
      # If image without music, 5 seconds
      timer_ref = Process.send_after(self(), :next_slide, 5000)
      assign(socket, :timer_ref, timer_ref)
    else
      # If video, wait for JS hook
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
