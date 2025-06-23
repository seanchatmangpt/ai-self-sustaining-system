defmodule SelfSustaining.TelemetrySupervisor do
  @moduledoc """
  Telemetry supervisor for comprehensive observability integration.

  Manages the telemetry infrastructure including OpenTelemetry handlers,
  PromEx metric collection, and agent coordination telemetry integration.

  This supervisor ensures that all telemetry components start in the correct
  order and provides fault tolerance for observability components.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # OpenTelemetry telemetry handlers
      {Task, fn -> setup_opentelemetry_handlers() end},

      # Agent coordination telemetry integration
      {Task, fn -> setup_coordination_telemetry() end},

      # PromEx telemetry event handlers
      {Task, fn -> setup_promex_handlers() end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp setup_opentelemetry_handlers do
    # Set up OpenTelemetry handlers for Phoenix, Ecto, and custom events
    :telemetry.attach_many(
      "self-sustaining-opentelemetry",
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:self_sustaining, :coordination, :operation, :start],
        [:self_sustaining, :coordination, :operation, :stop],
        [:self_sustaining, :reactor, :workflow, :start],
        [:self_sustaining, :reactor, :workflow, :stop]
      ],
      &handle_opentelemetry_event/4,
      %{}
    )

    Logger.info("OpenTelemetry telemetry handlers attached")
  end

  defp setup_coordination_telemetry do
    # Set up handlers for agent coordination events
    :telemetry.attach_many(
      "self-sustaining-coordination",
      [
        [:self_sustaining, :coordination, :work_claimed],
        [:self_sustaining, :coordination, :work_completed],
        [:self_sustaining, :coordination, :agent_registered],
        [:self_sustaining, :coordination, :efficiency_calculated]
      ],
      &handle_coordination_event/4,
      %{}
    )

    Logger.info("Coordination telemetry handlers attached")
  end

  defp setup_promex_handlers do
    # Set up handlers for PromEx metric events
    :telemetry.attach_many(
      "self-sustaining-promex",
      [
        [:self_sustaining, :promex, :coordination_metric, :recorded],
        [:self_sustaining, :promex, :business_value, :recorded]
      ],
      &handle_promex_event/4,
      %{}
    )

    Logger.info("PromEx telemetry handlers attached")
  end

  defp handle_opentelemetry_event(event, measurements, metadata, _config) do
    # Forward events to OpenTelemetry
    case event do
      [:phoenix, :endpoint, :start] ->
        Logger.debug("Phoenix endpoint request started", trace_id: Map.get(metadata, :trace_id))

      [:phoenix, :endpoint, :stop] ->
        Logger.debug("Phoenix endpoint request completed",
          trace_id: Map.get(metadata, :trace_id),
          duration: Map.get(measurements, :duration)
        )

      [:self_sustaining, :coordination, :operation, :start] ->
        Logger.debug("Coordination operation started",
          operation: Map.get(metadata, :operation_type),
          agent_id: Map.get(metadata, :agent_id)
        )

      [:self_sustaining, :coordination, :operation, :stop] ->
        Logger.debug("Coordination operation completed",
          operation: Map.get(metadata, :operation_type),
          agent_id: Map.get(metadata, :agent_id),
          duration: Map.get(measurements, :duration)
        )

      _ ->
        :ok
    end
  end

  defp handle_coordination_event(event, measurements, metadata, _config) do
    # Handle coordination-specific telemetry events
    case event do
      [:self_sustaining, :coordination, :work_claimed] ->
        agent_id = Map.get(metadata, :agent_id, "unknown")
        work_type = Map.get(metadata, :work_type, "general")
        Logger.info("Work claimed", agent_id: agent_id, work_type: work_type)

      [:self_sustaining, :coordination, :work_completed] ->
        agent_id = Map.get(metadata, :agent_id, "unknown")
        work_type = Map.get(metadata, :work_type, "general")
        result = Map.get(metadata, :result, "success")
        duration = Map.get(measurements, :duration, 0)

        Logger.info("Work completed",
          agent_id: agent_id,
          work_type: work_type,
          result: result,
          duration_ms: duration
        )

      [:self_sustaining, :coordination, :efficiency_calculated] ->
        efficiency = Map.get(measurements, :efficiency, 0.0)
        Logger.info("Coordination efficiency calculated", efficiency: efficiency)

      _ ->
        :ok
    end
  end

  defp handle_promex_event(event, measurements, metadata, _config) do
    # Handle PromEx-specific telemetry events
    case event do
      [:self_sustaining, :promex, :coordination_metric, :recorded] ->
        metric_type = Map.get(metadata, :metric_type)
        Logger.debug("PromEx coordination metric recorded", metric_type: metric_type)

      [:self_sustaining, :promex, :business_value, :recorded] ->
        value = Map.get(measurements, :value, 0)
        Logger.debug("PromEx business value recorded", value: value)

      _ ->
        :ok
    end
  end
end
