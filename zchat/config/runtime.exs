import Config

# 1. FORCE SERVER TO START
config :zchat, ZchatWeb.Endpoint, server: true

if config_env() == :prod do
  # --- Database ---
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is missing."

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :zchat, Zchat.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # --- Endpoint ---
  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "8080")
  secret_key_base = System.get_env("SECRET_KEY_BASE") || raise "SECRET_KEY_BASE missing"

  config :zchat, ZchatWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # 2. FORCE IPv4 (4 zeros)
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # --- Cloudinary ---
  config :cloudex,
    api_key: System.fetch_env!("CLOUDINARY_API_KEY"),
    api_secret: System.fetch_env!("CLOUDINARY_SECRET"),
    cloud_name: System.fetch_env!("CLOUDINARY_CLOUD_NAME"),
    upload_preset: System.fetch_env!("CLOUDINARY_PRESET")
end
