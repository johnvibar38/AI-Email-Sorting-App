import Config

# Note: Database configuration is in config/runtime.exs to support .env file loading
# Configure your database
config :jump, Jump.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :jump, JumpWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  code_reloader: true,
  check_origin: false,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_must_be_at_least_64_bytes_long_for_security_purposes",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :jump, JumpWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg|ico)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/jump_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher log level during development
config :logger, level: :debug

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Enable dev routes for /dev/* endpoints (LiveDashboard, Mailbox, etc.)
config :jump, dev_routes: true
