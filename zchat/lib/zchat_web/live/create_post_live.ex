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
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webp),
       max_entries: 5, # Limit to 5 files to prevent timeouts
       max_file_size: 10_000_000,
       auto_upload: false
     )}
  end

  # Validate form inputs
  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.changeset
      |> cast(post_params, [:title, :content, :category, :tags])
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       changeset: changeset,
       form: to_form(changeset, as: :post)
     )}
  end

  # Add tags dynamically
  @impl true
  def handle_event("add_tag", params, socket) do
    # Get tag from button click OR enter key input
    tag = params["tag"] || params["value"] || ""
    tag = String.trim(tag)

    if tag != "" do
      changeset = socket.assigns.changeset
      current_tags = Ecto.Changeset.get_field(changeset, :tags, [])

      # Avoid duplicates
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

  # Remove tags
  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    changeset = socket.assigns.changeset
    current_tags = get_field(changeset, :tags, [])
    new_changeset = put_change(changeset, :tags, List.delete(current_tags, tag))

    {:noreply, assign(socket, changeset: new_changeset, form: to_form(new_changeset, as: :post))}
  end

  # Save the post (Handles Cloudinary upload via Context)
  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    current_user = socket.assigns.current_user

    # 1. Consume uploads to get the temp file paths.
    # We do NOT upload to Cloudinary here. We just pass the paths to the Context.
    file_paths =
      consume_uploaded_entries(socket, :media, fn %{path: path}, _entry ->
        {:ok, path}
      end)

    # 2. Add the list of paths to the params
    # The Posts.create_post function will take this list, upload them,
    # and format them correctly for the database.
    post_params =
      if file_paths != [] do
        Map.put(post_params, "media_files", file_paths)
      else
        post_params
      end

    # 3. Create the post
    case Posts.create_post(current_user, post_params) do
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
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
