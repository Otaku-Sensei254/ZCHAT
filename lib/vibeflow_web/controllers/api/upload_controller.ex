defmodule VibeflowWeb.Api.UploadController do
  use VibeflowWeb, :controller

  alias Vibeflow.UploadTracker

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
end
