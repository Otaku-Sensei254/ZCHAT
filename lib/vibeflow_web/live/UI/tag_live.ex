defmodule VibeflowWeb.UI.TagLive do
  use VibeflowWeb, :live_view
  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post

  @impl true
  def mount(%{"tag" => tag}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "posts")
    end

    socket =
      socket
      |> stream_configure(:posts, dom_id: &"post-#{&1.uuid}")
      # Initialize empty stream
      |> stream(:posts, [], reset: true)
      |> assign(:tag, tag)
      |> assign(:similar_tags, [])
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:loading, false)
      |> assign(:has_more, true)
      # Show exact matches first by default
      |> assign(:show_similar_first, false)

    {:ok, socket |> load_posts()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  defp apply_action(socket, :show, %{"tag" => tag}) do
    socket
    |> assign(:page_title, "##{tag}")
    |> assign(:tag, tag)
  end

  defp apply_action(socket, _, _), do: socket

  @impl true
  def handle_event("load_more", _params, socket) do
    {:noreply, socket |> load_more_posts()}
  end

  @impl true
  def handle_event("toggle_similar", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_similar_first, !socket.assigns.show_similar_first)
     |> load_posts()}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}

  # --- CORE HELPERS ---

  defp load_posts(socket) do
    %{tag: tag, page: page, per_page: per_page} = socket.assigns

    # Get similar tags for smart matching
    similar_tags = find_similar_tags(tag)

    # Get posts with exact tag match
    exact_posts = Posts.list_posts_by_tag(tag, page: page, per_page: per_page)

    # Get posts with similar tags if enabled
    similar_posts =
      if socket.assigns.show_similar_first and similar_tags != [] do
        remaining = per_page - length(exact_posts)

        if remaining > 0 do
          Posts.list_posts_by_tags(similar_tags, page: 1, per_page: remaining, exclude_tag: tag)
        else
          []
        end
      else
        []
      end

    # Combine posts: similar first (if enabled), then exact matches
    all_posts =
      if socket.assigns.show_similar_first do
        similar_posts ++ exact_posts
      else
        exact_posts
      end

    has_more = length(all_posts) >= per_page

    socket
    |> assign(:similar_tags, similar_tags)
    |> assign(:has_more, has_more)
    |> assign(:loading, false)
    |> stream(:posts, all_posts, reset: page == 1)
  end

  defp load_more_posts(socket) do
    %{tag: tag, page: page, per_page: per_page} = socket.assigns

    new_page = page + 1
    similar_tags = socket.assigns.similar_tags

    # Load more posts
    exact_posts = Posts.list_posts_by_tag(tag, page: new_page, per_page: per_page)

    similar_posts =
      if socket.assigns.show_similar_first and similar_tags != [] do
        Posts.list_posts_by_tags(similar_tags,
          page: new_page,
          per_page: per_page,
          exclude_tag: tag
        )
      else
        []
      end

    all_posts =
      if socket.assigns.show_similar_first do
        similar_posts ++ exact_posts
      else
        exact_posts
      end

    has_more = length(all_posts) >= per_page

    socket
    |> assign(:page, new_page)
    |> assign(:has_more, has_more)
    |> assign(:loading, false)
    |> stream(:posts, all_posts)
  end

  # --- TAG SIMILARITY LOGIC ---

  defp find_similar_tags(tag) do
    # Normalize the tag for comparison
    normalized_tag = normalize_tag(tag)

    # Get all unique tags from the database
    all_tags = Posts.list_all_tags()

    # Find similar tags
    all_tags
    |> Enum.reject(&(&1 == tag))
    |> Enum.map(fn other_tag ->
      similarity = calculate_tag_similarity(normalized_tag, normalize_tag(other_tag))
      {other_tag, similarity}
    end)
    |> Enum.filter(fn {_tag, similarity} -> similarity >= 0.6 end)
    |> Enum.sort_by(fn {_tag, similarity} -> -similarity end)
    |> Enum.take(5)
    |> Enum.map(fn {tag, _similarity} -> tag end)
  end

  defp normalize_tag(tag) do
    tag
    |> String.downcase()
    |> String.replace("-", "")
    |> String.replace("_", "")
    |> String.replace(" ", "")
  end

  defp calculate_tag_similarity(tag1, tag2) do
    # Simple similarity based on common substrings
    if tag1 == tag2 do
      1.0
    else
      # Check if one contains the other
      cond do
        String.contains?(tag1, tag2) or String.contains?(tag2, tag1) ->
          0.8

        true ->
          # Calculate Levenshtein distance similarity
          distance = levenshtein_distance(tag1, tag2)
          max_len = max(String.length(tag1), String.length(tag2))

          if max_len > 0 do
            1.0 - distance / max_len
          else
            0.0
          end
      end
    end
  end

  # Simple Levenshtein distance implementation
  defp levenshtein_distance(s, t) when is_binary(s) and is_binary(t) do
    s_chars = String.to_charlist(s)
    t_chars = String.to_charlist(t)

    levenshtein_distance(s_chars, t_chars)
  end

  defp levenshtein_distance(s, t) when is_list(s) and is_list(t) do
    {s_len, t_len} = {length(s), length(t)}

    # Initialize matrix
    matrix = for(i <- 0..s_len, do: for(j <- 0..t_len, do: 0))

    # Fill first row and column
    matrix =
      matrix
      |> List.replace_at(0, Enum.to_list(0..t_len))
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        List.replace_at(row, 0, i)
      end)

    # Fill rest of matrix
    for i <- 1..s_len, j <- 1..t_len do
      cost = if(Enum.at(s, i - 1) == Enum.at(t, j - 1), do: 0, else: 1)

      deletion = Enum.at(Enum.at(matrix, i - 1), j) + 1
      insertion = Enum.at(Enum.at(matrix, i), j - 1) + 1
      substitution = Enum.at(Enum.at(matrix, i - 1), j - 1) + cost

      min_cost = min(deletion, min(insertion, substitution))

      matrix =
        matrix
        |> List.replace_at(
          i,
          List.replace_at(Enum.at(matrix, i), j, min_cost)
        )
    end

    # Get final distance
    Enum.at(Enum.at(matrix, s_len), t_len)
  end
end
