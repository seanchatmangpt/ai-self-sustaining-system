defmodule SelfSustainingWeb.CoordinationController do
  @moduledoc """
  Agent coordination controller for swarm status and operations.
  """

  use SelfSustainingWeb, :controller

  @agent_status_file Path.join([File.cwd!(), "..", "agent_coordination", "agent_status.json"])
  @work_claims_file Path.join([File.cwd!(), "..", "agent_coordination", "work_claims.json"])

  def agents(conn, _params) do
    # Return real agent data from JSON file
    agents =
      case read_json_file(@agent_status_file) do
        {:ok, data} when is_list(data) ->
          data
          |> Enum.map(fn agent ->
            %{
              agent_id: Map.get(agent, "agent_id"),
              team: Map.get(agent, "team"),
              status: Map.get(agent, "status"),
              capacity: Map.get(agent, "capacity"),
              current_workload: Map.get(agent, "current_workload", 0),
              specialization: Map.get(agent, "specialization"),
              last_heartbeat: Map.get(agent, "last_heartbeat"),
              performance_metrics: Map.get(agent, "performance_metrics", %{})
            }
          end)

        _ ->
          []
      end

    response = %{
      timestamp: DateTime.utc_now(),
      trace_id: Map.get(conn.assigns, :trace_id),
      total_agents: length(agents),
      active_agents: agents |> Enum.count(fn a -> a.status == "active" end),
      agents: agents
    }

    json(conn, response)
  end

  def status(conn, _params) do
    # Return coordination status with REAL data
    status = %{
      timestamp: DateTime.utc_now(),
      trace_id: Map.get(conn.assigns, :trace_id),
      agents: %{
        active: get_active_agent_count(),
        total: get_total_agent_count()
      },
      coordination: %{
        work_claims: get_work_claim_count(),
        completed_work: get_completed_work_count(),
        pending_work: get_pending_work_count()
      },
      performance: %{
        coordination_operations_per_hour: get_coordination_rate(),
        average_work_completion_time: get_avg_completion_time()
      },
      system_health: %{
        agent_status_file_exists: File.exists?(@agent_status_file),
        work_claims_file_exists: File.exists?(@work_claims_file)
      }
    }

    json(conn, status)
  end

  # Read actual data from JSON files
  defp get_active_agent_count do
    case read_json_file(@agent_status_file) do
      {:ok, agents} when is_list(agents) ->
        agents |> Enum.count(fn agent -> Map.get(agent, "status") == "active" end)

      _ ->
        0
    end
  end

  defp get_total_agent_count do
    case read_json_file(@agent_status_file) do
      {:ok, agents} when is_list(agents) -> length(agents)
      _ -> 0
    end
  end

  defp get_work_claim_count do
    case read_json_file(@work_claims_file) do
      {:ok, claims} when is_list(claims) -> length(claims)
      _ -> 0
    end
  end

  defp get_completed_work_count do
    case read_json_file(@work_claims_file) do
      {:ok, claims} when is_list(claims) ->
        claims |> Enum.count(fn claim -> Map.get(claim, "status") == "completed" end)

      _ ->
        0
    end
  end

  defp get_pending_work_count do
    case read_json_file(@work_claims_file) do
      {:ok, claims} when is_list(claims) ->
        claims |> Enum.count(fn claim -> Map.get(claim, "status") in ["pending", "active"] end)

      _ ->
        0
    end
  end

  defp get_coordination_rate do
    # Calculate operations per hour from completed work
    case read_json_file(@work_claims_file) do
      {:ok, claims} when is_list(claims) ->
        completed_claims =
          claims
          |> Enum.filter(fn claim ->
            Map.get(claim, "status") == "completed" and Map.has_key?(claim, "completed_at")
          end)

        if length(completed_claims) > 0 do
          # Calculate based on completed work in last hour
          one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

          recent_completed =
            completed_claims
            |> Enum.filter(fn claim ->
              case DateTime.from_iso8601(Map.get(claim, "completed_at", "")) do
                {:ok, completed_at, _} -> DateTime.compare(completed_at, one_hour_ago) == :gt
                _ -> false
              end
            end)

          length(recent_completed)
        else
          0
        end

      _ ->
        0
    end
  end

  defp get_avg_completion_time do
    case read_json_file(@work_claims_file) do
      {:ok, claims} when is_list(claims) ->
        completed_claims =
          claims
          |> Enum.filter(fn claim ->
            Map.get(claim, "status") == "completed" and
              Map.has_key?(claim, "completed_at") and
              Map.has_key?(claim, "claimed_at")
          end)

        if length(completed_claims) > 0 do
          total_time =
            completed_claims
            |> Enum.map(fn claim ->
              with {:ok, completed_at, _} <-
                     DateTime.from_iso8601(Map.get(claim, "completed_at")),
                   {:ok, claimed_at, _} <- DateTime.from_iso8601(Map.get(claim, "claimed_at")) do
                DateTime.diff(completed_at, claimed_at, :minute)
              else
                _ -> 0
              end
            end)
            |> Enum.sum()

          total_time / length(completed_claims)
        else
          0.0
        end

      _ ->
        0.0
    end
  end

  defp read_json_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, :invalid_json}
        end

      {:error, _} ->
        {:error, :file_not_found}
    end
  end
end
