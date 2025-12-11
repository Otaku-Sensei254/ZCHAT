import Config

# config/runtime.exs

if config_env() == :prod do
  # --- 1. Database ---
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :zchat, Zchat.Repo,
    # ssl: [verify: :verify_none], # Disabled to match your database URL
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

 # --- 2. Endpoint (Web Server) ---
  config :zchat, ZchatWeb.Endpoint, server: true

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # Hardcoded secret from before (Keep this for now!)
  hardcoded_secret = "a+Very+Long+Random+String+That+Is+At+Least+64+Bytes+Long+For+Security+Purposes+Just+To+Get+It+Working+Now+123456"

  config :zchat, ZchatWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # CHANGE THIS: Use 4 zeros for IPv4
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: hardcoded_secret

  # --- 3. Cloudinary ---
  config :zchat, :cloudinary,
    api_key: System.get_env("CLOUDINARY_API_KEY"),
    api_secret: System.get_env("CLOUDINARY_SECRET"),
    cloud_name: System.get_env("CLOUDINARY_CLOUD_NAME"),
    upload_preset: System.get_env("CLOUDINARY_PRESET")
end
