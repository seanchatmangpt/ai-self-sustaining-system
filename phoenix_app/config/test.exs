import Config

# Configure the database
config :self_sustaining, SelfSustaining.Repo,
  database: "self_sustaining_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "sac",
  password: "",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test
config :self_sustaining, SelfSustainingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DQ0VJtfOX8qgGOoHLhwC9V0l8P3mBkP5yJ2QxC8aP5hG9Nd6O1mRvWsK8xYzA2bF",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime