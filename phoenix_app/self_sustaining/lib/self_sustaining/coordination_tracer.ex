defmodule SelfSustaining.CoordinationTracer do
  @moduledoc """
  Coordination trace management for agent coordination boundaries with OpenTelemetry
  """
  
  require Logger
  require OpenTelemetry.Tracer
  alias OpenTelemetry.{Span, Tracer}

  @tracer_id __MODULE__

  @doc """
  Start a coordination span for agent work
  """
  def start_coordination_span(operation_name, attributes \\ %{}) do
    span_name = "coordination.#{operation_name}"
    
    span_ctx = Tracer.start_span(@tracer_id, span_name, %{
      kind: :internal,
      attributes: Map.merge(%{
        "coordination.operation" => operation_name,
        "coordination.system" => "self_sustaining",
        "coordination.version" => "0.1.0"
      }, attributes)
    })
    
    # Add coordination-specific metadata
    Span.set_attributes(span_ctx, %{
      "coordination.timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "coordination.node" => Node.self(),
      "coordination.process" => inspect(self())
    })
    
    Logger.metadata(trace_id: get_trace_id(), span_id: get_span_id())
    
    span_ctx
  end

  @doc """
  End a coordination span with result status
  """
  def end_coordination_span(span_ctx, status \\ :ok, result \\ nil) do
    case status do
      :ok ->
        Span.set_status(span_ctx, OpenTelemetry.status(:ok))
        if result, do: Span.set_attribute(span_ctx, "coordination.result", inspect(result))
      :error ->
        Span.set_status(span_ctx, OpenTelemetry.status(:error, "Coordination operation failed"))
        if result, do: Span.set_attribute(span_ctx, "coordination.error", inspect(result))
      {:error, reason} ->
        Span.set_status(span_ctx, OpenTelemetry.status(:error, "Coordination error: #{inspect(reason)}"))
        Span.set_attribute(span_ctx, "coordination.error", inspect(reason))
    end
    
    Tracer.end_span(@tracer_id, span_ctx)
  end

  @doc """
  Execute a function within a coordination span
  """
  def with_coordination_span(operation_name, attributes \\ %{}, fun) do
    span_ctx = start_coordination_span(operation_name, attributes)
    
    try do
      result = fun.()
      end_coordination_span(span_ctx, :ok, result)
      result
    rescue
      error ->
        end_coordination_span(span_ctx, {:error, error})
        reraise error, __STACKTRACE__
    catch
      :exit, reason ->
        end_coordination_span(span_ctx, {:error, {:exit, reason}})
        exit(reason)
      :throw, value ->
        end_coordination_span(span_ctx, {:error, {:throw, value}})
        throw(value)
    end
  end

  @doc """
  Add coordination event to current span
  """
  def add_coordination_event(name, attributes \\ %{}) do
    event_attributes = Map.merge(%{
      "coordination.event" => name,
      "coordination.timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }, attributes)
    
    Span.add_event(OpenTelemetry.Tracer.current_span_ctx(@tracer_id), name, event_attributes)
  end

  @doc """
  Get current trace ID for coordination logging
  """
  def get_trace_id do
    case OpenTelemetry.Tracer.current_span_ctx(@tracer_id) do
      :undefined -> "no-trace"
      span_ctx -> 
        trace_id = Span.trace_id(span_ctx)
        if trace_id == :undefined do
          "no-trace"
        else
          Integer.to_string(trace_id, 16) |> String.downcase()
        end
    end
  end

  @doc """
  Get current span ID for coordination logging
  """
  def get_span_id do
    case OpenTelemetry.Tracer.current_span_ctx(@tracer_id) do
      :undefined -> "no-span"
      span_ctx -> 
        span_id = Span.span_id(span_ctx)
        if span_id == :undefined do
          "no-span"
        else
          Integer.to_string(span_id, 16) |> String.downcase()
        end
    end
  end

  @doc """
  Create correlation context for agent coordination boundaries
  """
  def create_coordination_context(agent_id, work_type, metadata \\ %{}) do
    trace_id = get_trace_id()
    
    coordination_context = %{
      trace_id: trace_id,
      span_id: get_span_id(),
      agent_id: agent_id,
      work_type: work_type,
      coordination_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      correlation_data: metadata
    }
    
    # Emit telemetry event for coordination boundary crossing
    :telemetry.execute(
      [:coordination, :boundary, :crossed],
      %{count: 1},
      coordination_context
    )
    
    coordination_context
  end

  @doc """
  Propagate trace context across coordination boundaries
  """
  def propagate_trace_context(context) do
    case Map.get(context, :trace_id) do
      nil -> 
        Logger.warning("No trace_id in coordination context for propagation")
        context
      trace_id ->
        Logger.metadata(trace_id: trace_id, span_id: Map.get(context, :span_id))
        
        # Add span if we have trace context
        if span_id = Map.get(context, :span_id) do
          add_coordination_event("context_propagated", %{
            "agent_id" => Map.get(context, :agent_id),
            "work_type" => Map.get(context, :work_type)
          })
        end
        
        context
    end
  end

  @doc """
  Instrument agent coordination operations with distributed tracing
  """
  def instrument_agent_operation(agent_id, operation, work_data, fun) do
    attributes = %{
      "agent.id" => agent_id,
      "agent.operation" => operation,
      "agent.work_type" => Map.get(work_data, :work_type, "unknown"),
      "agent.priority" => Map.get(work_data, :priority, "medium")
    }
    
    with_coordination_span("agent.#{operation}", attributes, fn ->
      # Create coordination context
      context = create_coordination_context(agent_id, operation, work_data)
      
      # Propagate context and execute
      context |> propagate_trace_context()
      
      result = fun.(context)
      
      # Emit completion event
      :telemetry.execute(
        [:coordination, :agent, :operation, :completed],
        %{duration: 1},
        Map.merge(context, %{result: result})
      )
      
      result
    end)
  end
end