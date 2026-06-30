defmodule Vibeflow.Infrastructure.UploadCloudinary do
  @moduledoc """
  Uploads media to Cloudflare R2 using the S3-compatible API.

  The module name is kept for compatibility with existing callers.
  """

  require Logger

  @region "auto"
  @service "s3"
  @algorithm "AWS4-HMAC-SHA256"

  @audio_exts ~w(.mp3 .wav .ogg .flac .webm .m4a .aac .opus)
  @video_exts ~w(.mp4 .mov .mkv .webm .avi .m4v)
  @image_exts ~w(.jpg .jpeg .png .gif .webp .bmp .avif)

  def upload_file(file_path, upload_kind \\ :auto, opts \\ []) do
    with {:ok, config} <- storage_config(),
         {:ok, bytes} <- File.read(file_path) do
      filename = Keyword.get(opts, :filename)
      content_type_hint = Keyword.get(opts, :content_type)
      key = object_key(file_path, upload_kind, filename)
      content_type = content_type_for(file_path, upload_kind, filename, content_type_hint)
      resource_type = resource_type_for(file_path, upload_kind, filename, content_type_hint)

      Logger.info("Uploading media to Cloudflare R2: key=#{key}, type=#{resource_type}")

      case put_object(config, key, bytes, content_type) do
        {:ok, _response} ->
          {:ok,
           %{
             url: public_url(config, key),
             resource_type: resource_type
           }}

        {:error, reason} ->
          Logger.error("Cloudflare R2 upload error: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to read upload file #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp put_object(config, key, bytes, content_type) do
    endpoint = endpoint_url(config)
    url = "#{endpoint}/#{config.bucket}/#{key}"
    amz_date = amz_date()
    date_stamp = date_stamp(amz_date)
    payload_hash = sha256_hex(bytes)
    host = URI.parse(endpoint).host

    headers =
      signed_headers(
        config,
        host,
        key,
        content_type,
        payload_hash,
        amz_date,
        date_stamp
      )

    case Req.put(url,
           body: bytes,
           headers: headers,
           receive_timeout: 60_000,
           finch: Vibeflow.Finch,
           retry: false
         ) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp signed_headers(config, host, key, content_type, payload_hash, amz_date, date_stamp) do
    canonical_uri = "/#{config.bucket}/#{key}"
    canonical_headers = [
      {"content-type", content_type},
      {"host", host},
      {"x-amz-content-sha256", payload_hash},
      {"x-amz-date", amz_date}
    ]

    canonical_headers_string =
      canonical_headers
      |> Enum.sort_by(fn {name, _value} -> name end)
      |> Enum.map(fn {name, value} -> "#{name}:#{String.trim(value)}\n" end)
      |> Enum.join("")

    signed_headers =
      canonical_headers
      |> Enum.map(fn {name, _value} -> name end)
      |> Enum.sort()
      |> Enum.join(";")

    canonical_request = [
      "PUT",
      canonical_uri,
      "",
      canonical_headers_string,
      signed_headers,
      payload_hash
    ]
    |> Enum.join("\n")

    credential_scope = "#{date_stamp}/#{@region}/#{@service}/aws4_request"
    string_to_sign = [
      @algorithm,
      amz_date,
      credential_scope,
      sha256_hex(canonical_request)
    ]
    |> Enum.join("\n")

    signing_key = signing_key(config.secret_access_key, date_stamp)
    signature = hmac_hex(signing_key, string_to_sign)

    [
      {"content-type", content_type},
      {"host", host},
      {"x-amz-content-sha256", payload_hash},
      {"x-amz-date", amz_date},
      {"authorization",
       "#{@algorithm} Credential=#{config.access_key_id}/#{credential_scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"}
    ]
  end

  defp signing_key(secret_access_key, date_stamp) do
    k_date = hmac("AWS4" <> secret_access_key, date_stamp)
    k_region = hmac(k_date, @region)
    k_service = hmac(k_region, @service)
    hmac(k_service, "aws4_request")
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp hmac_hex(key, data), do: hmac(key, data) |> Base.encode16(case: :lower)
  defp sha256_hex(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  defp amz_date do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp date_stamp(amz_date), do: String.slice(amz_date, 0, 8)

  defp endpoint_url(config) do
    String.trim_trailing(config.endpoint, "/")
  end

  defp public_url(config, key) do
    base = String.trim_trailing(config.public_base_url, "/")
    "#{base}/#{key}"
  end

  defp object_key(file_path, upload_kind, filename \\ nil) do
    ext = effective_extension(file_path, filename)
    ext =
      case ext do
        "" -> default_extension(upload_kind)
        ".bin" -> default_extension(upload_kind)
        _ -> ext
      end

    prefix =
      case resource_type_for(file_path, upload_kind) do
        "audio" -> "audio"
        "video" -> "video"
        "image" -> "images"
        _ -> "media"
      end

    "#{prefix}/#{Ecto.UUID.generate()}#{ext}"
  end

  defp default_extension(:audio), do: ".mp3"
  defp default_extension(:video), do: ".mp4"
  defp default_extension(:image), do: ".jpg"
  defp default_extension(_), do: ".bin"

  defp resource_type_for(file_path, upload_kind, filename \\ nil, content_type_hint \\ nil) do
    ext = effective_extension(file_path, filename)
    content_type_hint = content_type_hint || ""

    cond do
      String.starts_with?(content_type_hint, "audio/") ->
        "audio"

      String.starts_with?(content_type_hint, "video/") ->
        "video"

      String.starts_with?(content_type_hint, "image/") ->
        "image"

      upload_kind in [:audio, :video, :image] ->
        Atom.to_string(upload_kind)

      ext in @audio_exts ->
        "audio"

      ext in @video_exts ->
        "video"

      ext in @image_exts ->
        "image"

      true ->
        "raw"
    end
  end

  defp content_type_for(file_path, upload_kind, filename \\ nil, content_type_hint \\ nil) do
    ext = effective_extension(file_path, filename)
    content_type_hint = content_type_hint || ""

    cond do
      String.starts_with?(content_type_hint, "audio/") -> content_type_hint
      String.starts_with?(content_type_hint, "video/") -> content_type_hint
      String.starts_with?(content_type_hint, "image/") -> content_type_hint
      true ->
        case {upload_kind, ext} do
          {:audio, ".mp3"} -> "audio/mpeg"
          {:audio, ".m4a"} -> "audio/mp4"
          {:audio, ".aac"} -> "audio/aac"
          {:audio, ".wav"} -> "audio/wav"
          {:audio, ".ogg"} -> "audio/ogg"
          {:audio, ".opus"} -> "audio/opus"
          {:audio, ".flac"} -> "audio/flac"
          {:audio, ".webm"} -> "audio/webm"
          {:audio, _} -> "audio/webm"
          {:video, ".mp4"} -> "video/mp4"
          {:video, ".mov"} -> "video/quicktime"
          {:video, ".webm"} -> "video/webm"
          {:video, ".mkv"} -> "video/x-matroska"
          {:video, ".avi"} -> "video/x-msvideo"
          {:video, ".m4v"} -> "video/x-m4v"
          {:image, ".png"} -> "image/png"
          {:image, ".gif"} -> "image/gif"
          {:image, ".webp"} -> "image/webp"
          {:image, ".bmp"} -> "image/bmp"
          {:image, ".avif"} -> "image/avif"
          {:image, _} -> "image/jpeg"
          {_, ".jpg"} -> "image/jpeg"
          {_, ".jpeg"} -> "image/jpeg"
          {_, ".png"} -> "image/png"
          {_, ".gif"} -> "image/gif"
          {_, ".webp"} -> "image/webp"
          {_, ".mp4"} -> "video/mp4"
          {_, ".mov"} -> "video/quicktime"
          {_, ".webm"} -> "video/webm"
          {_, ".wav"} -> "audio/wav"
          {_, ".ogg"} -> "audio/ogg"
          {_, ".flac"} -> "audio/flac"
          _ -> "application/octet-stream"
        end
    end
  end

  defp effective_extension(file_path, filename) do
    filename_ext =
      filename
      |> case do
        nil -> ""
        name -> Path.extname(String.downcase(name))
      end

    path_ext = Path.extname(file_path) |> String.downcase()

    cond do
      filename_ext not in ["", ".bin"] -> filename_ext
      path_ext not in ["", ".bin"] -> path_ext
      true -> ""
    end
  end

  defp storage_config do
    config = Application.get_env(:vibeflow, :cloudflare_r2, []) |> Enum.into(%{})

    access_key_id =
      config[:access_key_id] ||
        System.get_env("CLOUDFLARE_R2_ACCESS_KEY_ID")

    secret_access_key =
      config[:secret_access_key] ||
        System.get_env("CLOUDFLARE_R2_SECRET_ACCESS_KEY") ||
        System.get_env("CLOUDFLARE_R2_SECRET")

    account_id =
      config[:account_id] ||
        System.get_env("CLOUDFLARE_R2_ACCOUNT_ID")

    bucket =
      config[:bucket] ||
        System.get_env("CLOUDFLARE_R2_BUCKET")

    endpoint =
      config[:endpoint] ||
        if account_id, do: "https://#{account_id}.r2.cloudflarestorage.com", else: nil

    public_base_url =
      config[:public_base_url] ||
        System.get_env("CLOUDFLARE_R2_PUBLIC_BASE_URL")

    case {access_key_id, secret_access_key, account_id, bucket, endpoint, public_base_url} do
      {nil, _, _, _, _, _} -> {:error, "Missing CLOUDFLARE_R2_ACCESS_KEY_ID"}
      {_, nil, _, _, _, _} -> {:error, "Missing CLOUDFLARE_R2_SECRET_ACCESS_KEY"}
      {_, _, nil, _, _, _} -> {:error, "Missing CLOUDFLARE_R2_ACCOUNT_ID"}
      {_, _, _, nil, _, _} -> {:error, "Missing CLOUDFLARE_R2_BUCKET"}
      {_, _, _, _, nil, _} -> {:error, "Missing Cloudflare R2 endpoint"}
      {_, _, _, _, _, nil} -> {:error, "Missing CLOUDFLARE_R2_PUBLIC_BASE_URL"}
      _ ->
        {:ok,
         %{
           access_key_id: access_key_id,
           secret_access_key: secret_access_key,
           account_id: account_id,
           bucket: bucket,
           endpoint: endpoint,
           public_base_url: public_base_url
         }}
    end
  end
end
