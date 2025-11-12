defmodule ZchatWeb.UI.SinglePostLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    post = Posts.get_post!(id)
    {:noreply, assign(socket, :post, post)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <article class="bg-white shadow-md rounded-lg p-6">
        <h1 class="text-3xl font-bold text-gray-900 mb-4"><%= @post.title %></h1>

        <%= if @post.media_url do %>
          <div class="my-6">
            <%= cond do %>
              <% @post.media_type == "image" -> %>
                <img src={@post.media_url} alt="Post media" class="max-h-96 w-auto rounded-lg" />
              <% @post.media_type == "video" -> %>
                <video src={@post.media_url} controls class="max-h-96 w-auto rounded-lg">
                  Your browser does not support the video tag.
                </video>
              <% true -> %>
                <!-- Fallback for unknown media types -->
                <a href={@post.media_url} class="text-blue-600 hover:underline" target="_blank">View attached media</a>
            <% end %>
          </div>
        <% end %>

        <div class="prose max-w-none mt-6">
          <%= if Code.ensure_loaded?(Earmark) do %>
            <%= raw(Earmark.as_html!(@post.content)) %>
          <% else %>
            <p class="whitespace-pre-line"><%= @post.content %></p>
          <% end %>
        </div>

        <%= if @post.tags && @post.tags != [] do %>
          <div class="mt-6 pt-4 border-t border-gray-200">
            <div class="flex flex-wrap gap-2">
              <%= for tag <- @post.tags do %>
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-orange-100 text-orange-800">
                  #<%= tag %>
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="mt-8 pt-4 border-t border-gray-200 text-sm text-gray-500">
          Posted by <%= @post.user.username %> on <%= Calendar.strftime(@post.inserted_at, "%B %d, %Y") %>
        </div>
      </article>
    </div>
    """
  end
end
