defmodule Zchat.Infrastructure.UploadCloudinary do
  @moduledoc """
  Handles uploading media (images/video) to Cloudinary via the "Auto" endpoint.
  """
  require Logger

  # 1. We take the temporary file path from the LiveView upload
  def upload_file(file_path) do
    # Get config (defined in config.exs)
    cloud_name = config()[:cloud_name]
    upload_preset = config()[:upload_preset]

    Logger.info("Uploading to Cloudinary with cloud_name: #{cloud_name}, upload_preset: #{upload_preset}")

    # 2. Use the "auto" endpoint so Cloudinary detects if it's video or image
    url = "https://api.cloudinary.com/v1_1/#{cloud_name}/auto/upload"

    # 3. Construct the multipart body
    body = {:multipart, [
      {:file, file_path},
      {"upload_preset", upload_preset}
    ]}

    # Increase timeout to 30s because videos take longer to upload
    options = [recv_timeout: 30_000]

    # 4. Send the request
    case HTTPoison.post(url, body, [], options) do
      {:ok, %{status_code: 200, body: response_body}} ->
        json = Jason.decode!(response_body)

        # Return the URL and the type (e.g., "image" or "video")
        {:ok, %{
          url: json["secure_url"],
          resource_type: json["resource_type"]
        }}

      {:ok, %{body: error_body}} ->
        Logger.error("Cloudinary upload error: #{inspect(error_body)}")
        {:error, "Cloudinary Error: #{inspect(error_body)}"}

      {:error, reason} ->
        Logger.error("HTTPoison network error: #{inspect(reason)}")
        {:error, "Network Error: #{inspect(reason)}"}
    end
  end

  defp config do
    %{
      cloud_name: Application.get_env(:cloudex, :cloud_name) || "dahpsrzjh",
      upload_preset: Application.get_env(:cloudex, :upload_preset) || "default"
    }
  end
end
