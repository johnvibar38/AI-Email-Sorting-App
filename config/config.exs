import Config

# config/runtime.exs is executed for all environments, including
# during compilation. See config/runtime.exs for runtime-specific
# configurations.

# Configure Ecto repositories
config :jump,
  ecto_repos: [Jump.Repo]

# Configures the endpoint
config :jump, JumpWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: JumpWeb.ErrorHTML, json: JumpWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jump.PubSub,
  live_view: [signing_salt: "jump_live_view_secret"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "3.3.0",
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

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Guardian configuration
config :jump, Jump.Guardian,
  issuer: "jump",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "your-secret-key-change-in-runtime-exs"

# Ueberauth Google OAuth configuration with Gmail scopes
config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google,
       [
         default_scope:
           "email profile https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.modify",
         access_type: "offline",
         prompt: "consent"
       ]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# OpenAI configuration
config :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY"),
  http_options: [recv_timeout: 30_000]

# Cloak encryption configuration
config :jump, Jump.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key:
        Base.decode64!(
          System.get_env("CLOAK_KEY") || Base.encode64(:crypto.strong_rand_bytes(32))
        )
    }
  ]

config :jump, Jump.Repo, migration_timestamps: [type: :utc_datetime]

# Oban configuration
config :jump, Oban,
  repo: Jump.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, emails: 20, unsubscribe: 5]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
