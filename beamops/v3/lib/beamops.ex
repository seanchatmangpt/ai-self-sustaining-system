defmodule Beamops do
  @moduledoc """
  BEAMOPS v3 - Engineering Elixir Applications Observability Suite
  
  A comprehensive observability platform for BEAM applications implementing
  Engineering Elixir Applications patterns with Promex + Grafana integration,
  BEAM VM monitoring, performance profiling, and intelligent alerting.
  
  ## Quick Start
  
      # Start BEAMOPS observability
      Beamops.start_observability()
      
      # View system health
      Beamops.system_health()
      
      # Export current metrics
      Beamops.export_metrics()
      
      # Generate performance profile
      Beamops.profile_system(duration: 30_000)
  
  ## Components
  
  ### Promex Integration
  Custom Prometheus metrics for agent coordination and business intelligence:
  
      # Get coordination metrics
      Beamops.coordination_metrics()
      
      # Custom business metric
      Beamops.record_metric(:agent_work_completed, %{agent_id: "agent_123", duration: 1500})
  
  ### BEAM VM Monitoring
  Deep visibility into BEAM VM performance:
  
      # Current VM state
      Beamops.vm_state()
      
      # Process analysis
      Beamops.analyze_processes(limit: 100)
      
      # Memory breakdown
      Beamops.memory_analysis()
  
  ### Performance Profiling
  Real-time performance analysis with flame graphs:
  
      # Start profiling session
      Beamops.start_profiling()
      
      # Generate flame graph
      Beamops.flame_graph(duration: 10_000)
      
      # System benchmarks
      Beamops.run_benchmarks()
  
  ### Agent Coordination Metrics
  Specialized metrics for agent coordination and Scrum at Scale:
  
      # Agent performance metrics
      Beamops.agent_metrics()
      
      # S@S ceremony tracking
      Beamops.sas_metrics()
      
      # Team analytics
      Beamops.team_analytics()
  
  ### Error Tracking & Alerting
  Intelligent error tracking with ML-based anomaly detection:
  
      # Current alerts
      Beamops.active_alerts()
      
      # Error analytics
      Beamops.error_analytics()
      
      # SLA monitoring
      Beamops.sla_status()
  
  ## Configuration
  
  Configure BEAMOPS in your `config/config.exs`:
  
      config :beamops,
        promex: [port: 9568],
        vm_monitor: [enabled: true],
        profiler: [flame_graph_port: 8080],
        coordination_metrics: [enabled: true],
        alerting: [channels: [:slack, :email]]
  
  ## Engineering Elixir Applications Patterns
  
  BEAMOPS implements comprehensive observability patterns from the
  Engineering Elixir Applications book:
  
  - **Custom Promex Metrics**: Business-specific metrics collection
  - **Grafana Integration**: Production-ready dashboards
  - **BEAM VM Monitoring**: Deep BEAM virtual machine insights
  - **Performance Profiling**: Continuous performance optimization
  - **Intelligent Alerting**: ML-based anomaly detection and noise reduction
  - **Agent Coordination**: Specialized metrics for autonomous agent systems
  """
  
  alias Beamops.{
    Promex,
    VmMonitor,
    Profiler,
    CoordinationMetrics,
    AlertEngine,
    HealthChecker,
    LiveDashboard,
    MetricsExporter
  }
  
  require Logger

  @doc """
  Starts BEAMOPS observability suite.
  
  This function ensures all BEAMOPS components are running and properly configured.
  Safe to call multiple times.
  
  ## Examples
  
      iex> Beamops.start_observability()
      :ok
      
      # With custom configuration
      iex> Beamops.start_observability(promex: [port: 9569])
      :ok
  """
  @spec start_observability(keyword()) :: :ok | {:error, term()}
  def start_observability(opts \\ []) do
    Logger.info("🚀 Starting BEAMOPS v3 observability suite")
    
    case Application.ensure_all_started(:beamops) do
      {:ok, _apps} ->
        if opts != [], do: apply_runtime_config(opts)
        
        # Verify all components are healthy
        case system_health() do
          %{overall_health: health} when health >= 0.8 ->
            Logger.info("✅ BEAMOPS observability suite started successfully")
            :ok
            
          %{overall_health: health} ->
            Logger.warn("⚠️ BEAMOPS started with degraded health: #{round(health * 100)}%")
            :ok
        end
        
      {:error, {app, reason}} ->
        Logger.error("❌ Failed to start BEAMOPS dependency #{app}: #{inspect(reason)}")
        {:error, {:dependency_failed, app, reason}}
    end
  end

  @doc """
  Returns comprehensive system health information.
  
  Aggregates health data from all BEAMOPS components to provide
  a complete picture of system observability health.
  
  ## Examples
  
      iex> Beamops.system_health()
      %{
        overall_health: 0.95,
        components: %{
          promex: %{status: :healthy, metrics_count: 247},
          vm_monitor: %{status: :healthy, process_count: 1834},
          profiler: %{status: :healthy, active_sessions: 0},
          coordination: %{status: :healthy, active_agents: 5},
          alerting: %{status: :healthy, active_alerts: 0}
        },
        metrics: %{
          uptime_seconds: 86400,
          total_requests: 125847,
          error_rate: 0.001,
          response_time_p99: 45.2
        }
      }
  """
  @spec system_health() :: map()
  def system_health do
    HealthChecker.comprehensive_health_check()
  end

  @doc """
  Exports current Prometheus metrics in text format.
  
  Returns all metrics currently tracked by BEAMOPS Promex integration
  in Prometheus exposition format.
  
  ## Examples
  
      iex> metrics = Beamops.export_metrics()
      iex> String.contains?(metrics, "beamops_agent_work_completed_total")
      true
  """
  @spec export_metrics() :: String.t()
  def export_metrics do
    MetricsExporter.export_prometheus_metrics()
  end

  @doc """
  Returns current agent coordination metrics.
  
  Provides detailed metrics about agent coordination performance,
  work completion rates, and team analytics.
  
  ## Examples
  
      iex> Beamops.coordination_metrics()
      %{
        active_agents: 5,
        total_work_items: 23,
        completed_work_items: 18,
        average_completion_time: 1250,
        coordination_efficiency: 0.89,
        team_metrics: %{
          velocity: 15.2,
          collaboration_score: 0.94
        }
      }
  """
  @spec coordination_metrics() :: map()
  def coordination_metrics do
    CoordinationMetrics.current_metrics()
  end

  @doc """
  Records a custom business metric.
  
  Allows recording custom metrics for business intelligence and
  operational monitoring.
  
  ## Examples
  
      # Record work completion
      Beamops.record_metric(:agent_work_completed, %{
        agent_id: "agent_123",
        duration: 1500,
        complexity: :high
      })
      
      # Record S@S ceremony
      Beamops.record_metric(:sas_ceremony_completed, %{
        ceremony_type: :pi_planning,
        participants: 25,
        duration: 7200
      })
  """
  @spec record_metric(atom(), map()) :: :ok
  def record_metric(metric_name, metadata) when is_atom(metric_name) and is_map(metadata) do
    Promex.record_custom_metric(metric_name, metadata)
  end

  @doc """
  Returns current BEAM VM state and performance metrics.
  
  Provides detailed information about BEAM VM performance including
  process counts, memory usage, scheduler utilization, and garbage collection.
  
  ## Examples
  
      iex> Beamops.vm_state()
      %{
        process_count: 1834,
        memory: %{
          total: 125_847_392,
          processes: 67_234_123,
          system: 58_613_269
        },
        schedulers: %{
          online: 8,
          utilization: 0.23
        },
        gc: %{
          collections: 45123,
          words_reclaimed: 125_847_392
        }
      }
  """
  @spec vm_state() :: map()
  def vm_state do
    VmMonitor.current_vm_state()
  end

  @doc """
  Analyzes current system processes.
  
  Returns detailed analysis of running processes including memory usage,
  message queue lengths, and performance characteristics.
  
  ## Options
  
  - `:limit` - Maximum number of processes to analyze (default: 50)
  - `:sort_by` - Sort criteria (:memory, :reductions, :message_queue_len)
  - `:filter` - Process filter function
  
  ## Examples
  
      # Top 10 memory consumers
      Beamops.analyze_processes(limit: 10, sort_by: :memory)
      
      # Processes with long message queues
      Beamops.analyze_processes(
        filter: fn proc -> proc.message_queue_len > 100 end
      )
  """
  @spec analyze_processes(keyword()) :: [map()]
  def analyze_processes(opts \\ []) do
    VmMonitor.analyze_processes(opts)
  end

  @doc """
  Returns detailed memory analysis.
  
  Provides comprehensive memory usage breakdown including
  heap analysis, binary memory, ETS tables, and memory trends.
  
  ## Examples
  
      iex> Beamops.memory_analysis()
      %{
        total_memory: 125_847_392,
        breakdown: %{
          processes: 67_234_123,
          system: 58_613_269,
          atom: 1_234_567,
          binary: 15_847_392,
          code: 12_234_567,
          ets: 8_234_567
        },
        trends: %{
          growth_rate: 0.05,
          gc_frequency: 12.5
        },
        top_processes: [...]
      }
  """
  @spec memory_analysis() :: map()
  def memory_analysis do
    VmMonitor.memory_analysis()
  end

  @doc """
  Starts a performance profiling session.
  
  Begins profiling system performance with configurable duration
  and sampling options.
  
  ## Options
  
  - `:duration` - Profiling duration in milliseconds (default: 10_000)
  - `:type` - Profiling type (:cpu, :memory, :io) (default: :cpu)
  - `:sample_rate` - Sampling rate in Hz (default: 1000)
  
  ## Examples
  
      # 30-second CPU profiling
      Beamops.start_profiling(duration: 30_000, type: :cpu)
      
      # Memory profiling with high sample rate
      Beamops.start_profiling(type: :memory, sample_rate: 2000)
  """
  @spec start_profiling(keyword()) :: {:ok, reference()} | {:error, term()}
  def start_profiling(opts \\ []) do
    Profiler.start_profiling_session(opts)
  end

  @doc """
  Generates a flame graph for performance analysis.
  
  Creates an interactive flame graph visualization of system performance
  for the specified duration.
  
  ## Examples
  
      # Generate 10-second flame graph
      {:ok, url} = Beamops.flame_graph(duration: 10_000)
      # Returns: {:ok, "http://localhost:8080/flame_graph/20231215_143052"}
  """
  @spec flame_graph(keyword()) :: {:ok, String.t()} | {:error, term()}
  def flame_graph(opts \\ []) do
    Profiler.generate_flame_graph(opts)
  end

  @doc """
  Returns currently active alerts.
  
  Provides list of active alerts with severity, timing, and resolution information.
  
  ## Examples
  
      iex> Beamops.active_alerts()
      [
        %{
          id: "alert_001",
          type: :high_memory_usage,
          severity: :warning,
          triggered_at: ~U[2023-12-15 14:30:52Z],
          message: "Memory usage above 80% threshold",
          metadata: %{current_usage: 0.85, threshold: 0.80}
        }
      ]
  """
  @spec active_alerts() :: [map()]
  def active_alerts do
    AlertEngine.list_active_alerts()
  end

  @doc """
  Returns error analytics and trends.
  
  Provides comprehensive error analysis including error rates,
  patterns, and correlation data.
  
  ## Examples
  
      iex> Beamops.error_analytics()
      %{
        error_rate: 0.001,
        total_errors: 15,
        error_types: %{
          "badarg" => 8,
          "timeout" => 4,
          "noproc" => 3
        },
        trends: %{
          daily_change: -0.2,
          pattern_detected: false
        }
      }
  """
  @spec error_analytics() :: map()
  def error_analytics do
    AlertEngine.error_analytics()
  end

  @doc """
  Returns current SLA status and performance against targets.
  
  ## Examples
  
      iex> Beamops.sla_status()
      %{
        availability: 0.9998,
        response_time_p99: 45.2,
        error_rate: 0.001,
        targets: %{
          availability: 0.999,
          response_time_p99: 100.0,
          error_rate: 0.01
        },
        status: :meeting_targets
      }
  """
  @spec sla_status() :: map()
  def sla_status do
    AlertEngine.sla_status()
  end

  ## Private Functions
  
  defp apply_runtime_config(opts) do
    # Apply runtime configuration updates
    # This allows dynamic reconfiguration without restart
    Enum.each(opts, fn {component, config} ->
      Application.put_env(:beamops, component, config)
    end)
  end
end