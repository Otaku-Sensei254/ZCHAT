defmodule VibeflowWeb.CreatePostLive do
  use VibeflowWeb, :live_view

  import VibeflowWeb.CoreComponents
  require Logger

  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post
  alias Vibeflow.UploadTracker

  @impl true
  def mount(_params, _session, socket) do
    changeset = Posts.change_post(%Post{})
    form = to_form(changeset, as: :post)

    {:ok,
     socket
     |> assign(:page_title, "Create New Post")
     |> assign(:form, form)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    upload_ids = Map.get(post_params, "upload_ids", []) |> List.wrap()

    case Posts.create_draft_post(socket.assigns.current_user, post_params) do
      {:ok, post} ->
        flash_msg =
          if upload_ids != [] do
            UploadTracker.associate(upload_ids, post.id)
            "Your post is being processed! You'll be notified when it's live."
          else
            Posts.publish_post(post, [])
            "Post published successfully!"
          end

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> push_navigate(to: ~p"/feed")}

      {:error, changeset} ->
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
end
