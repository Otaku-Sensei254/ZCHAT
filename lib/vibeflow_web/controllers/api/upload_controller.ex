defmodule VibeflowWeb.Api.UploadController do
  use VibeflowWeb, :controller

  alias Vibeflow.UploadTracker
  alias Vibeflow.Infrastructure.UploadCloudinary

  @upload_dir "/tmp/vibeflow/uploads"

  def init(conn, params) do
    upload_id = params["upload_id"] || Ecto.UUID.generate()
    name = params["name"] || "file"
    type = params["type"] || "application/octet-stream"
    size =
      case params["size"] do
        val when is_integer(val) -> val
        val when is_binary(val) -> String.to_integer(val)
        _ -> 0
      end

    File.mkdir_p!(@upload_dir)
    UploadTracker.register(upload_id, name, type, size)

    json(conn, %{upload_id: upload_id})
  end

  def upload(conn, %{"upload_id" => upload_id}) do
    content_type = List.first(get_req_header(conn, "content-type")) || "application/octet-stream"

    ext =
      case content_type do
        "image/jpeg" -> ".jpg"
        "image/png" -> ".png"
        "image/gif" -> ".gif"
        "image/webp" -> ".webp"
        "video/mp4" -> ".mp4"
        "video/quicktime" -> ".mov"
        "video/webm" -> ".webm"
        _ -> ".bin"
      end

    dest = Path.join(@upload_dir, "#{upload_id}#{ext}")

    {:ok, binary, conn} =
      Plug.Conn.read_body(conn, length: 100_000_000, read_length: 1_000_000)

    File.write!(dest, binary)

    UploadTracker.complete(upload_id, dest)

    json(conn, %{status: "ok"})
  end

  def upload_media(conn, params) do
    # Accept multipart upload, save to temp file, upload to R2, return URL
    content_type = params["content_type"] || List.first(get_req_header(conn, "content-type")) || "image/jpeg"

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

    # Read raw body
    {:ok, binary, conn} =
      Plug.Conn.read_body(conn, length: 100_000_000, read_length: 1_000_000)

    File.write!(dest, binary)

    # Upload to R2
    kind =
      cond do
        String.starts_with?(content_type, "image/") -> :image
        String.starts_with?(content_type, "video/") -> :video
        true -> :auto
      end

    case UploadCloudinary.upload_file(dest, kind, filename: Path.basename(dest), content_type: content_type) do
      {:ok, result} ->
        json(conn, %{data: %{url: result.url, resource_type: result.resource_type}})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Upload failed: #{inspect(reason)}"})
    end
  end
end
