defmodule ZchatWeb.CreatePost do
  use ZchatWeb, :live_view

  alias Zchat.Posts
  alias Zchat.Posts.Post
  import ZchatWeb.CoreComponents
  import Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    changeset = Posts.change_post(%Post{})
    form = to_form(changeset, as: :post)

    {:ok,
     socket
     |> assign(:page_title, "Create New Post")
     |> assign(:form, form)
     |> assign(:changeset, changeset)
     |> allow_upload(:media,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov),
       max_entries: 20,
       max_file_size: 10_000_000,
       auto_upload: true
     )}
  end

  # Validate form inputs
  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.changeset
      |> cast(post_params, [:title, :content, :category,])
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       changeset: changeset,
       form: to_form(changeset, as: :post)
     )}
  end

  # ✅ Add tags dynamically
  @impl true
  def handle_event("add_tag", %{"tag" => tag}, socket) do
    if tag != "" do
      changeset = socket.assigns.changeset
      current_tags = get_field(changeset, :tags, [])

      new_changeset =
        put_change(changeset, :tags, current_tags ++ [tag])

      {:noreply, assign(socket, changeset: new_changeset, form: to_form(new_changeset, as: :post))}
    else
      {:noreply, socket}
    end
  end

  # ✅ Remove tags
  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    changeset = socket.assigns.changeset
    current_tags = get_field(changeset, :tags, [])
    new_changeset = put_change(changeset, :tags, List.delete(current_tags, tag))

    {:noreply, assign(socket, changeset: new_changeset, form: to_form(new_changeset, as: :post))}
  end

  # Save the post (handles upload)
  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    current_user = socket.assigns.current_user

    # Debug: Check if there are any entries
    IO.inspect(socket.assigns.uploads.media.entries, label: "Upload entries")

    # Process uploaded files (if any)
    IO.inspect("About to consume uploaded entries", label: "Debug")
    uploaded_files =
      try do
        consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
          IO.inspect(path, label: "Temp file path")
          IO.inspect(entry.client_name, label: "Original filename")

          # Save file permanently to /priv/static/uploads/
          dest = Path.join(["priv/static/uploads", Path.basename(path)])
          IO.inspect(dest, label: "Destination path")

          case File.cp(path, dest) do
            :ok -> IO.inspect("File copied successfully")
            {:error, reason} -> IO.inspect(reason, label: "File copy error")
          end

        # Determine type
        type =
          cond do
            String.starts_with?(entry.client_type, "image/") -> "image"
            String.starts_with?(entry.client_type, "video/") -> "video"
            true -> nil
          end

        result = %{"url" => "/uploads/#{Path.basename(dest)}", "type" => type}
        IO.inspect(result, label: "File result")
        {:ok, result}
      end)
      rescue
        e ->
          IO.inspect(e, label: "Error consuming uploads")
          []
      end

    IO.inspect(uploaded_files, label: "Consumed files")

    # Add upload details (if present)
    post_params =
      if uploaded_files != [] do
        IO.inspect("Adding media_files to post_params", label: "Upload status")
        Map.put(post_params, "media_files", uploaded_files)
      else
        IO.inspect("No uploaded files found", label: "Upload status")
        post_params
      end

    IO.inspect(post_params, label: "Final post_params")

    # Save the post
    IO.inspect("About to create post", label: "Debug")
    case Posts.create_post(current_user, post_params) do
      {:ok, post} ->
        IO.inspect(post, label: "Post created successfully")
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully!")
         |> push_navigate(to: ~p"/feed")}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset.errors, label: "Post creation errors")
        {:noreply, assign(socket, form: to_form(changeset, as: :post))}
    end
  end
  @impl true
def handle_event("cancel-upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :media, ref)}
end


def error_to_string(:too_large), do: "Too large"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
