defmodule SelfSustaining.Telemetry.CoordinationMiddleware do
  @moduledoc """
  Telemetry middleware for agent coordination events.

  This middleware emits telemetry events that are consumed by the PromEx observability
  infrastructure to provide real-time monitoring of the agent coordination system.

  Events emitted:
  - [:coordination, :work, :claimed] - When work is claimed by an agent
  - [:coordination, :work, :completed] - When work is completed by an agent  
  - [:coordination, :trace, :generated] - When OpenTelemetry traces are generated
  """

  @doc """
  Emit telemetry event for work being claimed by an agent.
  """
  def emit_work_claimed(metadata \\ %{}) do
    measurements = %{count: 1}
    
    metadata = Map.merge(%{
      team: "unknown",
      work_type: "general", 
      priority: "medium",
      timestamp: DateTime.utc_now()
    }, metadata)

    :telemetry.execute([:coordination, :work, :claimed], measurements, metadata)
  end

  @doc """
  Emit telemetry event for work being completed by an agent.
  """
  def emit_work_completed(metadata \\ %{}) do
    measurements = %{count: 1}
    
    metadata = Map.merge(%{
      team: "unknown",
      status: "success",
      quality_score: 0,
      timestamp: DateTime.utc_now()
    }, metadata)

    :telemetry.execute([:coordination, :work, :completed], measurements, metadata)
  end

  @doc """
  Emit telemetry event for OpenTelemetry trace generation.
  """
  def emit_trace_generated(metadata \\ %{}) do
    measurements = %{count: 1}
    
    metadata = Map.merge(%{
      operation: "coordination",
      status: "success",
      timestamp: DateTime.utc_now()
    }, metadata)

    :telemetry.execute([:coordination, :trace, :generated], measurements, metadata)
  end

  @doc """
  Helper function to parse coordination data from shell script operations.
  
  This function monitors the coordination files and emits telemetry events
  when changes are detected, bridging the shell-based coordination system
  with the Elixir telemetry infrastructure.
  """
  def monitor_coordination_files do
    coordination_dir = "/Users/sac/dev/ai-self-sustaining-system/agent_coordination" 
    work_claims_file = Path.join(coordination_dir, "work_claims.json")
    
    # Monitor work claims file for changes
    case File.read(work_claims_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, work_items} when is_list(work_items) ->
            # Emit telemetry for recent work items
            recent_work = Enum.filter(work_items, &is_recent_work?/1)
            
            Enum.each(recent_work, fn work_item ->
              case work_item["status"] do
                "claimed" ->
                  emit_work_claimed(%{
                    team: work_item["team"] || "unknown",
                    work_type: work_item["work_type"] || "general",
                    priority: work_item["priority"] || "medium"
                  })
                
                "completed" ->
                  emit_work_completed(%{
                    team: work_item["team"] || "unknown", 
                    status: work_item["result"] || "success",
                    quality_score: work_item["quality_score"] || 0
                  })
                
                _ -> :ok
              end
            end)
            
          _ -> :ok
        end
      _ -> :ok
    end
  end

  defp is_recent_work?(work_item) do
    # Consider work from the last 10 minutes as "recent"
    case work_item["timestamp"] do
      timestamp when is_binary(timestamp) ->
        case DateTime.from_iso8601(timestamp) do
          {:ok, work_time, _} ->
            DateTime.diff(DateTime.utc_now(), work_time, :second) < 600
          _ -> false
        end
      _ -> false
    end
  end
end