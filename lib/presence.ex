defmodule VibeflowWeb.Presence do
  use Phoenix.Presence,
    otp_app: :vibeflow,
    pubsub_server: Vibeflow.PubSub
end
