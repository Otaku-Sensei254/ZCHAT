defmodule ZchatWeb.Admin.DashboardLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:stats, Posts.get_system_stats())
     |> assign(:categories, Posts.count_posts_by_category())
     |> assign(:tags, Posts.count_top_tags())}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-8">System Overview</h1>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <div class="text-sm font-medium text-gray-500">Total Users</div>
          <div class="mt-2 text-3xl font-bold text-gray-900"><%= @stats.total_users %></div>
        </div>
        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <div class="text-sm font-medium text-gray-500">Total Posts</div>
          <div class="mt-2 text-3xl font-bold text-blue-600"><%= @stats.total_posts %></div>
        </div>
        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <div class="text-sm font-medium text-gray-500">Total Comments</div>
          <div class="mt-2 text-3xl font-bold text-purple-600"><%= @stats.total_comments %></div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">

        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <h3 class="text-lg font-bold text-gray-900 mb-4 border-b border-gray-100 pb-2">
            Categories Performance
          </h3>
          <div class="space-y-4">
            <%= if @categories == [] do %>
              <p class="text-gray-500 text-sm">No stats available yet.</p>
            <% else %>
              <%= for {category, count} <- @categories do %>
                <div class="flex items-center justify-between group">
                  <span class="font-medium text-gray-700"><%= category %></span>
                  <div class="flex items-center gap-3">
                    <div class="h-2 w-24 bg-gray-100 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-blue-500 rounded-full"
                        style={"width: #{min(count * 10, 100)}%"}
                      ></div>
                    </div>
                    <span class="text-sm text-gray-500 w-12 text-right"><%= count %> posts</span>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <h3 class="text-lg font-bold text-gray-900 mb-4 border-b border-gray-100 pb-2">
            Trending Tags
          </h3>
          <div class="flex flex-wrap gap-3">
            <%= if @tags == [] do %>
              <p class="text-gray-500 text-sm">No tags used yet.</p>
            <% else %>
              <%= for {tag, count} <- @tags do %>
                <div class="flex items-center bg-gray-50 border border-gray-200 rounded-full px-3 py-1.5">
                  <span class="text-gray-600 font-medium text-sm">#<%= tag %></span>
                  <span class="ml-2 bg-blue-100 text-blue-700 text-xs font-bold px-2 py-0.5 rounded-full">
                    <%= count %>
                  </span>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

      </div>

      <div class="mt-8 flex justify-end">
        <.link navigate={~p"/feed"} class="text-blue-600 hover:underline text-sm font-medium">
          &larr; Back to Feed
        </.link>
      </div>
    </div>
    """
  end
end
