import Config

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
config :jump, JumpWeb.Endpoint, server: true

# Note: All other endpoint configuration (http, secret_key_base, check_origin)
# is handled in config/runtime.exs to support environment variables
