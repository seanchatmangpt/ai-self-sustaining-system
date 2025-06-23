import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
config :self_sustaining, SelfSustainingWeb.Endpoint,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: SelfSustaining.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger,
  level: :info,
  metadata: [:trace_id, :span_id, :request_id]

# Configure OpenTelemetry for production
config :opentelemetry,
  traces_exporter:
    {:otlp,
     %{
       endpoint: {:system, "OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318/v1/traces"},
       headers: [
         {"authorization", {:system, "OTEL_EXPORTER_OTLP_HEADERS", ""}}
       ]
     }},
  resource: [
    service: [
      name: "self_sustaining_system",
      version: "0.1.0"
    ]
  ]

# Runtime production config, including reading
# of environment variables, is done on config/runtime.exs.
