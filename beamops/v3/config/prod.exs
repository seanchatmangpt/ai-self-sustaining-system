# BEAMOPS v3 Production Configuration

import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

config :beamops, BeamopsWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: Beamops.Finch

# Do not print debug messages in production
config :logger, level: :info

# BEAMOPS production configuration
config :beamops,
  coordination_base_path: System.get_env("COORDINATION_BASE_PATH", "/app/coordination"),
  coordination_metrics: [
    enabled: true,
    poll_rate: 10_000  # 10 seconds
  ]

# PromEx production configuration
config :beamops, Beamops.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [
    port: String.to_integer(System.get_env("PROMEX_PORT", "9568")),
    path: "/metrics"
  ]

# Runtime configuration will be loaded in config/runtime.exs