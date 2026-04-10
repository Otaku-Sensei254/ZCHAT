defmodule Vibeflow.Uploads.LocalUploader do
  def put_file(%{path: temp_path, filename: filename}) do
    ext = Path.extname(filename)
    unique_name = "#{System.system_time(:second)}-#{Path.basename(filename, ext)}#{ext}"

    destination_path = Path.join([File.cwd!(), "priv/static/uploads/waves", unique_name])
    File.mkdir_p!(Path.dirname(destination_path))

    case File.cp(temp_path, destination_path) do
      :ok ->
        {:ok, "/uploads/waves/#{unique_name}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
