defmodule Vibeflow.Music.Itunes do
  @itunes_search_url "https://itunes.apple.com/search"



  def search(query) do
    params = [
      term: query,
      media: "music",
      limit: 20
    ]


    case Req.get(@itunes_search_url, params: params) do
      {:ok, %{status: 200, body: body}} ->
        #fetch the results as a map instead of raw output from itunes
        # now we decode the body....for a cool display
        data =
          case body do
            %{} -> body
            binary when is_binary(binary) -> Jason.decode!(binary)
            _ -> %{"results" => []}
          end

          results =
            data
            |> Map.get("results", [])
            |> Enum.map(&format_track/1)
            |> Enum.filter(fn track -> track.preview_url != nil end)

          {:ok, results}

          {"error", _reason} ->
            {:error, "Failed to fetch iTunes music"}
    end
  end

  defp format_track(track) do
    %{
      id: track["trackId"],
      title: track["trackName"],
      artist: track["artistName"],
      # The API returns .m4a files which play natively in all modern browsers
      preview_url: track["previewUrl"],
      # Get a higher resolution image (iTunes defaults to 100x100)
      cover_art: String.replace(track["artworkUrl100"], "100x100", "600x600"),
      duration: 30 # It's always ~30 seconds for previews
    }
  end
end
