# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :vibeflow,
  ecto_repos: [Vibeflow.Repo]

# Configures the endpoint
config :vibeflow, VibeflowWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: VibeflowWeb.ErrorHTML, json: VibeflowWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Vibeflow.PubSub,
  live_view: [signing_salt: "qoodR1tP"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :vibeflow, Vibeflow.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.4",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# CONFIG MIME TYPES FOR UPLOADED FILES
config :mime, :types, %{
  "audio/flac" => ["flac"],
  "audio/ogg" => ["ogg"],
  "audio/mp4" => ["m4a"],
  "audio/aac" => ["aac"],
  "audio/opus" => ["opus"],
  "audio/webm" => ["webm"],
  "video/webm" => ["webm"],
  "video/quicktime" => ["mov"],
  "video/x-msvideo" => ["avi"],
  "image/webp" => ["webp"]
}

config :mime, :extensions, %{
  "webm" => "video/webm"
}

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
# Neon Database Configuration
# yes yes yes

# Development/Production Configuration

#
