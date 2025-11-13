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
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )}
  end

  # ✅ Validate form inputs
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

  # ✅ Save the post (handles upload)
  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    current_user = socket.assigns.current_user

    # Process uploaded file (if any)
    uploaded_file =
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        # Save file permanently to /priv/static/uploads/
        dest = Path.join(["priv/static/uploads", Path.basename(path)])
        File.cp!(path, dest)

        # Determine type
        type =
          cond do
            String.starts_with?(entry.client_type, "image/") -> "image"
            String.starts_with?(entry.client_type, "video/") -> "video"
            true -> nil
          end

        {:ok, %{url: "/uploads/#{Path.basename(dest)}", type: type}}
      end)
      |> List.first()

    # Add upload details (if present)
    post_params =
      if uploaded_file do
        post_params
        |> Map.put("media_url", uploaded_file.url)
        |> Map.put("media_type", uploaded_file.type)
      else
        post_params
      end

    # Save the post
    case Posts.create_post(current_user, post_params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully!")
         |> push_navigate(to: ~p"/feed")}

      {:error, %Ecto.Changeset{} = changeset} ->
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
