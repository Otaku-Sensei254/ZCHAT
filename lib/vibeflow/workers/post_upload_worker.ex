defmodule Vibeflow.Workers.PostUploadWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Vibeflow.Infrastructure.UploadCloudinary
  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post
  alias Vibeflow.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id, "files" => files}}) do
    post = Repo.get!(Post, post_id)

    uploaded_media =
      Enum.reduce_while(files, [], fn file, acc ->
        case UploadCloudinary.upload_file(
               file["path"],
               upload_kind_for(file),
               filename: file["client_name"],
               content_type: file["client_type"]
             ) do
          {:ok, result} ->
            {:cont, acc ++ [%{"url" => result.url, "type" => result.resource_type}]}

          {:error, reason} ->
            Logger.error("PostUploadWorker upload failed for post #{post_id}: #{inspect(reason)}")
            {:halt, {:error, reason}}
        end
      end)

    case uploaded_media do
      media when is_list(media) and media != [] ->
        result = Posts.publish_post(post, media)
        cleanup_temp_files(files)
        result

      {:error, reason} ->
        Posts.fail_post(post, reason)
        {:error, reason}

      [] ->
        Posts.fail_post(post, "All media uploads failed")
        {:error, "All media uploads failed"}
    end
  end

  defp upload_kind_for(%{"client_type" => client_type}) do
    cond do
      String.starts_with?(client_type, "image/") -> :image
      String.starts_with?(client_type, "video/") -> :video
      String.starts_with?(client_type, "audio/") -> :audio
      true -> :auto
    end
  end

  defp upload_kind_for(_), do: :auto

  defp cleanup_temp_files(files) do
    Enum.each(files, fn %{"path" => path} ->
      try do
        File.rm(path)
      rescue
        _ -> :ok
      end
    end)
  end
end
