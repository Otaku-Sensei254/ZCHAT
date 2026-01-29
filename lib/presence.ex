defmodule ZchatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :zchat,
    pubsub_server: Zchat.PubSub
end
