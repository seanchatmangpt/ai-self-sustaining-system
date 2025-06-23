defmodule SelfSustaining.ReactorSteps.Telemetry.CollectionStep do
  @moduledoc """
  Reactor step for collecting comprehensive system telemetry data.

  This step implements a simplified telemetry collection process suitable for testing
  and development environments. It gathers system metrics, OpenTelemetry spans,
  coordination data, and SPR operation statistics into a unified telemetry report.

  ## Step Implementation

  Implements the Reactor step behavior with:
  - **`run/3`**: Collects telemetry data from various system components
  - **`compensate/4`**: Provides compensation logic for error recovery

  ## Collected Data

  The step collects the following telemetry categories:

  ### System Metrics
  - **Memory Usage**: Total memory consumption in MB
  - **Process Count**: Number of active system processes  
  - **CPU Usage**: Current CPU utilization percentage
  - **Uptime**: System uptime in seconds

  ### OpenTelemetry Data
  - **Spans**: Distributed tracing spans (empty in test implementation)
  - **Trace Context**: Generated trace ID for correlation

  ### Coordination Data
  - **Agent Status**: Agent coordination state (empty in test implementation)
  - **Work Claims**: Active work assignments

  ### SPR Operations
  - **Compression Count**: Total SPR compression operations
  - **Decompression Count**: Total SPR decompression operations

  ## Usage in Reactor Workflows

      step :collect_telemetry, SelfSustaining.ReactorSteps.Telemetry.CollectionStep do
        argument :time_window, input(:window_seconds)
      end

  ## Test Implementation Notes

  This is a simplified implementation designed for testing. Production implementations
  should integrate with actual telemetry systems, databases, and monitoring infrastructure.

  ## Return Format

  Returns a structured map containing:
  ```elixir
  %{
    time_range: %{start: DateTime, end: DateTime, window_seconds: integer},
    spans: [OpenTelemetry.Span.t()],
    system_metrics: map(),
    coordination_data: map(),
    spr_data: map(),
    collection_timestamp: DateTime.t(),
    trace_id: String.t()
  }
  ```
  """

  @doc """
  Executes the telemetry collection step in a Reactor workflow.

  Collects comprehensive system telemetry including metrics, spans, coordination data,
  and SPR operation statistics. This is a simplified test implementation that returns
  mock data suitable for development and testing scenarios.

  ## Parameters

  - `inputs` - Input arguments from previous Reactor steps (unused in current implementation)
  - `_context` - Reactor execution context containing trace IDs and metadata
  - `_options` - Step configuration options

  ## Returns

  `{:ok, telemetry_data}` where `telemetry_data` contains:

  - **time_range**: Collection time window with start/end timestamps
  - **spans**: OpenTelemetry spans (empty in test implementation)
  - **system_metrics**: Memory, CPU, process count, and uptime data
  - **coordination_data**: Agent coordination state (empty in test implementation)
  - **spr_data**: SPR compression/decompression operation counts
  - **collection_timestamp**: When the data was collected
  - **trace_id**: Generated trace ID for distributed tracing correlation
  """
  def run(inputs, context, _options) do
    # Enhanced implementation with real coordination data integration
    trace_id = Map.get(context, :trace_id, "reactor_trace_#{System.system_time(:nanosecond)}")

    # Read real coordination data
    coordination_data = collect_real_coordination_data()
    system_metrics = collect_enhanced_system_metrics()

    # Create OpenTelemetry span for this collection
    span_data = %{
      "trace_id" => trace_id,
      "span_id" => generate_span_id(),
      "operation_name" => "telemetry.collection.reactor_step",
      "span_kind" => "internal",
      "status" => "ok",
      "start_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "service" => %{
        "name" => "self_sustaining_phoenix",
        "version" => "0.1.0"
      },
      "span_attributes" => %{
        "telemetry.collection.type" => "reactor_step",
        "coordination.agents_active" => Map.get(coordination_data, :agents_active, 0),
        "coordination.work_items" => Map.get(coordination_data, :work_items, 0),
        "system.memory_mb" => Map.get(system_metrics, :memory_mb, 0)
      }
    }

    # Log telemetry span for correlation
    log_telemetry_span(span_data)

    result = %{
      time_range: %{
        start: DateTime.utc_now() |> DateTime.add(-300, :second),
        end: DateTime.utc_now(),
        window_seconds: 300
      },
      spans: [span_data],
      system_metrics: system_metrics,
      coordination_data: coordination_data,
      spr_data: %{
        total_compressions: get_spr_compressions(),
        total_decompressions: get_spr_decompressions()
      },
      collection_timestamp: DateTime.utc_now(),
      trace_id: trace_id,
      correlation_metadata: %{
        coordination_trace_correlation: true,
        business_value_correlation: true,
        reactor_workflow_correlation: true
      }
    }

    {:ok, result}
  end

  # Collect real coordination system data
  defp collect_real_coordination_data do
    try do
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

      agents_data =
        case File.read(agent_status_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, agents} when is_list(agents) -> agents
              _ -> []
            end

          _ ->
            []
        end

      work_data =
        case File.read(coordination_log_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, work_items} when is_list(work_items) -> work_items
              _ -> []
            end

          _ ->
            []
        end

      %{
        agents_active: length(agents_data),
        # Latest 5 for correlation
        agents_data: agents_data |> Enum.take(5),
        work_items: length(work_data),
        # Recent 10 completions
        recent_completions: work_data |> Enum.take(-10),
        velocity_points:
          work_data |> Enum.take(-10) |> Enum.map(& &1["velocity_points"]) |> Enum.sum(),
        coordination_health: calculate_coordination_health(agents_data, work_data)
      }
    rescue
      _ ->
        %{
          agents_active: 0,
          work_items: 0,
          coordination_health: "unknown"
        }
    end
  end

  # Enhanced system metrics collection
  defp collect_enhanced_system_metrics do
    memory_info = :erlang.memory()

    %{
      memory_mb: div(memory_info[:total], 1_048_576),
      process_count: :erlang.system_info(:process_count),
      cpu_usage: get_cpu_usage(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      memory_details: %{
        processes: div(memory_info[:processes], 1_048_576),
        system: div(memory_info[:system], 1_048_576),
        atom: div(memory_info[:atom], 1_048_576),
        ets: div(memory_info[:ets], 1_048_576)
      }
    }
  end

  # Calculate coordination system health score
  defp calculate_coordination_health(agents_data, work_data) do
    case {length(agents_data), length(work_data)} do
      {0, _} -> "no_agents"
      {_, 0} -> "no_work_history"
      {agents, work} when agents > 0 and work > 0 -> "healthy"
      _ -> "unknown"
    end
  end

  # Generate OpenTelemetry span ID
  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # Get CPU usage (simplified)
  defp get_cpu_usage do
    case :cpu_sup.util() do
      {:error, _} -> 0.0
      usage when is_number(usage) -> usage / 100.0
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  # Get SPR compression count
  defp get_spr_compressions do
    # Could integrate with actual SPR metrics if available
    5
  end

  # Get SPR decompression count  
  defp get_spr_decompressions do
    # Could integrate with actual SPR metrics if available
    3
  end

  # Log telemetry span for trace correlation
  defp log_telemetry_span(span_data) do
    try do
      telemetry_path =
        Path.join([
          Application.app_dir(:self_sustaining, ".."),
          "..",
          "agent_coordination",
          "telemetry_spans.jsonl"
        ])

      span_json = Jason.encode!(span_data)
      File.write(telemetry_path, span_json <> "\n", [:append])
    rescue
      _ -> :ok
    end
  end

  @doc """
  Compensation function for telemetry collection step error recovery.

  Called by Reactor when the telemetry collection step fails and needs to be
  compensated. In this simple implementation, compensation is a no-op since
  telemetry collection is generally safe and doesn't require rollback.

  ## Parameters

  - `_reason` - The reason for compensation (error that occurred)
  - `_inputs` - Original inputs to the failed step
  - `_context` - Reactor execution context
  - `_options` - Step configuration options

  ## Returns

  `:ok` - Compensation completed successfully
  """
  def compensate(_reason, _inputs, _context, _options) do
    # No compensation needed for telemetry collection in test implementation
    :ok
  end
end
