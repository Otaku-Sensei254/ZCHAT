defmodule ZchatWeb.CreatePostLive do
  use ZchatWeb, :live_view

  import ZchatWeb.CoreComponents

  alias Zchat.Posts
  alias Zchat.Posts.Post

  import ZchatWeb.CoreComponents
  import Ecto.Changeset
  alias Zchat.Infras

  alias Zchat.Infrastructure.UploadCloudinary


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
       max_entries: 20,
       max_file_size: 50_000_000,
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
          case UploadCloudinary.upload_file(path) do
            {:ok, result} ->
              {:ok, %{
                "url" => result.url,
                "type" => result.resource_type,
                "client_name" => entry.client_name,
                "client_size" => entry.client_size
              }}
            {:error, _reason} ->
              {:postpone, :upload_failed}
          end
        end)

      # Append new results to existing ones (don't overwrite)
      {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_results))}
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
    clean_media =
      socket.assigns.uploaded_files
      |> Enum.map(fn file -> Map.take(file, ["url", "type"]) end)

    post_params =
      if clean_media != [] do
        Map.put(post_params, "media_files", clean_media)
      else
        post_params
      end

    case Posts.create_post(socket.assigns.current_user, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully!")
         |> push_navigate(to: ~p"/feed")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :post))}
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

    {:noreply, assign(socket, :uploaded_files, new_files)}
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
        {:noreply, assign(socket, changeset: new_changeset, form: to_form(new_changeset, as: :post))}
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

  def error_to_string(:too_large), do: "File is too large. (Max 50MB)"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
