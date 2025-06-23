defmodule SelfSustaining.PromEx.CoordinationPlugin do
  @moduledoc """
  PromEx plugin for agent coordination performance monitoring
  """
  use PromEx.Plugin

  alias PromEx.MetricTypes.{Polling, Event}

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    [
      coordination_metrics_polling_group(poll_rate)
    ]
  end

  @impl true
  def event_metrics(_opts) do
    [
      coordination_events_group()
    ]
  end

  defp coordination_metrics_polling_group(poll_rate) do
    Polling.build(
      :coordination_metrics_polling_group,
      poll_rate,
      {__MODULE__, :emit_coordination_metrics, []},
      [
        # Active agents metric
        last_value(
          [:coordination, :active_agents, :count],
          event_name: [:coordination, :polling, :agents],
          description: "Number of active agents in the coordination system",
          measurement: :count,
          tags: [:team_type]
        ),

        # Work queue metrics
        last_value(
          [:coordination, :work_queue, :size],
          event_name: [:coordination, :polling, :work_queue],
          description: "Number of items in the work queue",
          measurement: :size,
          tags: [:priority]
        ),

        # Coordination operation latency
        last_value(
          [:coordination, :operation, :duration, :milliseconds],
          event_name: [:coordination, :polling, :operations],
          description: "Duration of coordination operations",
          measurement: :duration,
          tags: [:operation_type]
        ),

        # Agent performance metrics
        last_value(
          [:coordination, :agent, :throughput],
          event_name: [:coordination, :polling, :agent_performance],
          description: "Agent work completion rate",
          measurement: :throughput,
          tags: [:agent_id, :team_type]
        )
      ]
    )
  end

  defp coordination_events_group do
    Event.build(
      :coordination_events_group,
      [
        # Work claim events
        counter(
          [:coordination, :work, :claimed, :total],
          event_name: [:coordination, :work, :claimed],
          description: "Total number of work items claimed",
          tags: [:agent_id, :work_type, :priority]
        ),

        # Work completion events
        counter(
          [:coordination, :work, :completed, :total],
          event_name: [:coordination, :work, :completed],
          description: "Total number of work items completed",
          tags: [:agent_id, :work_type, :success]
        ),

        # Work duration distribution
        distribution(
          [:coordination, :work, :duration, :histogram],
          event_name: [:coordination, :work, :completed],
          description: "Distribution of work completion times",
          measurement: :duration,
          tags: [:work_type],
          unit: {:native, :second},
          reporter_options: [buckets: [0.1, 0.5, 1, 5, 10, 30, 60, 300, 600]]
        ),

        # Agent coordination events
        counter(
          [:coordination, :agent, :registered, :total],
          event_name: [:coordination, :agent, :registered],
          description: "Total number of agent registrations",
          tags: [:team_type, :capabilities]
        ),

        # Team formation events
        counter(
          [:coordination, :team, :formed, :total],
          event_name: [:coordination, :team, :formed],
          description: "Total number of teams formed",
          tags: [:team_type, :size]
        ),

        # PI planning events
        counter(
          [:coordination, :pi_planning, :sessions, :total],
          event_name: [:coordination, :pi_planning, :session],
          description: "Total number of PI planning sessions",
          tags: [:outcome, :participants]
        ),

        # Trace correlation events
        counter(
          [:coordination, :boundary, :crossed, :total],
          event_name: [:coordination, :boundary, :crossed],
          description: "Total number of coordination boundary crossings with trace correlation",
          tags: [:agent_id, :work_type]
        ),

        # Agent operation completion events
        counter(
          [:coordination, :agent, :operation, :completed, :total],
          event_name: [:coordination, :agent, :operation, :completed],
          description: "Total number of completed agent operations with trace correlation",
          tags: [:agent_id, :operation]
        ),

        # Trace context propagation events
        counter(
          [:coordination, :trace, :context, :propagated, :total],
          event_name: [:coordination, :trace, :context, :propagated],
          description: "Total number of trace context propagations across coordination boundaries",
          tags: [:from_agent, :to_agent]
        )
      ]
    )
  end

  # Helper function to emit coordination metrics
  def emit_coordination_metrics do
    active_agents = count_active_agents()
    work_queue_size = get_work_queue_size()
    
    :telemetry.execute([:coordination, :polling, :agents], %{count: active_agents}, %{team_type: "all"})
    :telemetry.execute([:coordination, :polling, :work_queue], %{size: work_queue_size}, %{priority: "all"})
    :telemetry.execute([:coordination, :polling, :operations], %{duration: 0.1}, %{operation_type: "status_check"})
    :telemetry.execute([:coordination, :polling, :agent_performance], %{throughput: 1.0}, %{agent_id: "system", team_type: "coordination"})
  end

  # Event handler function for coordination events
  def handle_coordination_events(_event_name, _measurements, _metadata, _config) do
    # Events are automatically handled by PromEx when they occur
    :ok
  end

  defp count_active_agents do
    case File.read("../agent_coordination/agent_status.json") do
      {:ok, content} ->
        content
        |> Jason.decode!()
        |> Map.get("agents", [])
        |> length()
      {:error, _} -> 0
    end
  end

  defp get_work_queue_size do
    case File.read("../agent_coordination/work_claims.json") do
      {:ok, content} ->
        content
        |> Jason.decode!()
        |> Map.get("active_work", [])
        |> length()
      {:error, _} -> 0
    end
  end
end