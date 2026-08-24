defmodule VibeflowWeb.Api.V1.MediaController do
  use VibeflowWeb, :controller

  alias Vibeflow.Infrastructure.UploadCloudinary

  def upload(conn, params) do
    content_type =
      params["content_type"] || List.first(get_req_header(conn, "content-type")) || "image/jpeg"

    ext = extension_for(content_type)
    upload_id = params["upload_id"] || Ecto.UUID.generate()
    filename = "#{upload_id}#{ext}"
    temp_path = Path.join(System.tmp_dir!(), filename)

    {:ok, binary, conn} =
      Plug.Conn.read_body(conn, length: 100_000_000, read_length: 1_000_000)

    with :ok <- File.write(temp_path, binary),
         {:ok, media} <-
           UploadCloudinary.upload_file(
             temp_path,
             upload_kind_for(content_type),
             filename: filename,
             content_type: content_type
           ) do
      File.rm(temp_path)
      json(conn, %{data: %{url: media.url, resource_type: media.resource_type}})
    else
      {:error, reason} ->
        File.rm(temp_path)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Upload failed", reason: inspect(reason)})
    end
  end

  defp extension_for(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> case do
        "image/jpeg" -> ".jpg"
        "image/png" -> ".png"
        "image/gif" -> ".gif"
        "image/webp" -> ".webp"
        "video/mp4" -> ".mp4"
        "video/quicktime" -> ".mov"
        "video/webm" -> ".webm"
        "video/x-matroska" -> ".mkv"
        "audio/mpeg" -> ".mp3"
        "audio/mp3" -> ".mp3"
        "audio/mp4" -> ".m4a"
        "audio/aac" -> ".aac"
        "audio/wav" -> ".wav"
        "audio/ogg" -> ".ogg"
        "audio/opus" -> ".opus"
        "audio/flac" -> ".flac"
        "audio/webm" -> ".webm"
        _ -> ".bin"
      end
  end

  defp upload_kind_for(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> :image
      String.starts_with?(content_type, "video/") -> :video
      String.starts_with?(content_type, "audio/") -> :audio
      true -> :auto
    end
  end
end
