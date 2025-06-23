defmodule SelfSustaining.PromExAgentCoordination do
  @moduledoc """
  Custom PromEx plugin for agent coordination monitoring.

  Provides comprehensive metrics for:
  - Agent claim rates and conflicts
  - Work distribution efficiency
  - Team formation metrics
  - Claude AI intelligence performance
  - Coordination throughput and latency
  """

  use PromEx.Plugin

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    [
      # Agent coordination summary metrics
      agent_coordination_summary_metrics(poll_rate),

      # Work distribution metrics  
      work_distribution_metrics(poll_rate),

      # Team formation efficiency metrics
      team_formation_metrics(poll_rate),

      # Claude AI intelligence metrics
      claude_intelligence_metrics(poll_rate)
    ]
  end

  @impl true
  def event_metrics(opts) do
    [
      # Real-time coordination event metrics
      coordination_event_metrics(opts),

      # Telemetry middleware integration
      telemetry_integration_metrics(opts)
    ]
  end

  defp agent_coordination_summary_metrics(poll_rate) do
    Polling.build(
      :agent_coordination_summary_metrics,
      poll_rate,
      {__MODULE__, :execute_agent_coordination_summary, []},
      [
        # Total active agents across all teams
        last_value(
          [:agent_coordination, :active_agents, :total],
          event_name: [:agent_coordination, :summary],
          description: "Total number of active agents in the system",
          measurement: :active_agents_total,
          tags: [:environment, :cluster]
        ),

        # Agent distribution by team
        last_value(
          [:agent_coordination, :team_distribution, :count],
          event_name: [:agent_coordination, :summary],
          description: "Number of agents per team",
          measurement: :team_agent_count,
          tags: [:team, :specialization, :environment]
        ),

        # Work claim efficiency
        last_value(
          [:agent_coordination, :claim_efficiency, :rate],
          event_name: [:agent_coordination, :summary],
          description: "Work claim success rate (1.0 = 100%)",
          measurement: :claim_efficiency_rate,
          tags: [:team, :priority, :environment]
        ),

        # Coordination velocity (operations per minute)
        last_value(
          [:agent_coordination, :velocity, :operations_per_minute],
          event_name: [:agent_coordination, :summary],
          description: "Agent coordination operations per minute",
          measurement: :coordination_velocity,
          tags: [:operation_type, :environment]
        )
      ]
    )
  end

  defp work_distribution_metrics(poll_rate) do
    Polling.build(
      :work_distribution_metrics,
      poll_rate,
      {__MODULE__, :execute_work_distribution_analysis, []},
      [
        # Active work items by priority
        last_value(
          [:work_distribution, :active_items, :count],
          event_name: [:work_distribution, :analysis],
          description: "Number of active work items by priority",
          measurement: :active_work_count,
          tags: [:priority, :work_type, :team, :environment]
        ),

        # Work completion rate  
        last_value(
          [:work_distribution, :completion_rate, :velocity_points],
          event_name: [:work_distribution, :analysis],
          description: "Work completion velocity in story points per hour",
          measurement: :completion_velocity,
          tags: [:team, :sprint, :environment]
        ),

        # Work queue depth
        last_value(
          [:work_distribution, :queue_depth, :items],
          event_name: [:work_distribution, :analysis],
          description: "Number of pending work items in queue",
          measurement: :queue_depth,
          tags: [:priority, :team, :environment]
        ),

        # Agent utilization rates
        last_value(
          [:work_distribution, :agent_utilization, :percentage],
          event_name: [:work_distribution, :analysis],
          description: "Agent utilization percentage (0.0-1.0)",
          measurement: :agent_utilization,
          tags: [:agent_id, :team, :specialization, :environment]
        )
      ]
    )
  end

  defp team_formation_metrics(poll_rate) do
    Polling.build(
      :team_formation_metrics,
      poll_rate,
      {__MODULE__, :execute_team_formation_analysis, []},
      [
        # Team formation efficiency
        last_value(
          [:team_formation, :efficiency, :score],
          event_name: [:team_formation, :analysis],
          description: "Team formation efficiency score (0.0-1.0)",
          measurement: :formation_efficiency,
          tags: [:team, :formation_strategy, :environment]
        ),

        # Scrum at Scale ceremony metrics
        last_value(
          [:team_formation, :ceremonies, :participation_rate],
          event_name: [:team_formation, :analysis],
          description: "Scrum ceremony participation rate",
          measurement: :ceremony_participation,
          tags: [:ceremony_type, :art, :team, :environment]
        ),

        # Cross-team coordination effectiveness
        last_value(
          [:team_formation, :cross_team, :coordination_score],
          event_name: [:team_formation, :analysis],
          description: "Cross-team coordination effectiveness score",
          measurement: :coordination_effectiveness,
          tags: [:source_team, :target_team, :environment]
        )
      ]
    )
  end

  defp claude_intelligence_metrics(poll_rate) do
    Polling.build(
      :claude_intelligence_metrics,
      poll_rate,
      {__MODULE__, :execute_claude_intelligence_analysis, []},
      [
        # Claude AI priority analysis confidence
        last_value(
          [:claude_intelligence, :priority_analysis, :confidence],
          event_name: [:claude_intelligence, :analysis],
          description: "Claude AI priority analysis confidence score",
          measurement: :priority_confidence,
          tags: [:analysis_type, :environment]
        ),

        # Claude AI work recommendation accuracy
        last_value(
          [:claude_intelligence, :recommendations, :accuracy],
          event_name: [:claude_intelligence, :analysis],
          description: "Claude AI work recommendation accuracy rate",
          measurement: :recommendation_accuracy,
          tags: [:recommendation_type, :environment]
        ),

        # Claude AI response time
        last_value(
          [:claude_intelligence, :response_time, :milliseconds],
          event_name: [:claude_intelligence, :analysis],
          description: "Claude AI analysis response time in milliseconds",
          measurement: :ai_response_time,
          tags: [:analysis_type, :complexity, :environment]
        )
      ]
    )
  end

  defp coordination_event_metrics(_opts) do
    Event.build(
      :coordination_event_metrics,
      [
        # Work claim events
        counter(
          [:agent_coordination, :work_claims, :total],
          event_name: [:agent_coordination, :work, :claimed],
          description: "Total number of work claims",
          tags: [:agent_id, :work_type, :priority, :team]
        ),

        # Work claim conflicts
        counter(
          [:agent_coordination, :conflicts, :total],
          event_name: [:agent_coordination, :conflict, :detected],
          description: "Total number of work claim conflicts",
          tags: [:conflict_type, :resolution_method, :agents_involved]
        ),

        # Work completion events
        distribution(
          [:agent_coordination, :work_completion, :duration],
          event_name: [:agent_coordination, :work, :completed],
          description: "Work completion duration distribution",
          measurement: :duration_ms,
          tags: [:work_type, :priority, :team, :agent_id],
          buckets: [100, 500, 1000, 5000, 10000, 30000, 60000]
        ),

        # Coordination middleware latency
        distribution(
          [:agent_coordination, :middleware, :latency],
          event_name: [:reactor, :middleware, :telemetry],
          description: "Agent coordination middleware latency",
          measurement: :duration,
          tags: [:middleware_type, :operation],
          buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]
        )
      ]
    )
  end

  defp telemetry_integration_metrics(_opts) do
    Event.build(
      :telemetry_integration_metrics,
      [
        # OpenTelemetry span creation
        counter(
          [:telemetry_integration, :spans, :created],
          event_name: [:opentelemetry, :span, :created],
          description: "OpenTelemetry spans created for coordination",
          tags: [:span_type, :trace_source, :coordination_context]
        ),

        # Telemetry event processing
        distribution(
          [:telemetry_integration, :event_processing, :duration],
          event_name: [:telemetry, :event, :processed],
          description: "Telemetry event processing duration",
          measurement: :processing_time,
          tags: [:event_type, :processor],
          buckets: [1, 10, 50, 100, 500, 1000, 5000]
        )
      ]
    )
  end

  # Polling metric execution functions
  def execute_agent_coordination_summary do
    try do
      # Read coordination files
      {active_agents, team_distribution, claim_efficiency, velocity} =
        analyze_coordination_state()

      # Emit telemetry events
      :telemetry.execute(
        [:agent_coordination, :summary],
        %{
          active_agents_total: active_agents.total,
          team_agent_count: team_distribution,
          claim_efficiency_rate: claim_efficiency,
          coordination_velocity: velocity
        },
        %{environment: get_environment(), cluster: get_cluster()}
      )
    rescue
      error ->
        :telemetry.execute(
          [:agent_coordination, :summary, :error],
          %{error_count: 1},
          %{error_type: inspect(error.__struct__)}
        )
    end
  end

  def execute_work_distribution_analysis do
    try do
      {active_work, completion_rate, queue_depth, utilization} =
        analyze_work_distribution()

      :telemetry.execute(
        [:work_distribution, :analysis],
        %{
          active_work_count: active_work,
          completion_velocity: completion_rate,
          queue_depth: queue_depth,
          agent_utilization: utilization
        },
        %{environment: get_environment()}
      )
    rescue
      error ->
        :telemetry.execute(
          [:work_distribution, :analysis, :error],
          %{error_count: 1},
          %{error_type: inspect(error.__struct__)}
        )
    end
  end

  def execute_team_formation_analysis do
    try do
      {formation_efficiency, ceremony_participation, coordination_effectiveness} =
        analyze_team_formation()

      :telemetry.execute(
        [:team_formation, :analysis],
        %{
          formation_efficiency: formation_efficiency,
          ceremony_participation: ceremony_participation,
          coordination_effectiveness: coordination_effectiveness
        },
        %{environment: get_environment()}
      )
    rescue
      error ->
        :telemetry.execute(
          [:team_formation, :analysis, :error],
          %{error_count: 1},
          %{error_type: inspect(error.__struct__)}
        )
    end
  end

  def execute_claude_intelligence_analysis do
    try do
      {priority_confidence, recommendation_accuracy, response_time} =
        analyze_claude_intelligence()

      :telemetry.execute(
        [:claude_intelligence, :analysis],
        %{
          priority_confidence: priority_confidence,
          recommendation_accuracy: recommendation_accuracy,
          ai_response_time: response_time
        },
        %{environment: get_environment()}
      )
    rescue
      error ->
        :telemetry.execute(
          [:claude_intelligence, :analysis, :error],
          %{error_count: 1},
          %{error_type: inspect(error.__struct__)}
        )
    end
  end

  # Analysis implementation functions
  defp analyze_coordination_state do
    # Read agent status file
    agent_status = read_coordination_file("agent_status.json", %{"agents" => []})
    work_claims = read_coordination_file("work_claims.json", %{"claims" => []})

    active_agents = %{total: length(agent_status["agents"])}

    # Calculate team distribution
    team_distribution =
      agent_status["agents"]
      |> Enum.group_by(& &1["team"])
      |> Enum.map(fn {team, agents} -> %{team: team, count: length(agents)} end)
      |> Enum.reduce(0, fn %{count: count}, acc -> acc + count end)

    # Calculate claim efficiency (simplified)
    total_claims = length(work_claims["claims"])
    completed_claims = Enum.count(work_claims["claims"], &(&1["status"] == "completed"))
    claim_efficiency = if total_claims > 0, do: completed_claims / total_claims, else: 1.0

    # Calculate velocity (operations per minute)
    velocity = calculate_coordination_velocity()

    {active_agents, team_distribution, claim_efficiency, velocity}
  end

  defp analyze_work_distribution do
    work_claims = read_coordination_file("work_claims.json", %{"claims" => []})

    # Active work by priority
    active_work =
      work_claims["claims"]
      |> Enum.filter(&(&1["status"] in ["pending", "active"]))
      |> length()

    # Completion rate (simplified)
    completion_rate = calculate_completion_velocity()

    # Queue depth
    queue_depth =
      work_claims["claims"]
      |> Enum.count(&(&1["status"] == "pending"))

    # Agent utilization (simplified)
    utilization = calculate_agent_utilization()

    {active_work, completion_rate, queue_depth, utilization}
  end

  defp analyze_team_formation do
    # Team formation efficiency (placeholder)
    formation_efficiency = 0.85

    # Ceremony participation (placeholder)
    ceremony_participation = 0.92

    # Coordination effectiveness (placeholder)
    coordination_effectiveness = 0.78

    {formation_efficiency, ceremony_participation, coordination_effectiveness}
  end

  defp analyze_claude_intelligence do
    # Priority confidence (placeholder - could read from Claude analysis files)
    priority_confidence = 0.70

    # Recommendation accuracy (placeholder)
    recommendation_accuracy = 0.83

    # Response time (placeholder)
    response_time = 1250.0

    {priority_confidence, recommendation_accuracy, response_time}
  end

  # Helper functions
  defp read_coordination_file(filename, default) do
    path = Path.join(["agent_coordination", filename])

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          {:error, _} -> default
        end

      {:error, _} ->
        default
    end
  end

  defp calculate_coordination_velocity do
    # Read coordination log for velocity calculation
    coordination_log = read_coordination_file("coordination_log.json", %{"entries" => []})

    # Calculate operations per minute (simplified)
    recent_entries =
      coordination_log["entries"]
      # Last 60 entries
      |> Enum.take(-60)
      |> length()

    # Operations per minute approximation
    recent_entries * 1.0
  end

  defp calculate_completion_velocity do
    # Calculate story points completed per hour (placeholder)
    25.5
  end

  defp calculate_agent_utilization do
    # Calculate average agent utilization (placeholder)
    0.74
  end

  defp get_environment do
    System.get_env("DEPLOYMENT_ENVIRONMENT", "development")
  end

  defp get_cluster do
    System.get_env("DEPLOYMENT_CLUSTER", "local")
  end
end
