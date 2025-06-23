import Config

# Configure Ecto repositories
config :self_sustaining, ecto_repos: [SelfSustaining.Repo]

# Configure Ash domains
config :self_sustaining,
  ash_domains: [SelfSustaining.AIDomain, SelfSustaining.Workflows]

# Disable ash function warnings for now
config :ash, :validate_domain_config_inclusion?, false

# Configure the database
config :self_sustaining, SelfSustaining.Repo,
  database: "self_sustaining_dev",
  username: "root",
  password: "password",
  hostname: "localhost",
  port: 5434

# Configure the endpoint
config :self_sustaining, SelfSustainingWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your-secret-key-base-here",
  render_errors: [
    formats: [html: SelfSustainingWeb.ErrorHTML, json: SelfSustainingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SelfSustaining.PubSub,
  live_view: [signing_salt: "live-view-salt"]

# Configure esbuild and tailwind
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# Configure OpenTelemetry with Enhanced Coordination Tracing
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: {:otlp, %{
    endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318"),
    headers: [{"Content-Type", "application/x-protobuf"}]
  }},
  resource: [
    service: [
      name: "ai_self_sustaining_system",
      version: "0.1.0",
      namespace: "coordination"
    ],
    attributes: [
      {"service.environment", System.get_env("MIX_ENV", "development")},
      {"service.instance.id", System.get_env("HOSTNAME", "localhost")},
      {"coordination.system.enabled", true},
      {"promex.integration.enabled", true}
    ]
  ],
  # Enhanced batch processing for coordination events
  batch_config: [
    max_queue_size: 2048,
    timeout_ms: 1000,
    export_timeout_ms: 5000
  ]

# Configure OpenTelemetry Phoenix with Coordination Context
config :opentelemetry_phoenix,
  endpoint: SelfSustainingWeb.Endpoint,
  trace_context_header_name: "traceparent",
  baggage_context_header_name: "baggage",
  # Enhanced coordination telemetry
  additional_attributes: [
    {"coordination.request.type", :request_type},
    {"coordination.agent.id", :agent_id}, 
    {"coordination.team", :team}
  ]

# Configure OpenTelemetry Ecto with Coordination Query Tracing
config :opentelemetry_ecto,
  repos: [SelfSustaining.Repo],
  # Trace coordination-related database operations
  trace_coordination_queries: true,
  additional_attributes: [
    {"coordination.query.type", :query_type},
    {"coordination.table", :table_name}
  ]

# Configure Oban for background job processing
config :self_sustaining, Oban,
  repo: SelfSustaining.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, ash_oban: 5]

# N8N Configuration
config :self_sustaining, :n8n,
  api_url: System.get_env("N8N_API_URL", "http://localhost:5678/api/v1"),
  api_key: System.get_env("N8N_API_KEY", ""),
  webhook_username: System.get_env("N8N_WEBHOOK_USERNAME", "webhook_user"),
  webhook_password: System.get_env("N8N_WEBHOOK_PASSWORD", "webhook_pass"),
  timeout: 30_000

# OpenTelemetry Data Pipeline Configuration
config :self_sustaining, :otlp_pipeline,
  # Pipeline execution settings
  max_concurrent_pipelines:
    String.to_integer(System.get_env("OTLP_MAX_CONCURRENT_PIPELINES", "5")),
  pipeline_timeout_ms: String.to_integer(System.get_env("OTLP_PIPELINE_TIMEOUT_MS", "60000")),

  # Sampling configuration
  trace_sampling_strategy:
    String.to_atom(System.get_env("OTLP_TRACE_SAMPLING_STRATEGY", "probabilistic")),
  trace_sampling_rate: String.to_float(System.get_env("OTLP_TRACE_SAMPLING_RATE", "0.1")),
  metric_sampling_strategy:
    String.to_atom(System.get_env("OTLP_METRIC_SAMPLING_STRATEGY", "time_based")),
  log_sampling_strategy:
    String.to_atom(System.get_env("OTLP_LOG_SAMPLING_STRATEGY", "severity_based")),

  # Error sampling (always sample errors by default)
  error_sampling_rate: String.to_float(System.get_env("OTLP_ERROR_SAMPLING_RATE", "1.0")),

  # Backend configuration
  jaeger_endpoint: System.get_env("JAEGER_ENDPOINT", "http://localhost:14268/api/traces"),
  jaeger_batch_size: String.to_integer(System.get_env("JAEGER_BATCH_SIZE", "100")),
  jaeger_timeout_ms: String.to_integer(System.get_env("JAEGER_TIMEOUT_MS", "10000")),
  jaeger_retry_attempts: String.to_integer(System.get_env("JAEGER_RETRY_ATTEMPTS", "3")),
  prometheus_endpoint:
    System.get_env("PROMETHEUS_ENDPOINT", "http://localhost:9090/api/v1/write"),
  prometheus_batch_size: String.to_integer(System.get_env("PROMETHEUS_BATCH_SIZE", "1000")),
  prometheus_timeout_ms: String.to_integer(System.get_env("PROMETHEUS_TIMEOUT_MS", "5000")),
  prometheus_retry_attempts: String.to_integer(System.get_env("PROMETHEUS_RETRY_ATTEMPTS", "2")),
  elasticsearch_endpoint: System.get_env("ELASTICSEARCH_ENDPOINT", "http://localhost:9200/_bulk"),
  elasticsearch_index: System.get_env("ELASTICSEARCH_INDEX", "telemetry"),
  elasticsearch_batch_size: String.to_integer(System.get_env("ELASTICSEARCH_BATCH_SIZE", "500")),
  elasticsearch_timeout_ms:
    String.to_integer(System.get_env("ELASTICSEARCH_TIMEOUT_MS", "15000")),
  elasticsearch_retry_attempts:
    String.to_integer(System.get_env("ELASTICSEARCH_RETRY_ATTEMPTS", "3")),

  # Service discovery and enrichment
  service_registry:
    %{
      # Can be populated with actual service discovery data
    },
  deployment_info: %{
    environment: System.get_env("DEPLOYMENT_ENVIRONMENT", "development"),
    region: System.get_env("DEPLOYMENT_REGION", "local"),
    cluster: System.get_env("DEPLOYMENT_CLUSTER", "local"),
    namespace: System.get_env("DEPLOYMENT_NAMESPACE", "default")
  },

  # Data quality thresholds
  required_fields: ["resourceSpans"],
  data_validation_enabled:
    String.to_existing_atom(System.get_env("OTLP_DATA_VALIDATION", "true")),

  # Performance tuning
  # full, minimal, disabled
  telemetry_mode: String.to_atom(System.get_env("OTLP_TELEMETRY_MODE", "full")),
  compression_enabled: String.to_existing_atom(System.get_env("OTLP_COMPRESSION", "false")),

  # Integration with existing systems
  integration: %{
    agent_coordination_enabled: true,
    n8n_integration_enabled: true,
    livebook_integration_enabled: true,
    self_telemetry_enabled: true
  }

# Livebook Configuration
config :livebook,
  # Authentication integration with Phoenix app
  authentication: :token,
  # Database connectivity for notebooks
  default_runtime: {Livebook.Runtime.Attached, node: Node.self()},
  # Team collaboration features
  teams_enabled: true,
  # Integration with Phoenix endpoint
  iframe_port: 4002,
  # Security settings
  token: System.get_env("LIVEBOOK_TOKEN", "self-sustaining-system-token"),
  # Data source configuration
  data_path: "priv/livebook_data",
  # Enable Teams features
  feature_flags: ["teams", "deployment", "collaboration"]

# Configure Kino for interactive widgets
config :kino, :output, :terminal

# Configure PromEx for Prometheus metrics - minimal working implementation
config :self_sustaining, SelfSustaining.PromExMinimal,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  metrics_server: [
    port: String.to_integer(System.get_env("PROMEX_PORT", "9568")),
    path: "/metrics",
    protocol: :http,
    pool_size: 5,
    cowboy_opts: []
  ],
  grafana: [
    host: System.get_env("GRAFANA_HOST", "http://localhost:3000"),
    auth_token: System.get_env("GRAFANA_TOKEN", ""),
    upload_dashboards_on_start: true,
    folder_name: "Agent Coordination",
    annotate_app_lifecycle: true
  ]

# Import environment specific config
import_config "#{config_env()}.exs"
