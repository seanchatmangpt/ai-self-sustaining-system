import Config

# Configure the database
config :self_sustaining, SelfSustaining.Repo,
  database: "self_sustaining_dev",
  username: "sac",
  password: "dev_password",
  hostname: "localhost",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :self_sustaining, SelfSustainingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "DQ0VJtfOX8qgGOoHLhwC9V0l8P3mBkP5yJ2QxC8aP5hG9Nd6O1mRvWsK8xYzA2bF",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :self_sustaining, SelfSustainingWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/self_sustaining_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :self_sustaining, :dev_routes, true

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:trace_id, :span_id, :request_id]

# Configure OpenTelemetry for development
config :opentelemetry,
  traces_exporter: :none,
  resource: [
    service: [
      name: "self_sustaining_system_dev",
      version: "0.1.0"
    ]
  ]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Livebook Development Configuration
config :livebook,
  # Development-specific settings
  ip: {127, 0, 0, 1},
  port: 8080,
  # Enable auto-start in development
  auto_shutdown: false,
  # Development token (should be changed in production)
  token: "dev-self-sustaining-livebook-token",
  # Enable all features for development
  feature_flags: ["teams", "deployment", "collaboration", "apps"],
  # Development-specific data path
  data_path: "priv/livebook_data/dev",
  # Allow iframe embedding for Phoenix integration
  iframe_url: "http://localhost:4001"
