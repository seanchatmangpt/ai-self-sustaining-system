# BEAMOPS v3 Development Configuration

import Config

# Configure your database
config :beamops, Beamops.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "beamops_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :beamops, BeamopsWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "development_secret_key_base_that_is_at_least_64_bytes_long_for_security",
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# BEAMOPS specific development configuration
config :beamops,
  coordination_base_path: "./agent_coordination",
  coordination_metrics: [
    enabled: true,
    poll_rate: 5_000  # 5 seconds for faster development feedback
  ]

# PromEx development configuration
config :beamops, Beamops.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [
    port: 9568,
    path: "/metrics"
  ]