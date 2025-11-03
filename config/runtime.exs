import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# Load .env file for development and test environments
if config_env() in [:dev, :test] and File.exists?(".env") do
  if Code.ensure_loaded?(Dotenvy) do
    import Dotenvy
    source!([".env", System.get_env()])
    
    # Development environment configuration
    if config_env() == :dev do
      config :jump, Jump.Repo,
        username: env!("POSTGRES_USER", :string),
        password: env!("POSTGRES_PASSWORD", :string),
        hostname: env!("POSTGRES_HOST", :string),
        database: env!("DATABASE", :string)
        
      # Google OAuth credentials
      config :ueberauth, Ueberauth.Strategy.Google.OAuth,
        client_id: env!("GOOGLE_CLIENT_ID", :string),
        client_secret: env!("GOOGLE_CLIENT_SECRET", :string)
      
      # OpenAI API key
      config :openai,
        api_key: env!("OPENAI_API_KEY", :string)
      
      # Cloak encryption key
      config :jump, Jump.Vault,
        ciphers: [
          default: {
            Cloak.Ciphers.AES.GCM,
            tag: "AES.GCM.V1",
            key: Base.decode64!(env!("CLOAK_KEY", :string))
          }
        ]
    end
  end
end

if config_env() == :prod do
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
    ssl: true,
    ssl_opts: [
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

  config :jump, JumpWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: [
      "https://#{host}",
      "https://ai-email-sorting-app-jatm.onrender.com"
    ]

  # Guardian secret key (optional - we're using Phoenix.Token instead)
  if System.get_env("GUARDIAN_SECRET_KEY") do
    config :jump, Jump.Guardian, secret_key: System.get_env("GUARDIAN_SECRET_KEY")
  end

  # Google OAuth credentials
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id:
      System.get_env("GOOGLE_CLIENT_ID") ||
        raise("environment variable GOOGLE_CLIENT_ID is missing."),
    client_secret:
      System.get_env("GOOGLE_CLIENT_SECRET") ||
        raise("environment variable GOOGLE_CLIENT_SECRET is missing.")

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
end
