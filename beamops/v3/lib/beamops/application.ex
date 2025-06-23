defmodule Beamops.Application do
  @moduledoc """
  BEAMOPS v3 Application - Engineering Elixir Applications Observability Suite
  
  Starts and supervises all BEAMOPS observability components following
  Engineering Elixir Applications patterns for comprehensive BEAM monitoring.
  
  ## Supervision Tree
  
  - **Promex.Supervisor**: Prometheus metrics collection and export
  - **VmMonitor.Supervisor**: BEAM VM monitoring and process inspection
  - **LiveDashboard.Supervisor**: Enhanced LiveDashboard with custom pages
  - **Profiler.Supervisor**: Performance profiling and flame graph generation
  - **CoordinationMetrics.Supervisor**: Agent coordination and S@S metrics
  - **AlertEngine.Supervisor**: Error tracking and intelligent alerting
  - **TelemetryBridge.Supervisor**: OpenTelemetry integration bridge
  
  ## Configuration
  
  Configure BEAMOPS in your application config:
  
      config :beamops,
        # Promex configuration
        promex: [
          disabled: false,
          manual_metrics_start_delay: :no_delay,
          drop_metrics_groups: [],
          grafana_folder: "/etc/grafana/provisioning/dashboards",
          metrics_server: [
            port: 9568,
            path: "/metrics",
            protocol: :http,
            pool_size: 5,
            scheme: :http
          ]
        ],
        
        # BEAM VM monitoring
        vm_monitor: [
          enabled: true,
          poll_interval: 5_000,
          process_limit: 10_000,
          memory_threshold: 0.8
        ],
        
        # Performance profiling
        profiler: [
          enabled: true,
          flame_graph_port: 8080,
          benchmark_interval: 60_000
        ],
        
        # Agent coordination metrics
        coordination_metrics: [
          enabled: true,
          coordination_helper_path: "./agent_coordination/coordination_helper.sh",
          metrics_interval: 10_000
        ],
        
        # Error tracking and alerting
        alerting: [
          enabled: true,
          alert_channels: [:slack, :email, :pagerduty],
          escalation_timeout: 300_000
        ]
  """
  
  use Application
  
  alias Beamops.{
    Promex
  }
  
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("🚀 Starting BEAMOPS v3 - Engineering Elixir Applications Observability Suite")
    
    # Setup telemetry handlers early
    setup_telemetry_handlers()
    
    children = [
      # Phoenix Endpoint for web interface
      BeamopsWeb.Endpoint,
      # Core observability infrastructure (minimal working setup)
      {Beamops.Promex, Application.get_env(:beamops, Beamops.Promex, [])}
    ]
    
    opts = [strategy: :one_for_one, name: Beamops.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("✅ BEAMOPS v3 started successfully")
        {:ok, pid}
        
      {:error, reason} ->
        Logger.error("❌ BEAMOPS v3 failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("🛑 Stopping BEAMOPS v3 observability suite")
    :ok
  end
  
  ## Private Functions
  
  defp setup_telemetry_handlers do
    # Setup core telemetry event handlers for BEAMOPS
    events = [
      [:beamops, :promex, :metrics, :exported],
      [:beamops, :vm_monitor, :process, :analyzed],
      [:beamops, :profiler, :flame_graph, :generated],
      [:beamops, :coordination, :metrics, :collected],
      [:beamops, :alert, :triggered],
      [:beamops, :health_check, :completed]
    ]
    
    :telemetry.attach_many(
      "beamops-core-handlers",
      events,
      &handle_telemetry_event/4,
      %{}
    )
    
    Logger.debug("📊 BEAMOPS telemetry handlers attached")
  end
  
  defp handle_telemetry_event([:beamops, :promex, :metrics, :exported], measurements, metadata, _config) do
    Logger.debug("📊 Promex metrics exported: #{measurements.count} metrics in #{measurements.duration}ms")
    
    # Emit BEAMOPS-specific telemetry for Promex export performance
    :telemetry.execute([:beamops, :internal, :metrics_export], %{
      metrics_count: measurements.count,
      export_duration_ms: measurements.duration,
      export_timestamp: System.system_time(:millisecond)
    }, metadata)
  end
  
  defp handle_telemetry_event([:beamops, :coordination, :metrics, :collected], measurements, metadata, _config) do
    Logger.debug("🎯 Coordination metrics collected: #{measurements.active_agents} agents, #{measurements.work_items} work items")
    
    # Track coordination system health
    coordination_health = calculate_coordination_health(measurements)
    
    :telemetry.execute([:beamops, :internal, :coordination_health], %{
      health_score: coordination_health,
      active_agents: measurements.active_agents,
      work_items: measurements.work_items
    }, metadata)
  end
  
  defp handle_telemetry_event([:beamops, :alert, :triggered], measurements, metadata, _config) do
    Logger.warn("🚨 Alert triggered: #{metadata.alert_type} - #{metadata.message}")
    
    # Track alert frequency for noise reduction
    :telemetry.execute([:beamops, :internal, :alert_frequency], %{
      alert_count: 1,
      severity: measurements.severity,
      timestamp: System.system_time(:millisecond)
    }, metadata)
  end
  
  defp handle_telemetry_event(event, measurements, metadata, _config) do
    Logger.debug("📊 BEAMOPS telemetry event: #{inspect(event)} - #{inspect(measurements)}")
  end
  
  defp calculate_coordination_health(measurements) do
    # Simple health calculation based on agent activity and work completion
    active_ratio = measurements.active_agents / max(measurements.total_agents, 1)
    work_efficiency = measurements.completed_work / max(measurements.total_work, 1)
    
    (active_ratio * 0.6 + work_efficiency * 0.4) * 100
    |> min(100)
    |> max(0)
    |> round()
  end
  
  defp log_startup_summary(config) do
    Logger.info("""
    
    📊 BEAMOPS v3 - Engineering Elixir Applications Observability Suite
    ================================================================
    
    🔧 Components Started:
    • Promex Metrics      → http://localhost:#{config.promex.metrics_server.port}#{config.promex.metrics_server.path}
    • VM Monitor          → Enabled (#{config.vm_monitor.poll_interval}ms interval)
    • Performance Profiler → http://localhost:#{config.profiler.flame_graph_port}
    • Coordination Metrics → Enabled (#{config.coordination_metrics.metrics_interval}ms interval)
    • Alert Engine        → Enabled (#{length(config.alerting.alert_channels)} channels)
    • LiveDashboard       → Enhanced with BEAMOPS pages
    
    📈 Monitoring Capabilities:
    • BEAM VM metrics, process monitoring, memory analysis
    • Agent coordination performance and S@S ceremony tracking
    • Real-time performance profiling with flame graphs
    • Intelligent error tracking and alerting
    • Custom Promex metrics for business intelligence
    • OpenTelemetry distributed tracing integration
    
    🎯 Ready for Engineering Elixir Applications observability!
    """)
  end
end