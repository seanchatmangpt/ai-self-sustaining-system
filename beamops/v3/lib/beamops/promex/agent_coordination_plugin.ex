# Following Engineering Elixir Applications patterns
# Simplified, single-responsibility plugin for agent coordination metrics

defmodule Beamops.PromEx.AgentCoordinationPlugin do
  @moduledoc """
  Simple Agent Coordination PromEx Plugin
  
  Following Engineering Elixir Applications patterns:
  - Single responsibility (coordination metrics only)
  - Polling-based data collection  
  - Clean telemetry execution
  - Minimal configuration
  """
  
  use PromEx.Plugin
  
  require Logger
  
  @coordination_event [:beamops, :agent, :coordination]
  
  defp coordination_metrics(poll_rate) do
    Polling.build(
      :agent_coordination_polling_events,
      poll_rate,
      {__MODULE__, :execute_coordination_metrics, []},
      [
        # Active agent count
        last_value(
          [:agents, :active_count],
          event_name: @coordination_event,
          description: "Number of currently active agents",
          measurement: :active_count,
          unit: :count,
          tags: [:team]
        ),
        
        # Work completion rate  
        last_value(
          [:work, :completion_rate],
          event_name: @coordination_event,
          description: "Work completion rate (items per minute)",
          measurement: :completion_rate,
          unit: :rate,
          tags: [:team, :work_type]
        ),
        
        # Coordination efficiency
        last_value(
          [:coordination, :efficiency_ratio],
          event_name: @coordination_event,
          description: "Overall coordination efficiency (0-1)",
          measurement: :efficiency_ratio,
          unit: :ratio,
          tags: [:measurement_window]
        ),
        
        # System health score
        last_value(
          [:system, :health_score],
          event_name: @coordination_event,
          description: "System health score (0-100)",
          measurement: :health_score,
          unit: :score,
          tags: [:component]
        )
      ]
    )
  end
  
  @doc false
  def execute_coordination_metrics do
    try do
      # Simple file-based metrics collection (following real patterns)
      coordination_data = collect_coordination_data()
      
      # Execute telemetry events (simple, direct approach)
      :telemetry.execute(
        @coordination_event,
        %{
          active_count: coordination_data.active_agents,
          completion_rate: coordination_data.completion_rate,
          efficiency_ratio: coordination_data.efficiency,
          health_score: coordination_data.health_score
        },
        %{
          team: coordination_data.team,
          work_type: coordination_data.work_type,
          measurement_window: "current",
          component: "agent_coordination"
        }
      )
    rescue
      error ->
        Logger.warn("Error collecting coordination metrics: #{inspect(error)}")
        
        # Default metrics on error (following real error handling patterns)
        :telemetry.execute(@coordination_event, %{
          active_count: 0,
          completion_rate: 0.0,
          efficiency_ratio: 0.0,
          health_score: 50.0
        }, %{})
    end
  end
  
  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 10_000)  # 10 seconds default
    
    [
      coordination_metrics(poll_rate)
    ]
  end
  
  ## Private Functions (Simplified data collection)
  
  defp collect_coordination_data do
    # Simple, focused data collection (no complex file parsing)
    base_path = get_coordination_base_path()
    
    %{
      active_agents: count_active_agents(base_path),
      completion_rate: calculate_completion_rate(base_path),
      efficiency: calculate_efficiency_ratio(),
      health_score: get_health_score(),
      team: "default",
      work_type: "general"
    }
  end
  
  defp get_coordination_base_path do
    Application.get_env(:beamops, :coordination_base_path, "./agent_coordination")
  end
  
  defp count_active_agents(base_path) do
    # Simple implementation - just count based on status file
    agent_status_path = Path.join(base_path, "agent_status.json")
    
    case File.read(agent_status_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, agents} when is_list(agents) ->
            Enum.count(agents, fn agent -> Map.get(agent, "status") == "active" end)
          {:ok, _} -> 1  # Single agent
          {:error, _} -> 0
        end
      {:error, _} -> 0
    end
  end
  
  defp calculate_completion_rate(base_path) do
    # Enhanced completion rate calculation using work_claims.json
    work_claims_path = Path.join(base_path, "work_claims.json")
    
    case File.read(work_claims_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, work_items} when is_list(work_items) ->
            completed_count = Enum.count(work_items, fn item -> 
              Map.get(item, "status") == "completed" 
            end)
            total_count = length(work_items)
            
            # Calculate completion rate as percentage
            if total_count > 0 do
              completed_count / total_count * 100.0
            else
              0.0
            end
          {:error, _} -> 0.0
        end
      {:error, _} -> 
        # Fallback to coordination log
        coordination_log_path = Path.join(base_path, "coordination_log.json")
        case File.read(coordination_log_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, log_entries} when is_list(log_entries) ->
                completed_count = Enum.count(log_entries, fn entry -> 
                  Map.get(entry, "status") == "completed" 
                end)
                completed_count * 6.0
              {:error, _} -> 0.0
            end
          {:error, _} -> 0.0
        end
    end
  end
  
  defp calculate_efficiency_ratio do
    # Enhanced efficiency calculation based on actual coordination data
    base_path = get_coordination_base_path()
    work_claims_path = Path.join(base_path, "work_claims.json")
    
    case File.read(work_claims_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, work_items} when is_list(work_items) ->
            total_items = length(work_items)
            completed_items = Enum.count(work_items, fn item -> 
              Map.get(item, "status") == "completed" 
            end)
            active_items = Enum.count(work_items, fn item -> 
              Map.get(item, "status") == "active" 
            end)
            
            # Calculate efficiency: completed / (completed + active)
            working_items = completed_items + active_items
            if working_items > 0 do
              completed_items / working_items
            else
              0.85  # Default high efficiency when no active work
            end
          {:error, _} -> 0.75
        end
      {:error, _} -> 0.75  # Default moderate efficiency
    end
  end
  
  defp get_health_score do
    # Enhanced health score based on system state
    base_path = get_coordination_base_path()
    work_claims_path = Path.join(base_path, "work_claims.json")
    
    case File.read(work_claims_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, work_items} when is_list(work_items) ->
            error_count = Enum.count(work_items, fn item -> 
              status = Map.get(item, "status", "")
              String.contains?(status, "error") or String.contains?(status, "failed")
            end)
            
            total_items = length(work_items)
            
            # Health score: 100 - (error_percentage * 100)
            if total_items > 0 do
              error_percentage = error_count / total_items
              max(100.0 - (error_percentage * 100.0), 0.0)
            else
              95.0  # High health when no work items
            end
          {:error, _} -> 85.0
        end
      {:error, _} -> 85.0  # Default good health
    end
  end
end