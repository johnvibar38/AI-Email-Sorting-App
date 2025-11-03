import Config

# Enable all log levels for debugging (including debug, info, warning, error)
# Note: Set back to :info after debugging is complete for better performance
config :logger, level: :debug

# Set environment for Plug.SSL detection (compile-time config)
config :jump, :env, :prod

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
config :jump, JumpWeb.Endpoint, server: true

# Note: All other endpoint configuration (http, secret_key_base, check_origin)
# is handled in config/runtime.exs to support environment variables
