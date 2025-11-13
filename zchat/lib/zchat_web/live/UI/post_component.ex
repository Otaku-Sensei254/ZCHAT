defmodule ZchatWeb.UI.PostComponent do
  use ZchatWeb, :live_component
  alias Zchat.Posts
  alias Zchat.Posts.{Like, Comment}
  alias Zchat.Repo
  import Ecto.Query
  import Phoenix.HTML.Form


  @default_avatar "/images/default-avatar.png"
  @comments_per_page 5

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       show_comments: false,
       comments: [],
       comment_page: 1,
       has_more_comments: false,
       current_like: nil,
       like_count: 0,
       comment_count: 0,
       replying_to: nil,
       replying_to_user: nil,
       comment_form: to_form(%{"content" => ""}, as: :comment)
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:current_like, fn ->
        if assigns[:current_user] do
          Repo.one(
            from l in Like,
            where: l.user_id == ^assigns.current_user.id and l.post_id == ^assigns.post.id
          )
        end
      end)
      |> assign_new(:like_count, fn ->
        Repo.aggregate(
          from(l in Like, where: l.post_id == ^assigns.post.id),
          :count
        )
      end)
      |> assign_new(:comment_count, fn ->
        Repo.aggregate(
          from(c in Comment, where: c.post_id == ^assigns.post.id),
          :count
        )
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_comments", _, socket) do
    if socket.assigns.show_comments do
      {:noreply, assign(socket, show_comments: false)}
    else
      load_comments(socket, 1)
    end
  end

  def handle_event("load_more_comments", _, socket) do
    load_comments(socket, socket.assigns.comment_page + 1)
  end

  def handle_event("add_comment", %{"comment" => %{"content" => content, "post_id" => post_id, "parent_id" => parent_id}}, socket) do
    if String.trim(content) == "" do
      {:noreply, socket}
    else
      case Posts.create_comment(%{
             content: content,
             post_id: post_id,
             user_id: socket.assigns.current_user.id,
             parent_id: if(parent_id == "", do: nil, else: parent_id)
           }) do
        {:ok, comment} ->
          ZchatWeb.Endpoint.broadcast!("post:#{post_id}", "new_comment", %{
            comment: %{
              id: comment.id,
              content: comment.content,
              inserted_at: comment.inserted_at,
              user: %{
                id: socket.assigns.current_user.id,
                username: socket.assigns.current_user.username,
                avatar_url: socket.assigns.current_user.avatar_url
              },
              likes_count: 0,
              parent_id: comment.parent_id
            }
          })

          {:noreply,
           socket
           |> assign(comment_form: to_form(%{"content" => "", "post_id" => post_id, "parent_id" => ""}, as: :comment))
           |> assign(replying_to: nil, replying_to_user: nil)
           |> update_comment_count(1)
          }

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to add comment")}
      end
    end
  end

  def handle_event("reply_to_comment", %{"comment-id" => comment_id, "username" => username}, socket) do
    {:noreply,
     socket
     |> assign(replying_to: comment_id, replying_to_user: %{username: username})
     |> push_event("focus_comment_input", %{})}
  end

  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, replying_to: nil, replying_to_user: nil)}
  end

  def handle_event("toggle_like", %{"post-id" => post_id}, socket) do
    if socket.assigns.current_like do
      Repo.delete(socket.assigns.current_like)
      ZchatWeb.Endpoint.broadcast!("post:#{post_id}", "post_unliked", %{post_id: post_id, user_id: socket.assigns.current_user.id})

      {:noreply,
       socket
       |> assign(current_like: nil)
       |> update_like_count(-1)
      }
    else
      case Posts.create_like(%{
             post_id: post_id,
             user_id: socket.assigns.current_user.id
           }) do
        {:ok, like} ->
          ZchatWeb.Endpoint.broadcast!("post:#{post_id}", "post_liked", %{
            post_id: post_id,
            like: %{
              id: like.id,
              user_id: like.user_id,
              post_id: like.post_id
            }
          })

          {:noreply,
           socket
           |> assign(current_like: like)
           |> update_like_count(1)
          }

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to like post")}
      end
    end
  end

  # FIX: Added '_' to 'comment_id' to silence unused variable warning
  def handle_event("toggle_like_comment", %{"comment-id" => _comment_id}, socket) do
    # Implementation for comment likes would go here
    {:noreply, socket}
  end

  def handle_info(%{event: "new_comment", payload: %{comment: comment}}, socket) do
    if comment.parent_id do
      {:noreply,
       socket
       # FIX: Explicitly call Phoenix.Component.update
       |> Phoenix.Component.update(:comments, &[comment | &1])
       |> update_comment_count(1)}
    else
      {:noreply,
       socket
       |> Phoenix.Component.update(:comments, &[comment | &1])
       |> update_comment_count(1)}
    end
  end

  def handle_info(%{event: "post_liked", payload: %{like: like}}, socket) do
    if like.post_id == socket.assigns.post.id && like.user_id != socket.assigns.current_user.id do
      {:noreply, update_like_count(socket, 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "post_unliked", payload: %{post_id: post_id, user_id: user_id}}, socket) do
    if post_id == socket.assigns.post.id && user_id != socket.assigns.current_user.id do
      {:noreply, update_like_count(socket, -1)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp load_comments(socket, page) do
    comments = Posts.list_comments(
      post_id: socket.assigns.post.id,
      page: page,
      per_page: @comments_per_page,
      preload: [:user, :likes]
    )

    has_more = length(comments) == @comments_per_page

    socket =
      socket
      |> assign(show_comments: true)
      |> assign(comment_page: page)
      |> assign(has_more_comments: has_more)

    if page == 1 do
      {:noreply, assign(socket, comments: comments)}
    else
      # FIX: Explicitly call Phoenix.Component.update
      {:noreply, Phoenix.Component.update(socket, :comments, &(&1 ++ comments))}
    end
  end

  defp update_like_count(socket, delta) do
    # FIX: Explicitly call Phoenix.Component.update
    Phoenix.Component.update(socket, :like_count, &(&1 + delta))
  end

  defp update_comment_count(socket, delta) do
    # FIX: Explicitly call Phoenix.Component.update
    Phoenix.Component.update(socket, :comment_count, &(&1 + delta))
  end


end
