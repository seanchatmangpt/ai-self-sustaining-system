# BEAMOPS v3 Test Configuration

import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :beamops, Beamops.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "beamops_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :beamops, BeamopsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_testing_only",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# BEAMOPS test configuration
config :beamops,
  coordination_base_path: "./test/fixtures/coordination",
  coordination_metrics: [
    enabled: false  # Disable metrics during testing
  ]

# Disable PromEx during testing
config :beamops, Beamops.PromEx,
  disabled: true