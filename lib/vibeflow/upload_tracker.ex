defmodule Vibeflow.UploadTracker do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register(upload_id, name, type, size) do
    GenServer.call(__MODULE__, {:register, upload_id, name, type, size})
  end

  def complete(upload_id, path) do
    GenServer.call(__MODULE__, {:complete, upload_id, path})
  end

  def associate(upload_ids, post_id) when is_list(upload_ids) do
    GenServer.call(__MODULE__, {:associate, upload_ids, post_id})
  end

  def get(upload_id) do
    GenServer.call(__MODULE__, {:get, upload_id})
  end

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_call({:register, id, name, type, size}, _from, state) do
    {:reply, :ok,
     Map.put(state, id, %{
       status: :pending,
       client_name: name,
       client_type: type,
       client_size: size,
       path: nil,
       post_id: nil,
       finalized: false
     })}
  end

  def handle_call({:complete, id, path}, _from, state) do
    case Map.get(state, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      entry ->
        updated = %{entry | status: :complete, path: path}
        new_state = Map.put(state, id, updated)
        finalized_state = maybe_finalize(updated.post_id, new_state)
        {:reply, {:ok, updated.post_id}, finalized_state}
    end
  end

  def handle_call({:associate, ids, post_id}, _from, state) do
    new_state =
      Enum.reduce(ids, state, fn id, acc ->
        case Map.get(acc, id) do
          nil -> acc
          entry -> Map.put(acc, id, %{entry | post_id: post_id})
        end
      end)

    finalized_state =
      Enum.reduce(ids, new_state, fn id, acc ->
        entry = Map.get(acc, id)
        if entry && entry.status == :complete do
          maybe_finalize(post_id, acc)
        else
          acc
        end
      end)

    {:reply, :ok, finalized_state}
  end

  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state, id), state}
  end

  defp maybe_finalize(nil, state), do: state

  defp maybe_finalize(post_id, state) do
    entries = Map.filter(state, fn {_id, e} -> e.post_id == post_id end)

    all_complete? =
      map_size(entries) > 0 and
        Enum.all?(entries, fn {_id, e} -> e.status == :complete end)

    already_finalized? =
      Enum.any?(entries, fn {_id, e} -> Map.get(e, :finalized, false) end)

    if all_complete? and not already_finalized? do
      Logger.info("All uploads complete for post #{post_id}, enqueuing upload job")

      files =
        Enum.map(entries, fn {_id, e} ->
          %{
            "path" => e.path,
            "client_name" => e.client_name,
            "client_type" => e.client_type
          }
        end)

      %{post_id: post_id, files: files}
      |> Vibeflow.Workers.PostUploadWorker.new()
      |> Oban.insert()

      Enum.reduce(entries, state, fn {id, e}, acc ->
        Map.put(acc, id, %{e | finalized: true})
      end)
    else
      state
    end
  end
end
