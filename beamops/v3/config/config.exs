# BEAMOPS v3 Configuration - Simplified Engineering Elixir Applications
# 
# Following real Engineering Elixir Applications patterns with minimal configuration.

import Config

# BEAMOPS Core Configuration
config :beamops,
  # Global settings
  environment: Mix.env(),
  system_name: "ai_self_sustaining_system",
  version: "3.0.0",
  
  # Coordination system integration
  coordination_base_path: "./agent_coordination",
  coordination_metrics_interval: 10_000,  # 10 seconds
  ideal_agent_count: 10,
  
  # Simple PromEx Configuration (Following Engineering Elixir Applications)
  promex: [
    disabled: false,
    manual_metrics_start_delay: :no_delay,
    drop_metrics_groups: [],
    grafana: :disabled,
    metrics_server: :disabled
  ],

  # BEAM VM Monitoring Configuration
  vm_monitor: [
    enabled: true,
    poll_interval: 5_000,  # 5 seconds
    process_limit: 10_000,
    memory_threshold: 0.8,  # Alert when memory usage > 80%
    scheduler_monitoring: true,
    gc_monitoring: true,
    detailed_process_tracking: [
      # Track specific process types
      :gen_server,
      :gen_statem,
      :task,
      :phoenix_channel,
      :ecto_pool
    ],
    memory_analysis: [
      enabled: true,
      heap_analysis: true,
      binary_analysis: true,
      ets_monitoring: true,
      leak_detection: true
    ]
  ],

  # Performance Profiling Configuration
  profiler: [
    enabled: true,
    flame_graph_port: 8080,
    flame_graph_path: "/tmp/beamops_flame_graphs",
    benchmark_interval: 60_000,  # 1 minute
    profiling_options: [
      type: :cpu,  # :cpu, :memory, :io
      sample_rate: 1000,  # Hz
      max_duration: 300_000,  # 5 minutes max
      auto_gc_before_profiling: true
    ],
    benchmark_suites: [
      :coordination_performance,
      :memory_usage,
      :process_spawning,
      :message_passing
    ]
  ],

  # Simple coordination metrics (following real patterns)
  coordination_metrics: [
    enabled: true,
    poll_rate: 10_000,  # 10 seconds
    coordination_base_path: "./agent_coordination"
  ],

  # Error Tracking and Alerting Configuration
  alerting: [
    enabled: true,
    alert_channels: [:console, :telemetry],  # Add :slack, :email, :pagerduty in production
    escalation_timeout: 300_000,  # 5 minutes
    alert_rules: [
      # Memory alerts
      %{
        name: "high_memory_usage",
        metric: "beamops_vm_memory_usage_ratio",
        threshold: 0.85,
        duration: 60_000,  # 1 minute
        severity: :warning
      },
      
      # Agent coordination alerts
      %{
        name: "coordination_efficiency_low",
        metric: "beamops_coordination_efficiency_ratio",
        threshold: 0.7,
        duration: 300_000,  # 5 minutes
        severity: :warning
      },
      
      # Work completion alerts
      %{
        name: "work_failure_rate_high",
        metric: "beamops_agent_work_failed_total",
        threshold: 0.1,  # 10% failure rate
        duration: 600_000,  # 10 minutes
        severity: :critical
      }
    ],
    notification_settings: [
      rate_limiting: [
        max_alerts_per_minute: 10,
        duplicate_suppression: 300_000  # 5 minutes
      ],
      escalation: [
        warning_to_critical: 1_800_000,  # 30 minutes
        critical_to_emergency: 3_600_000  # 1 hour
      ]
    ]
  ],

  # Enhanced LiveDashboard Configuration
  live_dashboard: [
    enabled: true,
    port: 4040,
    custom_pages: [
      # BEAMOPS custom pages
      {Beamops.LiveDashboard.AgentCoordinationPage, []},
      {Beamops.LiveDashboard.PerformanceProfilingPage, []},
      {Beamops.LiveDashboard.BusinessMetricsPage, []},
      {Beamops.LiveDashboard.AlertManagementPage, []}
    ],
    metrics_visualization: [
      real_time_charts: true,
      historical_data: true,
      chart_refresh_interval: 5_000  # 5 seconds
    ]
  ],

  # OpenTelemetry Integration Configuration
  telemetry_bridge: [
    enabled: true,
    otel_exporter: [
      protocol: :grpc,
      endpoint: "http://localhost:4317",
      headers: []
    ],
    trace_sampling: [
      ratio: 0.1,  # 10% sampling in production
      max_spans_per_trace: 1000
    ],
    metrics_export: [
      interval: 30_000,  # 30 seconds
      enabled_metrics: [:coordination, :performance, :business]
    ]
  ],

  # Health Checking Configuration
  health_checker: [
    enabled: true,
    check_interval: 30_000,  # 30 seconds
    health_checks: [
      :promex_metrics_server,
      :vm_monitor,
      :coordination_files,
      :telemetry_bridge,
      :alert_engine
    ],
    health_thresholds: [
      critical: 0.5,
      warning: 0.7,
      healthy: 0.85
    ]
  ]

# Phoenix Configuration (for LiveDashboard)
config :phoenix, :json_library, Jason

# Logger Configuration (Simplified - no file backend for now)
config :logger,
  level: :info,
  backends: [:console]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Simple Telemetry Configuration
config :telemetry_poller, :default, []

# OpenTelemetry Configuration (Disabled - dependencies not installed)
# config :opentelemetry,
#   resource: [
#     service: [
#       name: "beamops_v3",
#       version: "3.0.0"
#     ],
#     deployment: [
#       environment: to_string(Mix.env())
#     ]
#   ]

# config :opentelemetry_phoenix,
#   adapter: :cowboy2

# config :opentelemetry_ecto,
#   time_unit: :microsecond

# Environment-specific configurations
import_config "#{Mix.env()}.exs"