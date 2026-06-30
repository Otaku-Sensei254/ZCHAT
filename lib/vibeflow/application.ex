defmodule Vibeflow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    require Logger

    mailer_cfg = Application.get_env(:vibeflow, Vibeflow.Mailer, [])
    adapter = Keyword.get(mailer_cfg, :adapter)
    api_key_present? =
      case Keyword.get(mailer_cfg, :api_key) do
        nil -> false
        "" -> false
        _ -> true
      end

    Logger.info("Mailer adapter=#{inspect(adapter)} brevo_api_key_present?=#{api_key_present?}")

    children = [
      # Start the Telemetry supervisor
      VibeflowWeb.Telemetry,
      # Start the Ecto repository
      Vibeflow.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Vibeflow.PubSub},
      VibeflowWeb.Presence,
      # Start Finch
      {Finch, name: Vibeflow.Finch},
      # Start Oban
      {Oban, Application.fetch_env!(:vibeflow, Oban)},
      # Track in-progress uploads for background upload flow
      Vibeflow.UploadTracker,
      # Start the Endpoint (http/https)
      VibeflowWeb.Endpoint

      # Start a worker by calling: Vibeflow.Worker.start_link(arg)
      # {Vibeflow.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Vibeflow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VibeflowWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
