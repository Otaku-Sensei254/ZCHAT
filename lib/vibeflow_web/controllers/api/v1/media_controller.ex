defmodule VibeflowWeb.Api.V1.MediaController do
  use VibeflowWeb, :controller

  alias Vibeflow.Infrastructure.UploadCloudinary

  @upload_dir "/tmp/vibeflow/uploads"

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
    dest = Path.join(@upload_dir, "#{upload_id}#{ext}")
    File.mkdir_p!(@upload_dir)

    {:ok, binary, conn} =
      Plug.Conn.read_body(conn, length: 100_000_000, read_length: 1_000_000)

    File.write!(dest, binary)

    kind =
      cond do
        String.starts_with?(content_type, "image/") -> :image
        String.starts_with?(content_type, "video/") -> :video
        true -> :auto
      end

    case UploadCloudinary.upload_file(dest, kind,
           filename: Path.basename(dest),
           content_type: content_type
         ) do
      {:ok, result} ->
        json(conn, %{data: %{url: result.url, resource_type: result.resource_type}})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Upload failed: #{inspect(reason)}"})
    end
  end
end
