defmodule Zchat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ZchatWeb.Telemetry,
      # Start the Ecto repository
      Zchat.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Zchat.PubSub},
      # Start Finch
      {Finch, name: Zchat.Finch},
      # Start the Endpoint (http/https)
      ZchatWeb.Endpoint
      # Start a worker by calling: Zchat.Worker.start_link(arg)
      # {Zchat.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Zchat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ZchatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
