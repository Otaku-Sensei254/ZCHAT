defmodule VibeflowWeb.CreatePostLive do
  use VibeflowWeb, :live_view

  import VibeflowWeb.CoreComponents
  require Logger

  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post

  @upload_dir "/tmp/vibeflow/uploads"

  @impl true
  def mount(_params, _session, socket) do
    changeset = Posts.change_post(%Post{})
    form = to_form(changeset, as: :post)

    File.mkdir_p!(@upload_dir)

    {:ok,
     socket
     |> assign(:page_title, "Create New Post")
     |> assign(:form, form)
     |> assign(:changeset, changeset)
     |> assign(:uploaded_files, [])
     |> allow_upload(:media,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webp),
       max_entries: 21,
       max_file_size: 100_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  def handle_progress(:media, _entry, socket) do
    all_done? = Enum.all?(socket.assigns.uploads.media.entries, & &1.done?)

    if all_done? do
      Process.send_after(self(), :consume_media, 0)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:consume_media, socket) do
    all_done? = Enum.all?(socket.assigns.uploads.media.entries, & &1.done?)

    if all_done? do
      uploaded_results =
        consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
          persistent_path = persist_temp_file(path, entry)
          {:ok, persistent_path}
        end)

      {:noreply, store_uploaded_media(socket, uploaded_results)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    uploaded_results =
      socket.assigns.uploaded_files
      |> case do
        [] -> consume_pending_media(socket)
        results -> results
      end

    if uploaded_results == [] do
      {:noreply,
       socket
       |> put_flash(:error, "Please wait for file uploads to finish.")}
    else
      files = build_file_list(uploaded_results)

      case Posts.create_draft_post(socket.assigns.current_user, post_params) do
        {:ok, post} ->
          %{post_id: post.id, files: files}
          |> Vibeflow.Workers.PostUploadWorker.new()
          |> Oban.insert()

          {:noreply,
           socket
           |> put_flash(:info, "Your post is being processed! You'll be notified when it's live.")
           |> push_navigate(to: ~p"/feed")}

        {:error, changeset} ->
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
    file = Enum.at(socket.assigns.uploaded_files, String.to_integer(index))

    if file do
      File.rm(file["path"])
    end

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

  defp persist_temp_file(path, entry) do
    ext = Path.extname(entry.client_name || "file")
    dest = Path.join(@upload_dir, "#{Ecto.UUID.generate()}#{ext}")

    File.cp!(path, dest)

    %{
      "path" => dest,
      "client_name" => entry.client_name,
      "client_type" => entry.client_type,
      "client_size" => entry.client_size
    }
  end

  defp build_file_list(uploaded_results) do
    Enum.map(uploaded_results, fn item ->
      %{
        "path" => item["path"],
        "client_name" => item["client_name"],
        "client_type" => item["client_type"]
      }
    end)
  end

  defp store_uploaded_media(socket, uploaded_results) do
    current = socket.assigns.uploaded_files || []
    updated_files = Enum.uniq_by(current ++ uploaded_results, & &1["path"])

    socket
    |> assign(:uploaded_files, updated_files)
  end

  defp consume_pending_media(socket) do
    if Enum.any?(socket.assigns.uploads.media.entries, & &1.done?) do
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        persistent_path = persist_temp_file(path, entry)
        {:ok, persistent_path}
      end)
    else
      []
    end
  end
end
