defmodule SelfSustaining.PromEx do
  @moduledoc """
  Phoenix Application PromEx Integration for AI Self-Sustaining System

  Comprehensive Prometheus metrics implementation following Engineering Elixir Applications
  patterns, specifically designed for the AI Self-Sustaining System with enhanced
  coordination performance monitoring.

  Integrates with existing OpenTelemetry infrastructure to provide:
  - Coordination system performance metrics
  - AI agent workflow telemetry
  - Business value tracking
  - System health monitoring
  - Custom Phoenix application metrics

  ## Metric Categories

  ### Coordination Performance Metrics
  - `self_sustaining_coordination_operations_total` - Coordination operations by type
  - `self_sustaining_coordination_duration_seconds` - Operation execution time
  - `self_sustaining_coordination_efficiency_ratio` - Real-time efficiency calculation
  - `self_sustaining_agent_utilization_ratio` - Agent capacity utilization

  ### AI Workflow Metrics
  - `self_sustaining_reactor_workflows_total` - Reactor workflow executions
  - `self_sustaining_reactor_step_duration_seconds` - Individual workflow step timing
  - `self_sustaining_ai_operations_total` - AI-specific operations (Claude integration)
  - `self_sustaining_workflow_success_ratio` - Workflow success rates

  ### Business Intelligence Metrics
  - `self_sustaining_business_value_delivered` - Quantified business value
  - `self_sustaining_feature_adoption_ratio` - Feature usage tracking
  - `self_sustaining_system_reliability_score` - Overall system reliability
  - `self_sustaining_user_satisfaction_score` - User experience metrics

  ### Phoenix Application Metrics
  - Enhanced HTTP request metrics with coordination context
  - LiveView performance with AI workflow correlation
  - Database operation metrics with telemetry integration
  - Custom Phoenix telemetry events

  ## Usage

      # Start PromEx with AI Self-Sustaining configuration
      {:ok, _} = SelfSustaining.PromEx.start_link()

      # Record coordination performance metric
      SelfSustaining.PromEx.record_coordination_metric(:operation_completed, %{
        operation_type: "work_claim",
        agent_id: "agent_1750056221402372000",
        duration: 126,
        team: "observability_team"
      })

      # Get real-time efficiency metrics
      efficiency = SelfSustaining.PromEx.coordination_efficiency()

  ## Integration with Existing Systems

  This PromEx configuration integrates seamlessly with:
  - OpenTelemetry distributed tracing (maintains trace context)
  - Agent coordination system (coordination_helper.sh metrics)
  - Reactor workflow telemetry (middleware integration)
  - Phoenix LiveDashboard (enhanced dashboards)
  - Grafana dashboards (custom visualization)
  """

  use PromEx, otp_app: :self_sustaining

  alias PromEx.Plugins
  require Logger

  @impl true
  def plugins do
    [
      # Standard PromEx plugins
      Plugins.Application,
      Plugins.Beam,
      # Plugins.Phoenix,  # Temporarily disabled due to configuration issue
      # Plugins.Ecto,     # Temporarily disabled  
      # Plugins.Oban,     # Temporarily disabled

      # Custom AI Self-Sustaining plugins
      SelfSustaining.PromEx.CoordinationPlugin
      # SelfSustaining.PromEx.ReactorPlugin,              # Temporarily disabled
      # SelfSustaining.PromEx.BusinessIntelligencePlugin  # Temporarily disabled
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
      # Standard PromEx dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"},

      # Custom AI Self-Sustaining dashboards
      {:self_sustaining, "grafana_dashboards/coordination_performance.json"},
      {:self_sustaining, "grafana_dashboards/reactor_workflows.json"},
      {:self_sustaining, "grafana_dashboards/business_intelligence.json"}
    ]
  end

  @doc """
  Records coordination performance metrics with enhanced telemetry integration.

  This function provides comprehensive coordination metrics that integrate with
  the existing agent coordination system and OpenTelemetry infrastructure.

  ## Metric Types

  ### Coordination Operations
  - `:operation_completed` - When a coordination operation completes
  - `:work_claimed` - When an agent claims work
  - `:work_progress` - When work progress is updated
  - `:work_completed` - When work is completed
  - `:coordination_cycle` - Full coordination cycle completion

  ### Agent Performance
  - `:agent_registered` - Agent registration events
  - `:agent_capacity_update` - Agent capacity changes
  - `:team_formation` - Team formation events
  - `:handoff_completed` - Context handoff completion

  ### System Health
  - `:health_check` - System health check results
  - `:performance_degradation` - Performance issue detection
  - `:recovery_completed` - System recovery events
  - `:efficiency_calculation` - Real-time efficiency updates

  ## Examples

      # Coordination operation completion
      SelfSustaining.PromEx.record_coordination_metric(:operation_completed, %{
        operation_type: "work_claim",
        agent_id: "agent_1750056221402372000",
        duration: 126,
        team: "observability_team",
        trace_id: "98dc729e7d6f3d4a8e957e28ca6b0e92"
      })

      # Agent performance tracking
      SelfSustaining.PromEx.record_coordination_metric(:agent_registered, %{
        agent_id: "agent_1750056221402372000",
        team: "observability_team",
        capacity: 100,
        specialization: "promex_integration"
      })

      # System health monitoring
      SelfSustaining.PromEx.record_coordination_metric(:health_check, %{
        component: "coordination_system",
        health_score: 95,
        checks_passed: 23,
        checks_failed: 1,
        response_time: 45
      })
  """
  @spec record_coordination_metric(atom(), map()) :: :ok
  def record_coordination_metric(metric_type, metadata)
      when is_atom(metric_type) and is_map(metadata) do
    timestamp = System.system_time(:millisecond)
    trace_id = Map.get(metadata, :trace_id, generate_trace_id())

    case metric_type do
      # Coordination Operation Metrics
      :operation_completed ->
        labels = %{
          operation_type: Map.get(metadata, :operation_type, "unknown"),
          agent_id: Map.get(metadata, :agent_id, "unknown"),
          team: Map.get(metadata, :team, "default"),
          status: Map.get(metadata, :status, "success")
        }

        # Increment operation counter
        :telemetry.execute(
          [:prom_ex, :plugin, :self_sustaining_coordination_operations, :inc],
          %{},
          %{labels: labels}
        )

        # Record duration if provided
        if duration = Map.get(metadata, :duration) do
          :telemetry.execute(
            [:prom_ex, :plugin, :self_sustaining_coordination_duration, :observe],
            %{duration: duration / 1000},
            %{labels: labels}
          )
        end

      :work_claimed ->
        labels = %{
          agent_id: Map.get(metadata, :agent_id, "unknown"),
          work_type: Map.get(metadata, :work_type, "general"),
          priority: Map.get(metadata, :priority, "medium"),
          team: Map.get(metadata, :team, "default")
        }

        :telemetry.execute(
          [:prom_ex, :plugin, :self_sustaining_work_claims, :inc],
          %{},
          %{labels: labels}
        )

      :work_completed ->
        labels = %{
          agent_id: Map.get(metadata, :agent_id, "unknown"),
          work_type: Map.get(metadata, :work_type, "general"),
          result: Map.get(metadata, :result, "success"),
          team: Map.get(metadata, :team, "default")
        }

        :telemetry.execute(
          [:prom_ex, :plugin, :self_sustaining_work_completions, :inc],
          %{},
          %{labels: labels}
        )

        # Record business value if provided
        if business_value = Map.get(metadata, :business_value) do
          :telemetry.execute(
            [:prom_ex, :plugin, :self_sustaining_business_value, :inc],
            %{value: business_value},
            %{labels: labels}
          )
        end

      # Agent Performance Metrics
      :agent_registered ->
        labels = %{
          agent_id: Map.get(metadata, :agent_id, "unknown"),
          team: Map.get(metadata, :team, "default"),
          specialization: Map.get(metadata, :specialization, "general")
        }

        :telemetry.execute(
          [:prom_ex, :plugin, :self_sustaining_agent_registrations, :inc],
          %{},
          %{labels: labels}
        )

        if capacity = Map.get(metadata, :capacity) do
          :telemetry.execute(
            [:prom_ex, :plugin, :self_sustaining_agent_capacity, :set],
            %{capacity: capacity},
            %{labels: labels}
          )
        end

      # System Health Metrics
      :health_check ->
        component = Map.get(metadata, :component, "system")
        health_score = Map.get(metadata, :health_score, 50)

        labels = %{component: component}

        :telemetry.execute(
          [:prom_ex, :plugin, :self_sustaining_health_score, :set],
          %{score: health_score},
          %{labels: labels}
        )

        if response_time = Map.get(metadata, :response_time) do
          :telemetry.execute(
            [:prom_ex, :plugin, :self_sustaining_health_response_time, :observe],
            %{duration: response_time / 1000},
            %{labels: labels}
          )
        end

      _ ->
        Logger.warning("Unknown coordination metric type: #{metric_type}")
        :ok
    end

    # Emit OpenTelemetry event for metric recording with trace correlation
    :telemetry.execute(
      [:self_sustaining, :promex, :coordination_metric, :recorded],
      %{timestamp: timestamp},
      %{
        metric_type: metric_type,
        metadata: metadata,
        trace_id: trace_id,
        otel_trace_id: System.get_env("OTEL_TRACE_ID")
      }
    )

    :ok
  end

  @doc """
  Calculates real-time coordination efficiency metrics.

  Integrates with the coordination_helper.sh system to provide comprehensive
  efficiency analysis based on agent performance, work completion rates,
  and system health indicators.

  Returns efficiency metrics correlated with OpenTelemetry traces for
  enhanced observability.
  """
  @spec coordination_efficiency() :: map()
  def coordination_efficiency do
    trace_id = generate_trace_id()
    start_time = System.monotonic_time(:millisecond)

    try do
      # Get coordination metrics from agent coordination system
      coordination_metrics = get_coordination_metrics()
      agent_metrics = get_agent_performance_metrics()
      system_health = get_system_health_metrics()

      # Calculate efficiency components
      work_completion_rate = calculate_work_completion_rate(coordination_metrics)
      agent_utilization = calculate_agent_utilization(agent_metrics)
      system_reliability = calculate_system_reliability(system_health)

      # Weighted efficiency calculation
      overall_efficiency =
        (work_completion_rate * 0.4 +
           agent_utilization * 0.35 +
           system_reliability * 0.25)
        |> max(0.0)
        |> min(1.0)

      duration = System.monotonic_time(:millisecond) - start_time

      efficiency_data = %{
        overall_efficiency: overall_efficiency,
        work_completion_rate: work_completion_rate,
        agent_utilization: agent_utilization,
        system_reliability: system_reliability,
        calculation_duration_ms: duration,
        timestamp: System.system_time(:millisecond),
        trace_id: trace_id
      }

      # Record efficiency metric
      :telemetry.execute(
        [:prom_ex, :plugin, :self_sustaining_coordination_efficiency, :set],
        %{efficiency: overall_efficiency},
        %{calculation_duration: duration}
      )

      # Emit telemetry event for efficiency calculation
      :telemetry.execute(
        [:self_sustaining, :coordination, :efficiency, :calculated],
        %{efficiency: overall_efficiency, duration: duration},
        %{trace_id: trace_id, components: efficiency_data}
      )

      efficiency_data
    rescue
      error ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.error("Coordination efficiency calculation failed: #{inspect(error)}")

        :telemetry.execute(
          [:self_sustaining, :coordination, :efficiency, :calculation_failed],
          %{duration: duration},
          %{error: inspect(error), trace_id: trace_id}
        )

        %{
          error: "calculation_failed",
          error_details: inspect(error),
          timestamp: System.system_time(:millisecond),
          trace_id: trace_id
        }
    end
  end

  ## Private Functions

  defp generate_trace_id do
    # Generate OpenTelemetry compatible trace ID
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_coordination_metrics do
    # Integration with coordination_helper.sh metrics
    try do
      # Read coordination log for recent metrics
      coordination_file =
        "/Users/sac/dev/ai-self-sustaining-system/agent_coordination/coordination_log.json"

      if File.exists?(coordination_file) do
        coordination_file
        |> File.read!()
        |> Jason.decode!()
        |> Map.get("operations", [])
        # Last 100 operations
        |> Enum.take(-100)
      else
        []
      end
    rescue
      _ -> []
    end
  end

  defp get_agent_performance_metrics do
    # Integration with agent_status.json
    try do
      agent_file = "/Users/sac/dev/ai-self-sustaining-system/agent_coordination/agent_status.json"

      if File.exists?(agent_file) do
        agent_file
        |> File.read!()
        |> Jason.decode!()
        |> Map.get("agents", %{})
      else
        %{}
      end
    rescue
      _ -> %{}
    end
  end

  defp get_system_health_metrics do
    # System health indicators
    %{
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count),
      run_queue: :erlang.statistics(:run_queue),
      uptime: :erlang.statistics(:wall_clock) |> elem(0)
    }
  end

  defp calculate_work_completion_rate(coordination_metrics) do
    if length(coordination_metrics) > 0 do
      completed = Enum.count(coordination_metrics, &(&1["status"] == "completed"))
      completed / length(coordination_metrics)
    else
      0.0
    end
  end

  defp calculate_agent_utilization(agent_metrics) do
    if map_size(agent_metrics) > 0 do
      total_capacity = agent_metrics |> Map.values() |> Enum.sum()
      utilized_capacity = agent_metrics |> Map.values() |> Enum.count(&(&1 > 0))

      if total_capacity > 0 do
        utilized_capacity / map_size(agent_metrics)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_system_reliability(system_health) do
    # Simple system reliability based on health indicators
    # GB
    memory_factor = min(system_health.memory_usage / (1024 * 1024 * 1024), 1.0)
    process_factor = min(system_health.process_count / 100_000, 1.0)

    # Higher is better for reliability (inverse of resource usage)
    ((2.0 - memory_factor - process_factor) / 2.0)
    |> max(0.0)
    |> min(1.0)
  end
end
