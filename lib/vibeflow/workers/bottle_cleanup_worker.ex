defmodule Vibeflow.Workers.BottleCleanupWorker do
  @moduledoc """
  Oban worker to clean up expired bottle conversations every hour.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Vibeflow.Chat.BottleService

  @impl Oban.Worker
  def perform(_job) do
    BottleService.delete_expired_bottle_conversations()
  end
end
