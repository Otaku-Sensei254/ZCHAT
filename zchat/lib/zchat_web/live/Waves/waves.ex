defmodule ZchatWeb.Waves.Waves do
  use ZchatWeb, :live_component
  alias Zchat.Stories

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:step, 1)          # 1: Camera/Upload, 2: Music, 3: Preview
     |> assign(:mode, :camera)    # :camera or :upload
     |> assign(:music_results, [])
     |> assign(:selected_music, nil)
     |> assign(:search_query, "")
     |> allow_upload(:media, accept: ~w(.jpg .jpeg .png), max_entries: 1)
    }
  end

@impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 bg-black flex flex-col animate-in fade-in duration-200">

      <div class="absolute top-0 left-0 right-0 p-4 flex justify-between items-center z-50 bg-gradient-to-b from-black/80 to-transparent">
        <button phx-click="close_waves_modal" class="text-white drop-shadow-md hover:scale-110 transition">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-8 h-8">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        <%= if @step > 1 do %>
           <h2 class="text-white font-bold text-lg drop-shadow-md">
             <%= if @step == 2, do: "Pick a Song", else: "Preview" %>
           </h2>
        <% end %>
        <div class="w-8"></div>
      </div>

      <div class="flex-1 relative bg-zinc-900 flex items-center justify-center overflow-hidden">

        <%= if @step == 1 do %>

          <%= if @uploads.media.entries != [] do %>
            <div class="relative w-full h-full bg-black">
              <%= for entry <- @uploads.media.entries do %>
                <.live_img_preview entry={entry} class="w-full h-full object-contain" />
              <% end %>

              <div class="absolute bottom-10 right-6 z-50">
                <button phx-click="next_step" phx-target={@myself} class="bg-blue-600 hover:bg-blue-500 text-white px-8 py-3 rounded-full font-bold shadow-lg flex items-center gap-2">
                  Next
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-4 h-4">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" />
                  </svg>
                </button>
              </div>

              <button phx-click="cancel_upload" phx-target={@myself} class="absolute top-20 left-6 z-50 bg-black/50 text-white px-4 py-2 rounded-full backdrop-blur-md border border-white/20 text-sm">
                 Retake
              </button>
            </div>

          <% else %>
            <%= if @mode == :camera do %>
              <div id="camera-wrapper" phx-hook="CameraCapture" class="w-full h-full relative">
                <video id="camera-feed" class="w-full h-full object-cover" autoplay playsinline muted></video>

                <div class="absolute bottom-0 left-0 right-0 h-40 bg-gradient-to-t from-black/90 to-transparent flex justify-center items-center gap-10 z-40">
                   <button phx-click="set_mode" phx-value-mode="upload" phx-target={@myself} class="p-4 rounded-full bg-white/10 text-white backdrop-blur-md hover:bg-white/20">
                     <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
                       <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" />
                     </svg>
                   </button>

                   <button phx-click={JS.push("trigger-capture", target: @myself)} class="w-20 h-20 rounded-full border-4 border-white bg-white/20 hover:bg-white/40 transition-all active:scale-95 shadow-xl"></button>

                   <button phx-click="switch_camera" phx-target={@myself} class="p-4 rounded-full bg-white/10 text-white backdrop-blur-md hover:bg-white/20">
                     <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
                       <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
                     </svg>
                   </button>
                </div>
              </div>

            <% else %>
              <div class="text-white text-center p-8 w-full max-w-md" phx-drop-target={@uploads.media.ref}>
                <div class="bg-zinc-800 p-10 rounded-2xl border-2 border-dashed border-zinc-600 flex flex-col items-center gap-4">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-12 h-12 text-blue-500">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 16.5V9.75m0 0l3 3m-3-3l-3 3M6.75 19.5a4.5 4.5 0 01-1.41-8.775 5.25 5.25 0 0110.233-2.33 3 3 0 013.758 3.848A3.752 3.752 0 0118 19.5H6.75z" />
                  </svg>
                  <p class="text-lg font-medium">Click to upload photo</p>
                  <.live_file_input upload={@uploads.media} class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-600 file:text-white hover:file:bg-blue-700"/>
                </div>
                <button phx-click="set_mode" phx-value-mode="camera" phx-target={@myself} class="mt-8 text-blue-400 hover:text-blue-300 underline">Back to Camera</button>
              </div>
            <% end %>
          <% end %>
        <% end %>

        <%= if @step == 2 do %>
          <div class="w-full max-w-md h-full flex flex-col p-4 pt-20">
            <form phx-change="search_music" phx-submit="prevent_submit" phx-target={@myself} class="mb-4">
              <div class="relative">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="absolute left-3 top-3.5 w-5 h-5 text-gray-400">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                <input type="text" name="query" value={@search_query} placeholder="Search songs..." class="w-full bg-zinc-800 text-white border-0 rounded-xl pl-10 pr-4 py-3 focus:ring-2 focus:ring-blue-500" autocomplete="off" phx-debounce="500" />
              </div>
            </form>

            <div class="flex-1 overflow-y-auto space-y-2">
              <button phx-click="skip_music" phx-target={@myself} class="w-full p-4 text-left rounded-xl border border-dashed border-zinc-700 text-gray-400 hover:bg-zinc-800 hover:text-white transition">
                No Music (Skip)
              </button>

              <%= for song <- @music_results do %>
                <button phx-click="select_music" phx-value-id={song.track_id} phx-target={@myself} class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-zinc-800 transition text-left group border border-transparent hover:border-zinc-700">
                  <img src={song.artwork_url} class="w-12 h-12 rounded-md object-cover" />
                  <div class="flex-1 min-w-0">
                    <p class="font-bold text-white truncate"><%= song.track_name %></p>
                    <p class="text-sm text-gray-400 truncate"><%= song.artist_name %></p>
                  </div>
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6 text-blue-500 opacity-0 group-hover:opacity-100 transition">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @step == 3 do %>
          <div class="relative w-full h-full bg-black">
            <%= for entry <- @uploads.media.entries do %>
              <.live_img_preview entry={entry} class="w-full h-full object-contain" />
            <% end %>

            <%= if @selected_music do %>
              <div class="absolute bottom-24 left-0 right-0 flex justify-center z-20">
                <div class="bg-black/60 backdrop-blur-xl border border-white/10 px-4 py-2 rounded-full flex items-center gap-3 shadow-2xl">
                   <img src={@selected_music.artwork_url} class="w-8 h-8 rounded-full animate-[spin_4s_linear_infinite]" />
                   <div class="flex flex-col">
                     <span class="text-white text-xs font-bold"><%= @selected_music.track_name %></span>
                     <span class="text-gray-300 text-[10px]"><%= @selected_music.artist_name %></span>
                   </div>
                </div>
              </div>
              <audio src={@selected_music.preview_url} autoplay loop></audio>
            <% end %>

            <div class="absolute bottom-6 left-0 right-0 flex justify-center gap-4 z-30 px-6">
              <button phx-click="restart" phx-target={@myself} class="bg-zinc-800 text-white px-6 py-3 rounded-full font-bold">Back</button>
              <button phx-click="save_wave" phx-target={@myself} class="flex-1 bg-blue-600 hover:bg-blue-500 text-white px-6 py-3 rounded-full font-bold shadow-lg flex justify-center items-center gap-2">
                Share Wave 🚀
              </button>
            </div>
          </div>
        <% end %>

      </div>
    </div>
    """
  end

  # --- EVENT HANDLERS ---

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_existing_atom(mode))}
  end

  # 1. Camera Logic
  def handle_event("switch_camera", _, socket) do
    {:noreply, push_event(socket, "switch-camera-mode", %{})}
  end

  def handle_event("trigger-capture", _, socket), do: {:noreply, socket} # JS does the work
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", _, socket) do
    ref = List.first(socket.assigns.uploads.media.entries).ref
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  def handle_event("next_step", _, socket) do
    {:noreply, assign(socket, step: 2)}
  end

  # 2. iTunes Logic
  def handle_event("search_music", %{"query" => query}, socket) do
    # Call iTunes API
    results = search_itunes(query)
    {:noreply, assign(socket, music_results: results, search_query: query)}
  end

  def handle_event("select_music", %{"id" => track_id}, socket) do
    track_id = String.to_integer(track_id)
    song = Enum.find(socket.assigns.music_results, fn x -> x.track_id == track_id end)
    {:noreply, assign(socket, step: 3, selected_music: song)}
  end

  def handle_event("skip_music", _, socket) do
    {:noreply, assign(socket, step: 3, selected_music: nil)}
  end

  def handle_event("restart", _, socket), do: {:noreply, assign(socket, step: 1)}
  def handle_event("prevent_submit", _, socket), do: {:noreply, socket}

  # 3. Save Logic
  def handle_event("save_wave", _, socket) do
    # A. Upload File
    [media_url] = consume_uploaded_entries(socket, :media, fn %{path: path}, _entry ->
      dest = Path.join("priv/static/uploads", Path.basename(path))
      File.cp!(path, dest)
      {:ok, "/uploads/#{Path.basename(path)}"}
    end)

    # B. Prepare Params
    attrs = %{
      "user_id" => socket.assigns.current_user.id,
      "media_url" => media_url,
      "caption" => "", # Add caption input if you want later
    }

    # C. Add Music Data (Flat Structure)
    attrs = if socket.assigns.selected_music do
      m = socket.assigns.selected_music
      Map.merge(attrs, %{
        "music_title" => m.track_name,
        "music_artist" => m.artist_name,
        "music_preview_url" => m.preview_url,
        "music_cover_url" => m.artwork_url
      })
    else
      attrs
    end

    # D. Save to DB
    case Stories.create_story(attrs) do
      {:ok, _} ->
        send(self(), :waves_created) # Close modal from parent
        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save wave.")}
    end
  end

  # --- HELPER FUNCTIONS ---

  defp search_itunes(query) do
    url = "https://itunes.apple.com/search?term=#{URI.encode(query)}&media=music&entity=song&limit=10"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        Enum.map(body["results"], fn item ->
          %{
            track_id: item["trackId"],
            track_name: item["trackName"],
            artist_name: item["artistName"],
            preview_url: item["previewUrl"],
            artwork_url: item["artworkUrl100"]
          }
        end)
      _ -> []
    end
  end
end
