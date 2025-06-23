defmodule SelfSustaining.PromEx.CoordinationPlugin do
  @moduledoc """
  PromEx Plugin for Agent Coordination Performance Monitoring

  Specialized PromEx plugin that provides comprehensive metrics for the AI agent
  coordination system, integrating with coordination_helper.sh and providing
  real-time performance visibility.

  This plugin follows Engineering Elixir Applications patterns and provides
  metrics that complement the existing OpenTelemetry infrastructure.

  ## Metrics Provided

  ### Coordination Operations
  - `self_sustaining_coordination_operations_total` - Total coordination operations by type
  - `self_sustaining_coordination_duration_seconds` - Operation execution time distribution
  - `self_sustaining_coordination_efficiency_ratio` - Real-time efficiency calculation
  - `self_sustaining_coordination_errors_total` - Error count by operation type

  ### Work Management
  - `self_sustaining_work_claims_total` - Work claims by agent and type
  - `self_sustaining_work_completions_total` - Work completions by result
  - `self_sustaining_work_queue_size` - Current work queue depth
  - `self_sustaining_work_cycle_time_seconds` - Complete work cycle timing

  ### Agent Performance
  - `self_sustaining_agent_capacity_ratio` - Agent capacity utilization
  - `self_sustaining_agent_response_time_seconds` - Agent response time distribution
  - `self_sustaining_team_coordination_score` - Team coordination effectiveness
  - `self_sustaining_handoff_success_ratio` - Context handoff success rate

  ## Integration

  This plugin integrates with:
  - Agent coordination system (coordination_helper.sh)
  - OpenTelemetry traces (maintains trace context)
  - Phoenix telemetry events
  - Business intelligence metrics
  """

  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :self_sustaining_coordination_event_metrics,
      [
        # Coordination Operations
        counter(
          "self_sustaining_coordination_operations_total",
          event_name: [:prom_ex, :plugin, :self_sustaining_coordination_operations, :inc],
          description: "Total number of coordination operations executed",
          tags: [:operation_type, :agent_id, :team, :status],
          tag_values: &get_coordination_operation_tags/1
        ),
        distribution(
          "self_sustaining_coordination_duration_seconds",
          event_name: [:prom_ex, :plugin, :self_sustaining_coordination_duration, :observe],
          description: "Coordination operation execution time distribution",
          measurement: :duration,
          tags: [:operation_type, :team],
          tag_values: &get_coordination_duration_tags/1,
          buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
        ),
        last_value(
          "self_sustaining_coordination_efficiency_ratio",
          event_name: [:prom_ex, :plugin, :self_sustaining_coordination_efficiency, :set],
          description: "Real-time coordination efficiency ratio (0-1)",
          measurement: :efficiency,
          tags: [:calculation_source],
          tag_values: fn _metadata -> %{calculation_source: "real_time"} end
        ),
        counter(
          "self_sustaining_coordination_errors_total",
          event_name: [:prom_ex, :plugin, :self_sustaining_coordination_errors, :inc],
          description: "Total coordination errors by type",
          tags: [:error_type, :operation_type, :agent_id],
          tag_values: &get_coordination_error_tags/1
        ),

        # Work Management Metrics
        counter(
          "self_sustaining_work_claims_total",
          event_name: [:prom_ex, :plugin, :self_sustaining_work_claims, :inc],
          description: "Total work claims by agent and type",
          tags: [:agent_id, :work_type, :priority, :team],
          tag_values: &get_work_claim_tags/1
        ),
        counter(
          "self_sustaining_work_completions_total",
          event_name: [:prom_ex, :plugin, :self_sustaining_work_completions, :inc],
          description: "Total work completions by result",
          tags: [:agent_id, :work_type, :result, :team],
          tag_values: &get_work_completion_tags/1
        ),
        last_value(
          "self_sustaining_work_queue_size",
          event_name: [:prom_ex, :plugin, :self_sustaining_work_queue, :set],
          description: "Current work queue depth",
          measurement: :queue_size,
          tags: [:queue_type, :priority],
          tag_values: &get_work_queue_tags/1
        ),
        distribution(
          "self_sustaining_work_cycle_time_seconds",
          event_name: [:prom_ex, :plugin, :self_sustaining_work_cycle_time, :observe],
          description: "Complete work cycle timing from claim to completion",
          measurement: :cycle_time,
          tags: [:work_type, :complexity, :team],
          tag_values: &get_work_cycle_tags/1,
          buckets: [1, 5, 15, 30, 60, 300, 900, 1800, 3600]
        ),

        # Agent Performance Metrics
        last_value(
          "self_sustaining_agent_capacity_ratio",
          event_name: [:prom_ex, :plugin, :self_sustaining_agent_capacity, :set],
          description: "Agent capacity utilization ratio (0-1)",
          measurement: :capacity,
          tags: [:agent_id, :team, :specialization],
          tag_values: &get_agent_capacity_tags/1
        ),
        distribution(
          "self_sustaining_agent_response_time_seconds",
          event_name: [:prom_ex, :plugin, :self_sustaining_agent_response_time, :observe],
          description: "Agent response time distribution",
          measurement: :response_time,
          tags: [:agent_id, :operation_type, :team],
          tag_values: &get_agent_response_tags/1,
          buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0]
        ),
        last_value(
          "self_sustaining_team_coordination_score",
          event_name: [:prom_ex, :plugin, :self_sustaining_team_coordination, :set],
          description: "Team coordination effectiveness score (0-100)",
          measurement: :coordination_score,
          tags: [:team, :metric_type],
          tag_values: &get_team_coordination_tags/1
        ),
        last_value(
          "self_sustaining_handoff_success_ratio",
          event_name: [:prom_ex, :plugin, :self_sustaining_handoff_success, :set],
          description: "Context handoff success ratio (0-1)",
          measurement: :success_ratio,
          tags: [:from_agent, :to_agent, :handoff_type],
          tag_values: &get_handoff_tags/1
        ),

        # Business Value Metrics
        counter(
          "self_sustaining_business_value_delivered_total",
          event_name: [:prom_ex, :plugin, :self_sustaining_business_value, :inc],
          description: "Total business value delivered by agents",
          measurement: :value,
          tags: [:value_type, :agent_id, :work_type, :team],
          tag_values: &get_business_value_tags/1
        )
      ]
    )
  end

  @impl true
  def polling_metrics(_opts) do
    # Return empty list to disable polling metrics for now
    []
  end

  ## Tag Value Functions

  defp get_coordination_operation_tags(%{labels: labels}) do
    %{
      operation_type: Map.get(labels, :operation_type, "unknown"),
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      team: Map.get(labels, :team, "default"),
      status: Map.get(labels, :status, "unknown")
    }
  end

  defp get_coordination_duration_tags(%{labels: labels}) do
    %{
      operation_type: Map.get(labels, :operation_type, "unknown"),
      team: Map.get(labels, :team, "default")
    }
  end

  defp get_coordination_error_tags(%{labels: labels}) do
    %{
      error_type: Map.get(labels, :error_type, "unknown"),
      operation_type: Map.get(labels, :operation_type, "unknown"),
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown"))
    }
  end

  defp get_work_claim_tags(%{labels: labels}) do
    %{
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      work_type: Map.get(labels, :work_type, "general"),
      priority: Map.get(labels, :priority, "medium"),
      team: Map.get(labels, :team, "default")
    }
  end

  defp get_work_completion_tags(%{labels: labels}) do
    %{
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      work_type: Map.get(labels, :work_type, "general"),
      result: Map.get(labels, :result, "success"),
      team: Map.get(labels, :team, "default")
    }
  end

  defp get_work_queue_tags(_metadata) do
    %{
      queue_type: "coordination",
      priority: "mixed"
    }
  end

  defp get_work_cycle_tags(%{labels: labels}) do
    %{
      work_type: Map.get(labels, :work_type, "general"),
      complexity: Map.get(labels, :complexity, "medium"),
      team: Map.get(labels, :team, "default")
    }
  end

  defp get_agent_capacity_tags(%{labels: labels}) do
    %{
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      team: Map.get(labels, :team, "default"),
      specialization: Map.get(labels, :specialization, "general")
    }
  end

  defp get_agent_response_tags(%{labels: labels}) do
    %{
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      operation_type: Map.get(labels, :operation_type, "unknown"),
      team: Map.get(labels, :team, "default")
    }
  end

  defp get_team_coordination_tags(%{labels: labels}) do
    %{
      team: Map.get(labels, :team, "default"),
      metric_type: Map.get(labels, :metric_type, "efficiency")
    }
  end

  defp get_handoff_tags(%{labels: labels}) do
    %{
      from_agent: sanitize_agent_id(Map.get(labels, :from_agent, "unknown")),
      to_agent: sanitize_agent_id(Map.get(labels, :to_agent, "unknown")),
      handoff_type: Map.get(labels, :handoff_type, "context")
    }
  end

  defp get_business_value_tags(%{labels: labels}) do
    %{
      value_type: Map.get(labels, :value_type, "feature"),
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      work_type: Map.get(labels, :work_type, "general"),
      team: Map.get(labels, :team, "default")
    }
  end

  defp get_agent_registration_tags(%{labels: labels}) do
    %{
      agent_id: sanitize_agent_id(Map.get(labels, :agent_id, "unknown")),
      team: Map.get(labels, :team, "default"),
      specialization: Map.get(labels, :specialization, "general")
    }
  end

  ## Polling Function

  def execute_polling do
    try do
      # Read current agent status for real-time metrics
      agent_status_path =
        Path.join([
          Application.app_dir(:self_sustaining, ".."),
          "..",
          "agent_coordination",
          "agent_status.json"
        ])

      coordination_log_path =
        Path.join([
          Application.app_dir(:self_sustaining, ".."),
          "..",
          "agent_coordination",
          "coordination_log.json"
        ])

      # Emit agent capacity metrics
      if File.exists?(agent_status_path) do
        case File.read!(agent_status_path) |> Jason.decode() do
          {:ok, agents} when is_list(agents) ->
            for agent <- agents do
              :telemetry.execute(
                [:prom_ex, :plugin, :self_sustaining_agent_capacity, :set],
                %{capacity: agent["capacity"] || 100},
                %{
                  agent_id: agent["agent_id"] || "unknown",
                  team: agent["team"] || "default",
                  specialization: agent["specialization"] || "general"
                }
              )
            end

          _ ->
            :ok
        end
      end

      # Emit coordination velocity metrics
      if File.exists?(coordination_log_path) do
        case File.read!(coordination_log_path) |> Jason.decode() do
          {:ok, work_items} when is_list(work_items) ->
            recent_work = work_items |> Enum.take(-10)
            total_velocity = recent_work |> Enum.map(& &1["velocity_points"]) |> Enum.sum()

            :telemetry.execute(
              [:prom_ex, :plugin, :self_sustaining_business_value, :set],
              %{velocity_points: total_velocity},
              %{value_type: "coordination", work_type: "system"}
            )

          _ ->
            :ok
        end
      end

      :ok
    rescue
      e ->
        # Log error but don't crash metrics collection
        require Logger
        Logger.warning("PromEx coordination polling error: #{inspect(e)}")
        :ok
    end
  end

  ## Utility Functions

  defp sanitize_agent_id(agent_id) do
    # Sanitize agent ID to prevent cardinality explosion
    case agent_id do
      "agent_" <> _timestamp -> "agent_" <> String.slice(agent_id, -8, 8)
      id when is_binary(id) -> String.slice(id, 0, 20)
      _ -> "unknown"
    end
  end
end
