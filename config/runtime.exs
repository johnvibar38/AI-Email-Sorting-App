import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# Load .env file for development and test environments
if config_env() in [:dev, :test] and File.exists?(".env") do
  if Code.ensure_loaded?(Dotenvy) do
    Dotenvy.source!([".env", System.get_env()])

    # Development environment configuration
    if config_env() == :dev do
      config :jump, Jump.Repo,
        username: System.get_env("POSTGRES_USER"),
        password: System.get_env("POSTGRES_PASSWORD"),
        hostname: System.get_env("POSTGRES_HOST"),
        database: System.get_env("DATABASE")

      # Google OAuth credentials
      config :ueberauth, Ueberauth.Strategy.Google.OAuth,
        client_id: System.get_env("GOOGLE_CLIENT_ID"),
        client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

      # OpenAI API key
      config :openai,
        api_key: System.get_env("OPENAI_API_KEY")

      # Cloak encryption key
      config :jump, Jump.Vault,
        ciphers: [
          default: {
            Cloak.Ciphers.AES.GCM,
            tag: "AES.GCM.V1", key: Base.decode64!(System.get_env("CLOAK_KEY"))
          }
        ]
    end
  end
end

if config_env() == :prod do
  # ========================================
  # PRODUCTION MODE DETECTION
  # ========================================
  IO.puts("=" |> String.duplicate(60))
  IO.puts("🚀 RUNTIME.EXS: ENTERING PRODUCTION MODE")
  IO.puts("config_env() = #{inspect(config_env())}")
  IO.puts("MIX_ENV = #{inspect(System.get_env("MIX_ENV"))}")
  IO.puts("=" |> String.duplicate(60))

  # Set environment for Plug.SSL detection
  config :jump, :env, :prod

  IO.puts("✅ Set config :jump, :env to :prod")
  IO.puts("=" |> String.duplicate(60))

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") == "true", do: [:inet6], else: []

  config :jump, Jump.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    ssl: [
      verify: :verify_none
    ]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  IO.puts("=" |> String.duplicate(60))
  IO.puts("🌐 PRODUCTION ENDPOINT CONFIGURATION")
  IO.puts("PHX_HOST = #{inspect(host)}")
  IO.puts("PORT = #{inspect(port)}")
  IO.puts("URL will be: https://#{host}:443")
  IO.puts("=" |> String.duplicate(60))

  config :jump, JumpWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0},
      port: port,
      protocol_options: [idle_timeout: 60_000]
    ],
    secret_key_base: secret_key_base,
    force_ssl: [rewrite_on: [:x_forwarded_proto], host: nil, scheme: "https"],
    check_origin: [
      "https://#{host}",
      "https://ai-email-sorting-app-jatm.onrender.com"
    ],
    live_view: [signing_salt: secret_key_base]

  # Guardian secret key (optional - we're using Phoenix.Token instead)
  if System.get_env("GUARDIAN_SECRET_KEY") do
    config :jump, Jump.Guardian, secret_key: System.get_env("GUARDIAN_SECRET_KEY")
  end

  # Google OAuth credentials
  google_client_id = System.get_env("GOOGLE_CLIENT_ID") ||
    raise("environment variable GOOGLE_CLIENT_ID is missing.")

  google_client_secret = System.get_env("GOOGLE_CLIENT_SECRET") ||
    raise("environment variable GOOGLE_CLIENT_SECRET is missing.")

  IO.puts("=" |> String.duplicate(60))
  IO.puts("🔐 GOOGLE OAUTH CONFIGURATION")
  IO.puts("GOOGLE_CLIENT_ID present: #{!!google_client_id}")
  IO.puts("GOOGLE_CLIENT_SECRET present: #{!!google_client_secret}")
  IO.puts("=" |> String.duplicate(60))

  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: google_client_id,
    client_secret: google_client_secret

  # OpenAI API key
  config :openai,
    api_key:
      System.get_env("OPENAI_API_KEY") ||
        raise("environment variable OPENAI_API_KEY is missing.")

  # Cloak encryption key
  config :jump, Jump.Vault,
    ciphers: [
      default:
        {Cloak.Ciphers.AES.GCM,
         tag: "AES.GCM.V1",
         key:
           Base.decode64!(
             System.get_env("CLOAK_KEY") ||
               raise(
                 "environment variable CLOAK_KEY is missing. Generate with: Base.encode64(:crypto.strong_rand_bytes(32))"
               )
           )}
    ]

  IO.puts("=" |> String.duplicate(60))
  IO.puts("✅ PRODUCTION CONFIGURATION COMPLETED")
  IO.puts("=" |> String.duplicate(60))
end
