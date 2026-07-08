defmodule VibeflowWeb.Api.V1.MediaController do
  use VibeflowWeb, :controller

  @upload_dir "priv/static/uploads"

  def upload(conn, params) do
    content_type =
      params["content_type"] || List.first(get_req_header(conn, "content-type")) || "image/jpeg"

    ext =
      case content_type do
        "image/jpeg" -> ".jpg"
        "image/png" -> ".png"
        "image/gif" -> ".gif"
        "image/webp" -> ".webp"
        "video/mp4" -> ".mp4"
        "video/quicktime" -> ".mov"
        "video/webm" -> ".webm"
        "video/x-matroska" -> ".mkv"
        _ -> ".bin"
      end

    upload_id = params["upload_id"] || Ecto.UUID.generate()
    filename = "#{upload_id}#{ext}"
    dest = Path.join(@upload_dir, filename)
    File.mkdir_p!(@upload_dir)

    {:ok, binary, conn} =
      Plug.Conn.read_body(conn, length: 100_000_000, read_length: 1_000_000)

    File.write!(dest, binary)

    url = "/uploads/#{filename}"
    resource_type = if String.starts_with?(content_type, "video/"), do: "video", else: "image"

    json(conn, %{data: %{url: url, resource_type: resource_type}})
  end
end
