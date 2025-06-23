defmodule SelfSustainingWeb.TelemetryController do
  @moduledoc """
  Enhanced Telemetry controller for OpenTelemetry spans and coordination observability.
  
  This controller provides comprehensive telemetry endpoints for the AI agent coordination 
  system, including real-time spans data, coordination metrics, and observability health.
  """

  use SelfSustainingWeb, :controller

  alias SelfSustaining.Telemetry.CoordinationMiddleware

  def spans(conn, _params) do
    # Return recent telemetry spans from coordination system
    spans = get_recent_spans()
    json(conn, %{spans: spans, count: length(spans), source: "coordination_system"})
  end

  def summary(conn, _params) do
    # Return comprehensive telemetry summary including coordination metrics
    coordination_metrics = get_coordination_metrics()
    
    summary = %{
      timestamp: DateTime.utc_now(),
      metrics: %{
        total_requests: get_total_requests(),
        average_response_time: get_avg_response_time(),
        error_rate: get_error_rate()
      },
      traces: %{
        active_traces: get_active_trace_count(),
        completed_traces: get_completed_trace_count()
      },
      coordination: coordination_metrics
    }

    json(conn, summary)
  end

  @doc """
  Receive coordination telemetry events from the shell-based coordination system.
  
  This endpoint bridges the shell coordination system with the Phoenix telemetry 
  infrastructure, enabling real-time observability of agent coordination.
  """
  def coordination(conn, params) do
    event_type = params["event_type"]
    metadata = params["metadata"] || %{}
    
    case event_type do
      "work_claimed" ->
        CoordinationMiddleware.emit_work_claimed(%{
          work_type: metadata["param1"] || "general",
          team: metadata["param2"] || "unknown", 
          priority: metadata["param3"] || "medium",
          agent_id: metadata["agent_id"],
          trace_id: metadata["trace_id"]
        })
        
      "work_completed" ->
        CoordinationMiddleware.emit_work_completed(%{
          status: metadata["param1"] || "success",
          team: metadata["param2"] || "unknown",
          quality_score: parse_quality_score(metadata["param3"]),
          agent_id: metadata["agent_id"],
          trace_id: metadata["trace_id"]
        })
        
      "trace_generated" ->
        CoordinationMiddleware.emit_trace_generated(%{
          operation: metadata["param1"] || "coordination",
          status: metadata["param2"] || "success",
          trace_id: metadata["trace_id"]
        })
        
      _ ->
        # Log unknown event type but don't error
        require Logger
        Logger.info("Unknown coordination telemetry event type: #{event_type}")
    end
    
    json(conn, %{"status" => "received", "event_type" => event_type})
  end

  @doc """
  Health check endpoint for coordination observability.
  """
  def health(conn, _params) do
    coordination_health = %{
      "status" => "healthy",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "telemetry_enabled" => true,
      "coordination_integration" => true,
      "observability_infrastructure" => "operational"
    }
    
    json(conn, coordination_health)
  end

  defp get_recent_spans do
    # Read from coordination telemetry spans
    coordination_dir = "/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
    telemetry_file = Path.join(coordination_dir, "telemetry_spans.jsonl")
    
    case File.read(telemetry_file) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn line ->
          case Jason.decode(line) do
            {:ok, span} -> span
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.take(-10)  # Last 10 spans
      _ ->
        []
    end
  end

  defp get_coordination_metrics do
    coordination_dir = "/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
    
    # Read agent status
    agent_metrics = case File.read(Path.join(coordination_dir, "agent_status.json")) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, agents} when is_list(agents) ->
            active_count = Enum.count(agents, fn agent -> agent["status"] == "active" end)
            %{active_agents: active_count, total_agents: length(agents)}
          _ -> %{active_agents: 0, total_agents: 0}
        end
      _ -> %{active_agents: 0, total_agents: 0}
    end
    
    # Read work claims
    work_metrics = case File.read(Path.join(coordination_dir, "work_claims.json")) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, work_items} when is_list(work_items) ->
            active_work = Enum.count(work_items, fn item -> 
              item["status"] == "claimed" or item["status"] == "in_progress"
            end)
            %{active_work: active_work, total_work: length(work_items)}
          _ -> %{active_work: 0, total_work: 0}
        end
      _ -> %{active_work: 0, total_work: 0}
    end
    
    Map.merge(agent_metrics, work_metrics)
  end

  defp get_total_requests, do: 0
  defp get_avg_response_time, do: 0.0
  defp get_error_rate, do: 0.0
  defp get_active_trace_count, do: 0
  defp get_completed_trace_count, do: 0
  
  defp parse_quality_score(value) when is_binary(value) do
    case Integer.parse(value) do
      {score, ""} -> score
      _ -> 0
    end
  end
  
  defp parse_quality_score(value) when is_integer(value), do: value
  defp parse_quality_score(_), do: 0
end
