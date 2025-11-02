import Config

# Configure your database for tests
# Supports DATABASE_URL environment variable or individual params
database_config =
  if database_url = System.get_env("DATABASE_URL") do
    [url: database_url]
  else
    [
      username: System.get_env("POSTGRES_USER") || "postgres",
      password: System.get_env("POSTGRES_PASSWORD") || "aiddyr",
      hostname: System.get_env("POSTGRES_HOST") || "localhost",
      database: "jump_test#{System.get_env("MIX_TEST_PARTITION")}"
    ]
  end

config :jump, Jump.Repo,
  Keyword.merge(database_config, [
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
  ])

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jump, JumpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_for_testing_must_be_at_least_64_bytes_long_to_work_properly_in_phoenix",
  server: false

# In test we don't send emails.
config :jump, Jump.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure Wallaby (browser testing - only used when explicitly needed)
config :wallaby,
  otp_app: :jump,
  driver: Wallaby.Chrome,
  hackney_options: [timeout: :infinity, recv_timeout: :infinity],
  screenshot_on_failure: true

# Disable Oban in tests (use testing: :manual to prevent auto-start)
config :jump, Oban, testing: :manual

