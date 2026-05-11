import Config

config :logger, level: :debug

if System.get_env("PHX_SERVER") do
  config :vibeflow, VibeflowWeb.Endpoint, server: true
end

if config_env() == :prod do
  # --- Database ---
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is missing."

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :vibeflow, Vibeflow.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: [verify: :verify_none],
    socket_options: maybe_ipv6

  # --- Endpoint ---
  host = System.get_env("PHX_HOST") || "vibeflow.gigalixirapp.com"
  port = String.to_integer(System.get_env("PORT") || "8080")
  secret_key_base = System.get_env("SECRET_KEY_BASE") || raise "SECRET_KEY_BASE missing"

config :vibeflow, VibeflowWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: ["https://#{host}", "https://vibeflow.gigalixirapp.com"],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    force_ssl: [rewrite_on: [:x_forwarded_proto]],
    secret_key_base: secret_key_base,
    server: true

  # --- Cloudflare R2 ---
  config :vibeflow, :cloudflare_r2,
    access_key_id: System.fetch_env!("CLOUDFLARE_R2_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("CLOUDFLARE_R2_SECRET_ACCESS_KEY"),
    account_id: System.fetch_env!("CLOUDFLARE_R2_ACCOUNT_ID"),
    bucket: System.fetch_env!("CLOUDFLARE_R2_BUCKET"),
    public_base_url: System.fetch_env!("CLOUDFLARE_R2_PUBLIC_BASE_URL")
end

# If we are in Dev mode but have a Cloud URL, use the Cloud!
if config_env() == :dev and System.get_env("DATABASE_URL") do
  config :vibeflow, Vibeflow.Repo,
    url: System.get_env("DATABASE_URL"),
    # Neon needs SSL, so we force it here
    ssl: [verify: :verify_none],
    pool_size: 10
end
