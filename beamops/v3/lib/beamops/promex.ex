defmodule Beamops.Promex do
  @moduledoc """
  BEAMOPS Promex Integration - Engineering Elixir Applications Pattern
  
  Custom Prometheus metrics implementation following Engineering Elixir Applications
  patterns for comprehensive BEAM observability and business intelligence.
  
  Extends standard Promex with specialized metrics for:
  - Agent coordination performance
  - Scrum at Scale (S@S) ceremony tracking  
  - BEAM VM deep monitoring
  - Business process intelligence
  - System health scoring
  
  ## Metric Categories
  
  ### Agent Coordination Metrics
  - `beamops_agent_work_claimed_total` - Work items claimed by agents
  - `beamops_agent_work_completed_total` - Work items completed
  - `beamops_agent_work_duration_seconds` - Work completion time
  - `beamops_coordination_efficiency_ratio` - Overall coordination efficiency
  
  ### S@S Ceremony Metrics  
  - `beamops_sas_ceremony_completed_total` - S@S ceremonies completed
  - `beamops_sas_ceremony_duration_seconds` - Ceremony duration
  - `beamops_sas_pi_planning_effectiveness` - PI planning effectiveness score
  - `beamops_sas_art_sync_frequency` - ART synchronization frequency
  
  ### BEAM VM Metrics
  - `beamops_vm_process_count` - Current process count
  - `beamops_vm_memory_usage_bytes` - Memory usage by type
  - `beamops_vm_scheduler_utilization_ratio` - Scheduler utilization
  - `beamops_vm_gc_collections_total` - Garbage collection statistics
  
  ### Business Intelligence Metrics
  - `beamops_business_value_delivered` - Business value delivery tracking
  - `beamops_system_health_score` - Overall system health (0-100)
  - `beamops_performance_sla_compliance` - SLA compliance ratio
  - `beamops_error_budget_consumption` - Error budget usage
  
  ## Usage
  
      # Start Promex with BEAMOPS configuration
      {:ok, _} = Beamops.Promex.start_link()
      
      # Record custom business metric
      Beamops.Promex.record_custom_metric(:agent_work_completed, %{
        agent_id: "agent_123",
        duration: 1500,
        complexity: :high
      })
      
      # Get current metrics export
      metrics = Beamops.Promex.export_metrics()
  """
  
  # Simplified: Following Engineering Elixir Applications patterns
  use PromEx, otp_app: :beamops
  
  alias PromEx.Plugins
  require Logger

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      # Simple agent coordination plugin (single responsibility)
      Beamops.PromEx.AgentCoordinationPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:beamops, "grafana_dashboards/agent_coordination.json"}
    ]
  end

  @doc """
  Records a custom business metric with metadata.
  
  This function provides a high-level interface for recording business-specific
  metrics that are important for Engineering Elixir Applications observability.
  
  ## Metric Types
  
  ### Agent Coordination
  - `:agent_work_claimed` - When an agent claims work
  - `:agent_work_completed` - When work is completed
  - `:agent_work_failed` - When work fails
  - `:coordination_cycle_completed` - Full coordination cycle
  
  ### S@S Ceremonies
  - `:sas_pi_planning` - PI planning session
  - `:sas_art_sync` - ART synchronization
  - `:sas_system_demo` - System demo completion
  - `:sas_inspect_adapt` - Inspect & Adapt session
  
  ### System Health
  - `:system_health_check` - Health check completion
  - `:performance_degradation` - Performance issues
  - `:error_spike` - Error rate increase
  - `:recovery_completed` - System recovery
  
  ## Examples
  
      # Agent work completion
      Beamops.Promex.record_custom_metric(:agent_work_completed, %{
        agent_id: "agent_1734567890123456789",
        work_type: "feature_development",
        duration: 2400,
        complexity: :high,
        team: "platform_team"
      })
      
      # S@S ceremony completion
      Beamops.Promex.record_custom_metric(:sas_pi_planning, %{
        art_id: "platform_art",
        participants: 45,
        duration: 8 * 60 * 60 * 1000,  # 8 hours in ms
        objectives_committed: 12,
        confidence_level: 8
      })
      
      # System health event
      Beamops.Promex.record_custom_metric(:system_health_check, %{
        component: "agent_coordination",
        health_score: 95,
        checks_passed: 23,
        checks_failed: 1
      })
  """
  @spec record_custom_metric(atom(), map()) :: :ok
  def record_custom_metric(metric_type, metadata) when is_atom(metric_type) and is_map(metadata) do
    timestamp = System.system_time(:millisecond)
    
    case metric_type do
      # Agent Coordination Metrics
      :agent_work_claimed ->
        Registry.counter(
          :beamops_agent_work_claimed_total,
          %{
            agent_id: Map.get(metadata, :agent_id, "unknown"),
            work_type: Map.get(metadata, :work_type, "general"),
            team: Map.get(metadata, :team, "default")
          }
        )
        |> Registry.inc(1)
        
      :agent_work_completed ->
        labels = %{
          agent_id: Map.get(metadata, :agent_id, "unknown"),
          work_type: Map.get(metadata, :work_type, "general"),
          complexity: Map.get(metadata, :complexity, :medium),
          team: Map.get(metadata, :team, "default")
        }
        
        # Increment completion counter
        Registry.counter(:beamops_agent_work_completed_total, labels)
        |> Registry.inc(1)
        
        # Record duration if provided
        if duration = Map.get(metadata, :duration) do
          Registry.histogram(:beamops_agent_work_duration_seconds, labels)
          |> Registry.observe(duration / 1000)
        end
        
      :agent_work_failed ->
        Registry.counter(
          :beamops_agent_work_failed_total,
          %{
            agent_id: Map.get(metadata, :agent_id, "unknown"),
            work_type: Map.get(metadata, :work_type, "general"),
            error_type: Map.get(metadata, :error_type, "unknown"),
            team: Map.get(metadata, :team, "default")
          }
        )
        |> Registry.inc(1)
        
      # S@S Ceremony Metrics
      :sas_pi_planning ->
        labels = %{
          art_id: Map.get(metadata, :art_id, "default_art"),
          confidence_level: Map.get(metadata, :confidence_level, 5)
        }
        
        Registry.counter(:beamops_sas_ceremony_completed_total, Map.put(labels, :ceremony_type, "pi_planning"))
        |> Registry.inc(1)
        
        if duration = Map.get(metadata, :duration) do
          Registry.histogram(:beamops_sas_ceremony_duration_seconds, Map.put(labels, :ceremony_type, "pi_planning"))
          |> Registry.observe(duration / 1000)
        end
        
        if objectives = Map.get(metadata, :objectives_committed) do
          Registry.gauge(:beamops_sas_pi_objectives_committed, labels)
          |> Registry.set(objectives)
        end
        
      :sas_art_sync ->
        labels = %{
          art_id: Map.get(metadata, :art_id, "default_art"),
          sync_type: Map.get(metadata, :sync_type, "regular")
        }
        
        Registry.counter(:beamops_sas_ceremony_completed_total, Map.put(labels, :ceremony_type, "art_sync"))
        |> Registry.inc(1)
        
      # System Health Metrics
      :system_health_check ->
        component = Map.get(metadata, :component, "system")
        health_score = Map.get(metadata, :health_score, 50)
        
        Registry.gauge(:beamops_system_health_score, %{component: component})
        |> Registry.set(health_score)
        
        checks_passed = Map.get(metadata, :checks_passed, 0)
        checks_failed = Map.get(metadata, :checks_failed, 0)
        
        Registry.gauge(:beamops_health_checks_passed, %{component: component})
        |> Registry.set(checks_passed)
        
        Registry.gauge(:beamops_health_checks_failed, %{component: component})
        |> Registry.set(checks_failed)
        
      _ ->
        Logger.warn("Unknown metric type: #{metric_type}")
        :ok
    end
    
    # Emit telemetry event for metric recording
    :telemetry.execute(
      [:beamops, :promex, :custom_metric, :recorded],
      %{timestamp: timestamp},
      %{metric_type: metric_type, metadata: metadata}
    )
    
    :ok
  end

  @doc """
  Exports current metrics in Prometheus text format.
  
  Returns all metrics currently registered in the BEAMOPS Promex registry
  formatted for Prometheus scraping.
  """
  @spec export_metrics() :: String.t()
  def export_metrics do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      metrics = Promex.Registry.export()
      
      # Record export performance
      duration = System.monotonic_time(:millisecond) - start_time
      metric_count = count_metrics(metrics)
      
      :telemetry.execute(
        [:beamops, :promex, :metrics, :exported],
        %{count: metric_count, duration: duration},
        %{format: :prometheus}
      )
      
      metrics
    rescue
      error ->
        Logger.error("Failed to export Promex metrics: #{inspect(error)}")
        
        :telemetry.execute(
          [:beamops, :promex, :metrics, :export_failed],
          %{duration: System.monotonic_time(:millisecond) - start_time},
          %{error: inspect(error)}
        )
        
        ""
    end
  end

  @doc """
  Returns current coordination efficiency metrics.
  
  Calculates and returns real-time coordination efficiency based on
  agent performance, work completion rates, and system health.
  """
  @spec coordination_efficiency() :: map()
  def coordination_efficiency do
    try do
      # Get current metric values from registry
      agent_metrics = get_agent_metrics()
      work_metrics = get_work_metrics()
      system_metrics = get_system_health_metrics()
      
      # Calculate efficiency ratios
      work_completion_rate = calculate_work_completion_rate(work_metrics)
      agent_utilization = calculate_agent_utilization(agent_metrics)
      system_health_factor = calculate_system_health_factor(system_metrics)
      
      # Overall efficiency calculation (weighted)
      overall_efficiency = 
        (work_completion_rate * 0.4 + 
         agent_utilization * 0.35 + 
         system_health_factor * 0.25)
        |> max(0.0)
        |> min(1.0)
      
      %{
        overall_efficiency: overall_efficiency,
        work_completion_rate: work_completion_rate,
        agent_utilization: agent_utilization,
        system_health_factor: system_health_factor,
        timestamp: System.system_time(:millisecond)
      }
    rescue
      error ->
        Logger.warn("Error calculating coordination efficiency: #{inspect(error)}")
        %{error: "calculation_failed", timestamp: System.system_time(:millisecond)}
    end
  end

  ## Private Functions
  
  defp count_metrics(metrics_text) do
    metrics_text
    |> String.split("\n")
    |> Enum.count(fn line -> 
      String.starts_with?(line, "beamops_") and not String.starts_with?(line, "# ")
    end)
  end
  
  defp get_agent_metrics do
    # Extract agent-related metrics from registry
    try do
      Registry.get_sample(:beamops_agent_work_completed_total) || %{}
    rescue
      _ -> %{}
    end
  end
  
  defp get_work_metrics do
    # Extract work-related metrics from registry
    try do
      completed = Registry.get_sample(:beamops_agent_work_completed_total) || %{}
      failed = Registry.get_sample(:beamops_agent_work_failed_total) || %{}
      %{completed: completed, failed: failed}
    rescue
      _ -> %{completed: %{}, failed: %{}}
    end
  end
  
  defp get_system_health_metrics do
    # Extract system health metrics from registry
    try do
      Registry.get_sample(:beamops_system_health_score) || %{}
    rescue
      _ -> %{}
    end
  end
  
  defp calculate_work_completion_rate(work_metrics) do
    completed = map_size(work_metrics.completed)
    failed = map_size(work_metrics.failed)
    total = completed + failed
    
    if total > 0 do
      completed / total
    else
      0.0
    end
  end
  
  defp calculate_agent_utilization(agent_metrics) do
    # Simple agent utilization based on work completion
    active_agents = map_size(agent_metrics)
    
    # Assume ideal agent count and calculate utilization
    ideal_agent_count = Application.get_env(:beamops, :ideal_agent_count, 10)
    
    if ideal_agent_count > 0 do
      min(active_agents / ideal_agent_count, 1.0)
    else
      0.0
    end
  end
  
  defp calculate_system_health_factor(system_metrics) do
    # Calculate average system health across components
    if map_size(system_metrics) > 0 do
      health_scores = Map.values(system_metrics)
      average_health = Enum.sum(health_scores) / length(health_scores)
      average_health / 100.0  # Convert to 0-1 ratio
    else
      0.5  # Default neutral health
    end
  end
end