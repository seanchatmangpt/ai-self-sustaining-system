defmodule SelfSustaining.PromEx.ReactorPlugin do
  @moduledoc """
  PromEx Plugin for Reactor Workflow Performance Monitoring

  Specialized PromEx plugin that provides comprehensive metrics for Reactor
  workflow executions, integrating with the existing telemetry middleware
  and providing enhanced observability for AI workflow orchestration.

  ## Metrics Provided

  ### Workflow Execution
  - `self_sustaining_reactor_workflows_total` - Total workflow executions by type
  - `self_sustaining_reactor_workflow_duration_seconds` - Workflow execution time
  - `self_sustaining_reactor_step_duration_seconds` - Individual step timing
  - `self_sustaining_reactor_workflow_errors_total` - Workflow error count

  ### Step Performance
  - `self_sustaining_reactor_step_executions_total` - Step executions by type
  - `self_sustaining_reactor_step_success_ratio` - Step success rate
  - `self_sustaining_reactor_step_retry_count` - Step retry statistics
  - `self_sustaining_reactor_async_tasks_total` - Async task metrics

  ### AI Operations
  - `self_sustaining_ai_operations_total` - AI-specific operations
  - `self_sustaining_ai_response_time_seconds` - AI operation response time
  - `self_sustaining_ai_token_usage_total` - Token consumption tracking
  - `self_sustaining_ai_success_ratio` - AI operation success rate

  ## Integration

  This plugin integrates with:
  - Reactor telemetry middleware
  - OpenTelemetry workflow traces
  - AI operation telemetry
  - Business intelligence metrics
  """

  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :self_sustaining_reactor_event_metrics,
      [
        # Workflow Execution Metrics
        counter(
          "self_sustaining_reactor_workflows_total",
          event_name: [:reactor, :workflow, :complete],
          description: "Total Reactor workflow executions by type and status",
          tags: [:workflow_name, :status, :reactor_id],
          tag_values: &get_workflow_tags/1
        ),
        distribution(
          "self_sustaining_reactor_workflow_duration_seconds",
          event_name: [:reactor, :workflow, :complete],
          description: "Reactor workflow execution time distribution",
          measurement: :duration,
          tags: [:workflow_name, :status],
          tag_values: &get_workflow_duration_tags/1,
          buckets: [0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 300.0]
        ),
        counter(
          "self_sustaining_reactor_workflow_errors_total",
          event_name: [:reactor, :workflow, :error],
          description: "Total Reactor workflow errors by type",
          tags: [:workflow_name, :error_type, :reactor_id],
          tag_values: &get_workflow_error_tags/1
        ),

        # Step Performance Metrics
        counter(
          "self_sustaining_reactor_step_executions_total",
          event_name: [:reactor, :step, :complete],
          description: "Total Reactor step executions by type and status",
          tags: [:step_name, :step_type, :status, :workflow_name],
          tag_values: &get_step_tags/1
        ),
        distribution(
          "self_sustaining_reactor_step_duration_seconds",
          event_name: [:reactor, :step, :complete],
          description: "Reactor step execution time distribution",
          measurement: :duration,
          tags: [:step_name, :step_type, :workflow_name],
          tag_values: &get_step_duration_tags/1,
          buckets: [0.001, 0.01, 0.1, 0.5, 1.0, 5.0, 10.0, 30.0]
        ),
        last_value(
          "self_sustaining_reactor_step_success_ratio",
          event_name: [:prom_ex, :plugin, :self_sustaining_reactor_step_success, :set],
          description: "Reactor step success ratio (0-1)",
          measurement: :success_ratio,
          tags: [:step_type, :workflow_name],
          tag_values: &get_step_success_tags/1
        ),
        counter(
          "self_sustaining_reactor_step_retry_count",
          event_name: [:reactor, :step, :retry],
          description: "Total Reactor step retries by type",
          tags: [:step_name, :retry_reason, :workflow_name],
          tag_values: &get_step_retry_tags/1
        ),
        counter(
          "self_sustaining_reactor_async_tasks_total",
          event_name: [:reactor, :async, :complete],
          description: "Total async task executions in Reactor workflows",
          tags: [:task_type, :status, :workflow_name],
          tag_values: &get_async_task_tags/1
        ),

        # AI Operation Metrics
        counter(
          "self_sustaining_ai_operations_total",
          event_name: [:self_sustaining, :ai, :operation, :complete],
          description: "Total AI operations by type and provider",
          tags: [:operation_type, :provider, :status],
          tag_values: &get_ai_operation_tags/1
        ),
        distribution(
          "self_sustaining_ai_response_time_seconds",
          event_name: [:self_sustaining, :ai, :operation, :complete],
          description: "AI operation response time distribution",
          measurement: :duration,
          tags: [:operation_type, :provider],
          tag_values: &get_ai_response_time_tags/1,
          buckets: [0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0]
        ),
        counter(
          "self_sustaining_ai_token_usage_total",
          event_name: [:self_sustaining, :ai, :tokens, :used],
          description: "Total AI token usage by operation and provider",
          measurement: :token_count,
          tags: [:operation_type, :provider, :token_type],
          tag_values: &get_ai_token_tags/1
        ),
        last_value(
          "self_sustaining_ai_success_ratio",
          event_name: [:prom_ex, :plugin, :self_sustaining_ai_success, :set],
          description: "AI operation success ratio (0-1)",
          measurement: :success_ratio,
          tags: [:operation_type, :provider],
          tag_values: &get_ai_success_tags/1
        ),

        # Telemetry Integration Metrics
        counter(
          "self_sustaining_telemetry_spans_created_total",
          event_name: [:self_sustaining, :telemetry, :span, :created],
          description: "Total OpenTelemetry spans created in workflows",
          tags: [:span_type, :workflow_name, :service_name],
          tag_values: &get_telemetry_span_tags/1
        ),
        distribution(
          "self_sustaining_trace_propagation_time_seconds",
          event_name: [:self_sustaining, :telemetry, :trace, :propagated],
          description: "Trace context propagation time distribution",
          measurement: :propagation_time,
          tags: [:source_service, :target_service],
          tag_values: &get_trace_propagation_tags/1,
          buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1]
        )
      ]
    )
  end

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    [
      Polling.build(
        :self_sustaining_reactor_polling_metrics,
        poll_rate,
        {__MODULE__, :execute_polling, []},
        [
          # Reactor System Health
          last_value(
            "self_sustaining_reactor_active_workflows",
            event_name: [:prom_ex, :plugin, :self_sustaining_reactor_active, :set],
            description: "Number of currently active Reactor workflows",
            measurement: :active_count,
            tags: [:workflow_type],
            tag_values: fn _metadata -> %{workflow_type: "all"} end
          ),
          last_value(
            "self_sustaining_reactor_queue_depth",
            event_name: [:prom_ex, :plugin, :self_sustaining_reactor_queue, :set],
            description: "Reactor workflow queue depth",
            measurement: :queue_depth,
            tags: [:priority, :workflow_type],
            tag_values: &get_reactor_queue_tags/1
          ),

          # AI System Health
          last_value(
            "self_sustaining_ai_availability_ratio",
            event_name: [:prom_ex, :plugin, :self_sustaining_ai_availability, :set],
            description: "AI service availability ratio (0-1)",
            measurement: :availability,
            tags: [:provider, :service_type],
            tag_values: &get_ai_availability_tags/1
          )
        ]
      )
    ]
  end

  ## Tag Value Functions

  defp get_workflow_tags(%{workflow_name: name, reactor_id: id} = metadata) do
    %{
      workflow_name: sanitize_name(name),
      status: Map.get(metadata, :status, "unknown"),
      reactor_id: sanitize_reactor_id(id)
    }
  end

  defp get_workflow_duration_tags(%{workflow_name: name} = metadata) do
    %{
      workflow_name: sanitize_name(name),
      status: Map.get(metadata, :status, "unknown")
    }
  end

  defp get_workflow_error_tags(%{workflow_name: name, reactor_id: id} = metadata) do
    %{
      workflow_name: sanitize_name(name),
      error_type: Map.get(metadata, :error_type, "unknown"),
      reactor_id: sanitize_reactor_id(id)
    }
  end

  defp get_step_tags(metadata) do
    %{
      step_name: sanitize_name(Map.get(metadata, :step_name, "unknown")),
      step_type: Map.get(metadata, :step_type, "unknown"),
      status: Map.get(metadata, :status, "unknown"),
      workflow_name: sanitize_name(Map.get(metadata, :workflow_name, "unknown"))
    }
  end

  defp get_step_duration_tags(metadata) do
    %{
      step_name: sanitize_name(Map.get(metadata, :step_name, "unknown")),
      step_type: Map.get(metadata, :step_type, "unknown"),
      workflow_name: sanitize_name(Map.get(metadata, :workflow_name, "unknown"))
    }
  end

  defp get_step_success_tags(%{labels: labels}) do
    %{
      step_type: Map.get(labels, :step_type, "unknown"),
      workflow_name: sanitize_name(Map.get(labels, :workflow_name, "unknown"))
    }
  end

  defp get_step_retry_tags(metadata) do
    %{
      step_name: sanitize_name(Map.get(metadata, :step_name, "unknown")),
      retry_reason: Map.get(metadata, :retry_reason, "unknown"),
      workflow_name: sanitize_name(Map.get(metadata, :workflow_name, "unknown"))
    }
  end

  defp get_async_task_tags(metadata) do
    %{
      task_type: Map.get(metadata, :task_type, "unknown"),
      status: Map.get(metadata, :status, "unknown"),
      workflow_name: sanitize_name(Map.get(metadata, :workflow_name, "unknown"))
    }
  end

  defp get_ai_operation_tags(metadata) do
    %{
      operation_type: Map.get(metadata, :operation_type, "unknown"),
      provider: Map.get(metadata, :provider, "unknown"),
      status: Map.get(metadata, :status, "unknown")
    }
  end

  defp get_ai_response_time_tags(metadata) do
    %{
      operation_type: Map.get(metadata, :operation_type, "unknown"),
      provider: Map.get(metadata, :provider, "unknown")
    }
  end

  defp get_ai_token_tags(metadata) do
    %{
      operation_type: Map.get(metadata, :operation_type, "unknown"),
      provider: Map.get(metadata, :provider, "unknown"),
      token_type: Map.get(metadata, :token_type, "total")
    }
  end

  defp get_ai_success_tags(%{labels: labels}) do
    %{
      operation_type: Map.get(labels, :operation_type, "unknown"),
      provider: Map.get(labels, :provider, "unknown")
    }
  end

  defp get_telemetry_span_tags(metadata) do
    %{
      span_type: Map.get(metadata, :span_type, "unknown"),
      workflow_name: sanitize_name(Map.get(metadata, :workflow_name, "unknown")),
      service_name: Map.get(metadata, :service_name, "self_sustaining")
    }
  end

  defp get_trace_propagation_tags(metadata) do
    %{
      source_service: Map.get(metadata, :source_service, "unknown"),
      target_service: Map.get(metadata, :target_service, "unknown")
    }
  end

  defp get_reactor_queue_tags(_metadata) do
    %{
      priority: "medium",
      workflow_type: "general"
    }
  end

  defp get_ai_availability_tags(%{labels: labels}) do
    %{
      provider: Map.get(labels, :provider, "unknown"),
      service_type: Map.get(labels, :service_type, "general")
    }
  end

  ## Polling Function

  def execute_polling do
    # Basic polling metrics execution
    :ok
  end

  ## Utility Functions

  defp sanitize_name(name) do
    # Sanitize workflow/step names to prevent cardinality explosion
    case name do
      name when is_binary(name) ->
        name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9_]/, "_")
        |> String.slice(0, 50)

      _ ->
        "unknown"
    end
  end

  defp sanitize_reactor_id(id) do
    # Sanitize reactor ID to prevent cardinality explosion
    case id do
      id when is_binary(id) -> String.slice(id, -8, 8)
      _ -> "unknown"
    end
  end
end
