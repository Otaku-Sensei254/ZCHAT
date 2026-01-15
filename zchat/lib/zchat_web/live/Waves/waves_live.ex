defmodule ZchatWeb.Waves.WavesLive do
  use ZchatWeb, :live_view

  alias Zchat.Waves
  alias Zchat.Infrastructure.UploadCloudinary

  @impl true
  def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Create Wave")
   |> assign(:step, 1) # 1=Camera, 2=MusicPicker, 3=Review
   |> assign(:caption, "")
   |> assign(:music_results, [])
   |> assign(:selected_music, nil)
   |> assign(:search_query, "")
   # Hide layout chrome on the Waves page so we have a full-bleed composer
   |> assign(:hide_bottom_nav, true)
   |> assign(:hide_header, true)
   |> allow_upload(:media, accept: ~w(.jpg .jpeg .png .mp4 .mov .webm), max_entries: 1)}
  end

@impl true
  def render(assigns) do
    ~H"""
    <div
      id="waves-main-container"
      phx-hook="CameraCapture"
      class="h-[100dvh] w-screen bg-black text-white flex flex-col overflow-hidden relative font-sans"
    >

      <div class="absolute inset-0 z-0 bg-black">
        <%= if @uploads.media.entries != [] do %>
          <%= for entry <- @uploads.media.entries do %>

            <%= if String.starts_with?(entry.client_type, "video") do %>
              <video
                id={"video-preview-#{entry.ref}"}
                phx-hook="LocalVideoPreview"
                autoplay loop playsinline muted={@selected_music != nil}
                class="w-full h-full object-cover"
              ></video>

            <% else %>
               <div class="w-full h-full relative">
                  <.live_img_preview entry={entry} class="w-full h-full object-cover" />
               </div>
            <% end %>

          <% end %>
        <% else %>
          <div id="camera-wrapper" class="w-full h-full relative">
            <video id="camera-feed" class="w-full h-full object-cover transform scale-x-[-1]" autoplay playsinline muted></video>

            <div id="recording-timer" class="hidden absolute top-24 left-1/2 -translate-x-1/2 bg-red-600 px-4 py-1 rounded-full font-mono font-bold text-sm tracking-widest shadow-lg z-50 animate-pulse border-2 border-white/20">
              00:00
            </div>

            <form phx-change="validate_upload" class="hidden">
              <.live_file_input upload={@uploads.media} id="gallery-input" />
            </form>
          </div>
        <% end %>
      </div>

      <div class="absolute top-0 left-0 right-0 p-4 pt-8 z-40 bg-gradient-to-b from-black/60 to-transparent flex justify-between items-center pointer-events-none">
        <.link navigate={~p"/feed"} class="pointer-events-auto p-2 bg-black/20 backdrop-blur-md rounded-full hover:bg-black/40 transition">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
        </.link>

        <%= if @uploads.media.entries != [] do %>
           <button phx-click="cancel_upload" class="pointer-events-auto text-xs font-bold bg-white/20 px-3 py-1.5 rounded-full backdrop-blur-md hover:bg-white/30 transition border border-white/10">
             Retake
           </button>
        <% end %>
      </div>

      <%= if @uploads.media.entries == [] do %>
        <div class="absolute bottom-0 left-0 right-0 z-30 pb-12 pt-24 bg-gradient-to-t from-black/90 via-black/40 to-transparent flex justify-around items-end">
            <button onclick="document.getElementById('gallery-input').click()" class="mb-6 p-3 rounded-xl bg-white/10 backdrop-blur-md border border-white/20 hover:bg-white/20 transition">
               <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
            </button>

            <div class="flex flex-col items-center gap-3">
              <button id="btn-snap" class="w-20 h-20 rounded-full border-[6px] border-white bg-transparent active:scale-95 transition-all shadow-lg"></button>
            </div>

            <div class="flex flex-col items-center gap-3">
               <button id="btn-record" class="w-14 h-14 rounded-full bg-red-500 border-4 border-white/50 hover:bg-red-600 active:scale-90 transition-all flex items-center justify-center shadow-lg">
                  <div class="w-4 h-4 bg-white rounded-sm"></div>
               </button>
            </div>

            <div class="absolute bottom-32 right-8">
               <button phx-click="switch_camera" class="p-3 rounded-full bg-black/40 text-white backdrop-blur-md border border-white/10 hover:bg-black/60 transition">
                 <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
               </button>
            </div>
        </div>
      <% end %>

      <%= if @uploads.media.entries != [] and @step != 2 do %>
         <div class="absolute top-24 left-1/2 -translate-x-1/2 z-30 w-full flex justify-center">
            <%= if @selected_music do %>
               <div class="bg-black/50 backdrop-blur-md px-4 py-2 rounded-full flex items-center gap-2 border border-white/10 shadow-lg cursor-pointer animate-bounce-small" phx-click="open_music">
                  <img src={@selected_music.artwork_url} class="w-6 h-6 rounded-full animate-spin-slow" />
                  <span class="text-xs font-bold truncate max-w-[150px]"><%= @selected_music.track_name %></span>
                  <button phx-click="remove_music" class="ml-2 text-gray-400 hover:text-white">✕</button>
               </div>
            <% else %>
               <button phx-click="open_music" class="bg-black/40 backdrop-blur-md px-5 py-2 rounded-full flex items-center gap-2 border border-white/10 text-sm font-semibold hover:bg-black/60 transition">
                  🎵 Add Sound
               </button>
            <% end %>
         </div>

         <div class="absolute bottom-0 left-0 right-0 p-6 pt-20 bg-gradient-to-t from-black/90 via-black/40 to-transparent z-30 flex flex-col gap-4">
            <form phx-change="update_caption" phx-submit="save_wave">
              <input type="text" name="caption" value={@caption} placeholder="Write a caption..."
                    class="w-full bg-white/10 border border-white/10 rounded-xl text-white placeholder-gray-300 px-4 py-3 backdrop-blur-md focus:ring-2 focus:ring-blue-500 focus:bg-black/40 transition outline-none" autocomplete="off" />
            </form>

            <button phx-click="save_wave" class="w-full bg-blue-600 hover:bg-blue-500 text-white py-3.5 rounded-xl font-bold text-lg shadow-xl shadow-blue-900/20 active:scale-[0.98] transition flex items-center justify-center gap-2">
               <%= if Enum.any?(@uploads.media.entries, &(!&1.done?)), do: "Uploading...", else: "Share to Feed 🚀" %>
            </button>
         </div>
      <% end %>

      <%= if @step == 2 do %>
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm z-40 transition-opacity" phx-click="close_music"></div>

        <div class="absolute bottom-0 left-0 right-0 h-[65dvh] bg-zinc-900 rounded-t-3xl z-50 flex flex-col shadow-2xl animate-slide-up border-t border-white/10">
           <div class="w-full flex justify-center pt-3 pb-1" phx-click="close_music">
              <div class="w-12 h-1.5 bg-zinc-700 rounded-full"></div>
           </div>

           <div class="p-4 flex gap-2 border-b border-zinc-800">
              <div class="relative flex-1">
                 <form phx-change="search_music" phx-submit="prevent_submit">
                   <input type="text" name="query" value={@search_query} placeholder="Search songs..."
                          class="w-full bg-zinc-800 text-white rounded-xl pl-4 pr-4 py-2.5 focus:ring-1 focus:ring-white border-none" phx-debounce="500" autoFocus />
                 </form>
              </div>
              <button phx-click="close_music" class="text-white font-semibold px-2">Done</button>
           </div>

           <div class="flex-1 overflow-y-auto p-2 space-y-1">
              <%= for song <- @music_results do %>
                <div phx-click="select_music" phx-value-id={song.track_id} class={"flex items-center gap-3 p-3 rounded-xl transition cursor-pointer " <> if(@selected_music && @selected_music.track_id == song.track_id, do: "bg-blue-600/20 border border-blue-500/50", else: "hover:bg-zinc-800")}>
                   <div class="relative w-12 h-12 rounded-md overflow-hidden bg-zinc-800 shrink-0">
                      <img src={song.artwork_url} class="w-full h-full object-cover" />
                   </div>

                   <div class="flex-1 min-w-0">
                      <p class={"font-bold truncate text-sm " <> if(@selected_music && @selected_music.track_id == song.track_id, do: "text-blue-400", else: "text-white")}><%= song.track_name %></p>
                      <p class="text-xs text-gray-400 truncate"><%= song.artist_name %></p>
                   </div>
                </div>
              <% end %>
           </div>
        </div>
      <% end %>

      <%= if @selected_music do %>
        <audio src={@selected_music.preview_url} autoplay loop id="music-preview-player" class="hidden"></audio>
      <% end %>

    </div>
    """
  end
  # --- LOGIC ---

  @impl true
  def handle_event("validate_upload", _, socket), do: {:noreply, socket}

  def handle_event("switch_camera", _, socket) do
    {:noreply, push_event(socket, "switch-camera-mode", %{})}
  end

  def handle_event("update_caption", %{"caption" => caption}, socket) do
    {:noreply, assign(socket, :caption, caption)}
  end

  def handle_event("cancel_upload", _, socket) do
    # Cancel all uploads
    socket = Enum.reduce(socket.assigns.uploads.media.entries, socket, fn entry, acc ->
      cancel_upload(acc, :media, entry.ref)
    end)
    {:noreply, assign(socket, step: 1, selected_music: nil, caption: "")}
  end

  def handle_event("open_music", _, socket), do: {:noreply, assign(socket, step: 2)}
  def handle_event("close_music", _, socket), do: {:noreply, assign(socket, step: 3)}
  def handle_event("remove_music", _, socket), do: {:noreply, assign(socket, selected_music: nil)}

  def handle_event("search_music", %{"query" => query}, socket) do
    results = search_itunes(query)
    {:noreply, assign(socket, music_results: results, search_query: query)}
  end

  def handle_event("select_music", %{"id" => track_id}, socket) do
    track_id = String.to_integer(track_id)
    song = Enum.find(socket.assigns.music_results, fn x -> x.track_id == track_id end)
    # Automatically selects and plays (via the hidden audio tag in render)
    {:noreply, assign(socket, selected_music: song)}
  end

  def handle_event("prevent_submit", _, socket), do: {:noreply, socket}

  def handle_event("save_wave", _, socket) do
    entries = socket.assigns.uploads.media.entries
    if Enum.any?(entries, &(!&1.done?)) do
      {:noreply, put_flash(socket, :info, "Please wait for upload to finish...")}
    else
      # Consume the uploaded file(s), upload to Cloudinary, then persist a Wave record
      results = consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        # do Cloudinary upload first
        case UploadCloudinary.upload_file(path) do
          {:ok, %{url: url, resource_type: resource_type}} ->
            # Cleanup the temporary file to folder
            try do
              File.rm(path)
            rescue
              _ -> :ok
            end
            {:ok, %{media_url: url, media_type: resource_type}}

          {:error, _reason} ->
            # Fallback: copy to priv/static/uploads and serve from app
            ext = Path.extname(entry.client_name) || ".jpg"
            filename = "#{System.unique_integer([:positive])}#{ext}"
            dest = Path.join(["priv", "static", "uploads", filename])
            File.mkdir_p!(Path.dirname(dest))
            File.cp!(path, dest)
            try do
              File.rm(path)
            rescue
              _ -> :ok
            end
            {:ok, %{media_url: "/uploads/#{filename}", media_type: "image"}}
        end
      end)

      # Use the first uploaded result
      [%{media_url: media_url, media_type: media_type} | _] = results

      music = socket.assigns.selected_music
      attrs = %{
        media_url: media_url,
        media_type: media_type,
        caption: socket.assigns.caption,
        user_id: socket.assigns.current_user && socket.assigns.current_user.id,
        music_preview_url: music && music.preview_url,
        music_title: music && music.track_name,
        music_artist: music && music.artist_name,
        music_cover_url: music && music.artwork_url
      }

      case Waves.create_wave(attrs) do
        {:ok, _wave} ->
          {:noreply,
           socket
           |> put_flash(:info, "Wave Shared!")
           |> push_navigate(to: "/feed")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save wave: #{inspect(changeset)}")}
      end
    end
  end

  defp search_itunes(query) when byte_size(query) > 0 do
    url = "https://itunes.apple.com/search?term=#{URI.encode(query)}&media=music&limit=12"

    case Finch.build(:get, url) |> Finch.request(Zchat.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"results" => results}} when is_list(results) ->
            Enum.map(results, fn r ->
              %{
                track_id: r["trackId"],
                track_name: r["trackName"] || "Unknown",
                artist_name: r["artistName"] || "Unknown",
                artwork_url: r["artworkUrl100"],
                preview_url: r["previewUrl"] # Essential for audio preview
              }
            end)
          _ -> []
        end
      _ -> []
    end
  end
  defp search_itunes(_), do: []
end
