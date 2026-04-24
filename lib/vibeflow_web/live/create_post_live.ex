defmodule VibeflowWeb.CreatePostLive do
  use VibeflowWeb, :live_view

  import VibeflowWeb.CoreComponents
  require Logger

  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post

  import VibeflowWeb.CoreComponents
  import Ecto.Changeset
  alias Vibeflow.Infras

  alias Vibeflow.Infrastructure.UploadCloudinary

  @impl true
  def mount(_params, _session, socket) do
    changeset = Posts.change_post(%Post{})
    form = to_form(changeset, as: :post)

    {:ok,
     socket
     |> assign(:page_title, "Create New Post")
     |> assign(:form, form)
     |> assign(:changeset, changeset)
     |> assign(:uploaded_files, [])
     |> allow_upload(:media,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webp),
       # inside vibe not chat
       max_entries: 21,
       max_file_size: 100_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  # --- FIX 1: Check ALL entries before triggering consumption ---
  # We cannot consume partially if other files in the same bucket
  # are still in flight. We must wait for the whole batch to turn green (100%).
  def handle_progress(:media, _entry, socket) do
    # Check if ALL entries currently known to the socket are done
    all_done? = Enum.all?(socket.assigns.uploads.media.entries, & &1.done?)

    if all_done? do
      # Use send_after with 0ms to ensure we process this
      # after the current stack of progress events clears.
      Process.send_after(self(), :consume_media, 0)
    end

    {:noreply, socket}
  end

  # --- FIX 2: Safe Consumption Handler ---
  @impl true
  def handle_info(:consume_media, socket) do
    # Double-check that state is still valid (user didn't drop a new file 1ms ago)
    # This prevents the "entries are still in progress" crash.
    all_done? = Enum.all?(socket.assigns.uploads.media.entries, & &1.done?)

    if all_done? do
      uploaded_results =
        consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
          case UploadCloudinary.upload_file(
                 path,
                 upload_kind_for(entry),
                 filename: entry.client_name,
                 content_type: entry.client_type
               ) do
            {:ok, result} ->
              {:ok,
               %{
                 "url" => result.url,
                 "type" => result.resource_type,
                 "client_name" => entry.client_name,
                 "client_size" => entry.client_size
               }}

            {:error, _reason} ->
              {:postpone, :upload_failed}
          end
        end)

      {:noreply, store_uploaded_media(socket, uploaded_results)}
    else
      # If a new file started uploading in the meantime, do nothing.
      # We will get another progress event later when that one finishes.
      {:noreply, socket}
    end
  end

  # Catch-all for other info messages
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    # Use the form's media state first, then any already-stored uploads,
    # then fall back to a final consume attempt.
    clean_media =
      socket
      |> media_files_from_socket()
      |> case do
        [] ->
          consume_pending_media(socket)

        media ->
          media
      end

    clean_media =
      clean_media
      |> normalize_media_files()
      |> Enum.uniq_by(& &1["url"])

    if clean_media == [] do
      Logger.warning(
        "Create post save blocked because no media files were attached: " <>
          "#{inspect(%{uploaded_files: socket.assigns.uploaded_files, form_media: Ecto.Changeset.get_field(socket.assigns.changeset, :media_files, []), upload_entries: Enum.map(socket.assigns.uploads.media.entries, &%{ref: &1.ref, done: &1.done?})})}"
      )

      {:noreply,
       socket
       |> put_flash(:error, "Please wait for the image or video upload to finish.")
       |> assign(:form, to_form(socket.assigns.changeset, as: :post))}
    else
      post_params =
        Map.put(post_params, "media_files", clean_media)

      case Posts.create_post(socket.assigns.current_user, post_params) do
        {:ok, post} ->
          {:noreply,
           socket
           |> put_flash(:info, "Post created successfully!")
           |> push_navigate(to: ~p"/feed?#{[highlight_post: to_string(post.uuid)]}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error("Create post failed: #{inspect(changeset.errors)}")

          {:noreply, assign(socket, form: to_form(changeset, as: :post))}
      end
    end
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      %Post{}
      |> Posts.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset, form: to_form(changeset, as: :post))}
  end

  @impl true
  def handle_event("remove-uploaded", %{"index" => index}, socket) do
    new_files =
      socket.assigns.uploaded_files
      |> List.delete_at(String.to_integer(index))

    media_files = normalize_media_files(new_files)
    changeset = Ecto.Changeset.put_change(socket.assigns.changeset, :media_files, media_files)

    {:noreply,
     socket
     |> assign(:uploaded_files, new_files)
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset, as: :post))}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_event("add_tag", params, socket) do
    tag = String.trim(params["tag"] || params["value"] || "")

    if tag != "" do
      changeset = socket.assigns.changeset
      current_tags = Ecto.Changeset.get_field(changeset, :tags, [])

      if tag in current_tags do
        {:noreply, socket}
      else
        new_changeset = Ecto.Changeset.put_change(changeset, :tags, current_tags ++ [tag])

        {:noreply,
         assign(socket, changeset: new_changeset, form: to_form(new_changeset, as: :post))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    changeset = socket.assigns.changeset
    current_tags = Ecto.Changeset.get_field(changeset, :tags, [])
    new_changeset = Ecto.Changeset.put_change(changeset, :tags, List.delete(current_tags, tag))

    {:noreply, assign(socket, changeset: new_changeset, form: to_form(new_changeset, as: :post))}
  end

  def error_to_string(:too_large), do: "File is too large (Max 100MB)"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp media_files_from_socket(socket) do
    socket.assigns.changeset
    |> Ecto.Changeset.get_field(:media_files, [])
    |> normalize_media_files()
    |> case do
      [] -> normalize_media_files(socket.assigns.uploaded_files || [])
      media -> media
    end
  end

  defp normalize_media_files(media_files) when is_list(media_files) do
    Enum.map(media_files, fn
      %{"url" => _url, "type" => _type} = item ->
        item

      %{url: url, type: type} when is_binary(url) and is_binary(type) ->
        %{"url" => url, "type" => type}

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_media_files(_), do: []

  defp store_uploaded_media(socket, uploaded_results) do
    current = socket.assigns.uploaded_files || []
    updated_files = Enum.uniq_by(current ++ uploaded_results, & &1["url"])
    media_files = normalize_media_files(updated_files)
    changeset = Ecto.Changeset.put_change(socket.assigns.changeset, :media_files, media_files)

    socket
    |> assign(:uploaded_files, updated_files)
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset, as: :post))
  end

  defp consume_pending_media(socket) do
    if Enum.any?(socket.assigns.uploads.media.entries, & &1.done?) do
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        case UploadCloudinary.upload_file(
               path,
               upload_kind_for(entry),
               filename: entry.client_name,
               content_type: entry.client_type
             ) do
          {:ok, result} ->
            {:ok,
             %{
               "url" => result.url,
               "type" => result.resource_type,
               "client_name" => entry.client_name,
               "client_size" => entry.client_size
             }}

          {:error, _reason} ->
            {:postpone, :upload_failed}
        end
      end)
    else
      []
    end
  end

  defp upload_kind_for(entry) do
    client_type = entry.client_type || ""
    client_name = String.downcase(entry.client_name || "")
    ext = Path.extname(client_name)

    cond do
      String.starts_with?(client_type, "image/") -> :image
      String.starts_with?(client_type, "video/") -> :video
      ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".avif"] -> :image
      ext in [".mp4", ".mov", ".mkv", ".webm", ".avi", ".m4v"] -> :video
      true -> :auto
    end
  end
end
