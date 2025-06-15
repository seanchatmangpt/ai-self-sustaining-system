# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Ash Framework configuration
config :ai_self_sustaining_minimal,
  ash_domains: [
    AiSelfSustainingMinimal.Coordination,
    AiSelfSustainingMinimal.Telemetry
  ],
  generators: [timestamp_type: :utc_datetime]

# Database configuration
config :ai_self_sustaining_minimal, AiSelfSustainingMinimal.Repo,
  username: System.get_env("DATABASE_USERNAME", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  database: System.get_env("DATABASE_NAME", "ai_self_sustaining_minimal_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10"))

config :ai_self_sustaining_minimal,
  ecto_repos: [AiSelfSustainingMinimal.Repo]

# OpenTelemetry Pipeline configuration (preserve from original system)
config :ai_self_sustaining_minimal, :otlp_pipeline,
  max_concurrent_pipelines: String.to_integer(System.get_env("OTLP_MAX_CONCURRENT_PIPELINES", "5")),
  trace_sampling_rate: String.to_float(System.get_env("OTLP_TRACE_SAMPLING_RATE", "0.1")),
  jaeger_endpoint: System.get_env("JAEGER_ENDPOINT", "http://localhost:14268/api/traces"),
  prometheus_endpoint: System.get_env("PROMETHEUS_ENDPOINT", "http://localhost:9090/api/v1/write"),
  elasticsearch_endpoint: System.get_env("ELASTICSEARCH_ENDPOINT", "http://localhost:9200"),
  integration: %{
    self_telemetry_enabled: true,
    livebook_integration_enabled: false
  }

# Agent coordination configuration (preserve from original system)
config :ai_self_sustaining_minimal, :agent_coordination,
  heartbeat_interval_ms: String.to_integer(System.get_env("AGENT_HEARTBEAT_INTERVAL", "30000")),
  work_claim_timeout_ms: String.to_integer(System.get_env("WORK_CLAIM_TIMEOUT", "300000")),
  max_concurrent_work_items: String.to_integer(System.get_env("MAX_CONCURRENT_WORK", "10"))

# Configures the endpoint
config :ai_self_sustaining_minimal, AiSelfSustainingMinimalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [
      html: AiSelfSustainingMinimalWeb.ErrorHTML,
      json: AiSelfSustainingMinimalWeb.ErrorJSON
    ],
    layout: false
  ],
  pubsub_server: AiSelfSustainingMinimal.PubSub,
  live_view: [signing_salt: "4ccRgc94"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ai_self_sustaining_minimal, AiSelfSustainingMinimal.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  ai_self_sustaining_minimal: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  ai_self_sustaining_minimal: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
