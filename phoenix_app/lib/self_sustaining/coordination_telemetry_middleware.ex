defmodule SelfSustaining.CoordinationTelemetryMiddleware do
  @moduledoc """
  Coordination Telemetry Middleware for Enhanced PromEx + OpenTelemetry Integration

  This middleware provides seamless integration between the agent coordination system,
  PromEx metrics, and OpenTelemetry distributed tracing. It ensures that every
  coordination operation is properly traced and measured for comprehensive observability.

  ## Features

  - **Distributed Trace Correlation**: Links PromEx metrics with OpenTelemetry spans
  - **Coordination Context Propagation**: Maintains trace context across agent operations
  - **Performance Monitoring**: Real-time coordination performance tracking
  - **Error Correlation**: Links coordination errors across telemetry systems
  - **Business Value Tracking**: Correlates coordination metrics with business outcomes

  ## Integration Points

  - Agent coordination system (coordination_helper.sh)
  - PromEx metrics collection and export
  - OpenTelemetry span creation and context propagation
  - Phoenix telemetry events
  - Reactor workflow telemetry

  ## Usage

  Add to your coordination pipeline:

      defmodule MyCoordinationPipeline do
        use SelfSustaining.CoordinationTelemetryMiddleware

        def coordinate_work(work_item) do
          with_coordination_telemetry("work_coordination", %{work_type: work_item.type}) do
            # Your coordination logic here
            perform_coordination(work_item)
          end
        end
      end

  ## Metrics Generated

  This middleware automatically generates:
  - PromEx coordination metrics (duration, success rate, etc.)
  - OpenTelemetry spans with coordination context
  - Telemetry events for downstream consumers
  - Error traces with full coordination context
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer
  require OpenTelemetry.Span, as: Span

  @doc """
  Wraps coordination operations with comprehensive telemetry.

  Generates both PromEx metrics and OpenTelemetry spans with proper
  context correlation for enhanced observability.
  """
  defmacro with_coordination_telemetry(operation_name, metadata \\ %{}, do: block) do
    quote do
      operation_name = unquote(operation_name)
      metadata = unquote(metadata)
      
      start_time = System.monotonic_time(:millisecond)
      trace_id = generate_trace_id()
      
      # Start OpenTelemetry span
      span_name = "coordination.#{operation_name}"
      
      Tracer.with_span span_name do
        # Set span attributes for coordination context
        coordination_attributes = %{
          "coordination.operation" => operation_name,
          "coordination.agent_id" => Map.get(metadata, :agent_id, get_current_agent_id()),
          "coordination.team" => Map.get(metadata, :team, "default"),
          "coordination.work_type" => Map.get(metadata, :work_type, "general"),
          "coordination.priority" => Map.get(metadata, :priority, "medium"),
          "coordination.trace_id" => trace_id,
          "service.name" => "ai_self_sustaining_system",
          "service.version" => "0.1.0"
        }
        
        Enum.each(coordination_attributes, fn {key, value} ->
          Span.set_attribute(key, value)
        end)
        
        # Execute the coordination operation
        try do
          result = unquote(block)
          
          end_time = System.monotonic_time(:millisecond)
          duration = end_time - start_time
          
          # Record successful operation metrics
          record_coordination_success(operation_name, metadata, duration, trace_id)
          
          # Set span status to OK
          Span.set_status(:ok)
          Span.set_attribute("coordination.success", true)
          Span.set_attribute("coordination.duration_ms", duration)
          
          result
        rescue
          error ->
            end_time = System.monotonic_time(:millisecond)
            duration = end_time - start_time
            
            # Record error metrics
            record_coordination_error(operation_name, metadata, error, duration, trace_id)
            
            # Set span status to error
            Span.set_status(:error, Exception.message(error))
            Span.set_attribute("coordination.success", false)
            Span.set_attribute("coordination.error", Exception.message(error))
            Span.set_attribute("coordination.duration_ms", duration)
            
            reraise error, __STACKTRACE__
        end
      end
    end
  end

  @doc """
  Records coordination operation success metrics.

  Integrates PromEx metrics with OpenTelemetry context for complete observability.
  """
  def record_coordination_success(operation_name, metadata, duration, trace_id) do
    # Get current OpenTelemetry context
    otel_span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    otel_trace_id = if otel_span_ctx, do: otel_span_ctx |> elem(0) |> Integer.to_string(16), else: nil
    
    # Enhanced metadata with telemetry correlation
    enhanced_metadata = 
      metadata
      |> Map.put(:trace_id, trace_id)
      |> Map.put(:otel_trace_id, otel_trace_id)
      |> Map.put(:duration, duration)
      |> Map.put(:status, "success")
      |> Map.put(:operation_type, operation_name)
    
    # Record PromEx coordination metric
    SelfSustaining.PromEx.record_coordination_metric(:operation_completed, enhanced_metadata)
    
    # Emit telemetry event for coordination success
    :telemetry.execute(
      [:self_sustaining, :coordination, :operation, :completed],
      %{duration: duration, success: true},
      enhanced_metadata
    )
    
    # Emit OpenTelemetry event for cross-system correlation
    :telemetry.execute(
      [:opentelemetry, :coordination, :operation, :success],
      %{duration: duration},
      enhanced_metadata
    )
    
    Logger.info("Coordination operation completed successfully",
      operation: operation_name,
      duration_ms: duration,
      trace_id: trace_id,
      otel_trace_id: otel_trace_id
    )
  end

  @doc """
  Records coordination operation error metrics.

  Provides comprehensive error tracking across PromEx and OpenTelemetry systems.
  """
  def record_coordination_error(operation_name, metadata, error, duration, trace_id) do
    # Get current OpenTelemetry context
    otel_span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    otel_trace_id = if otel_span_ctx, do: otel_span_ctx |> elem(0) |> Integer.to_string(16), else: nil
    
    # Enhanced error metadata
    error_metadata = 
      metadata
      |> Map.put(:trace_id, trace_id)
      |> Map.put(:otel_trace_id, otel_trace_id)
      |> Map.put(:duration, duration)
      |> Map.put(:status, "error")
      |> Map.put(:operation_type, operation_name)
      |> Map.put(:error_type, error.__struct__ |> Module.split() |> List.last())
      |> Map.put(:error_message, Exception.message(error))
    
    # Record PromEx error metric
    :telemetry.execute(
      [:prom_ex, :plugin, :self_sustaining_coordination_errors, :inc],
      %{},
      %{labels: error_metadata}
    )
    
    # Emit telemetry event for coordination error
    :telemetry.execute(
      [:self_sustaining, :coordination, :operation, :failed],
      %{duration: duration, success: false},
      error_metadata
    )
    
    # Emit OpenTelemetry error event
    :telemetry.execute(
      [:opentelemetry, :coordination, :operation, :error],
      %{duration: duration},
      error_metadata
    )
    
    Logger.error("Coordination operation failed",
      operation: operation_name,
      error: Exception.message(error),
      duration_ms: duration,
      trace_id: trace_id,
      otel_trace_id: otel_trace_id
    )
  end

  @doc """
  Creates a coordination span with proper context propagation.

  Useful for manual span creation in coordination operations.
  """
  def create_coordination_span(span_name, attributes \\ %{}) do
    full_span_name = "coordination.#{span_name}"
    
    coordination_attributes = Map.merge(%{
      "coordination.operation" => span_name,
      "service.name" => "ai_self_sustaining_system",
      "service.component" => "coordination"
    }, attributes)
    
    Tracer.start_span(full_span_name, %{attributes: coordination_attributes})
  end

  @doc """
  Injects coordination context into external HTTP requests.

  Ensures trace propagation when coordination system makes external calls.
  """
  def inject_coordination_headers(headers \\ []) do
    # Get current trace context
    trace_id = generate_trace_id()
    otel_span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    
    coordination_headers = [
      {"x-coordination-trace-id", trace_id},
      {"x-coordination-system", "ai-self-sustaining"},
      {"x-coordination-version", "0.1.0"}
    ]
    
    # Add OpenTelemetry trace headers if span context exists
    otel_headers = if otel_span_ctx do
      otel_trace_id = otel_span_ctx |> elem(0) |> Integer.to_string(16)
      [
        {"traceparent", format_traceparent(otel_trace_id, otel_span_ctx)},
        {"tracestate", "coordination=#{trace_id}"}
      ]
    else
      []
    end
    
    headers ++ coordination_headers ++ otel_headers
  end

  @doc """
  Extracts coordination context from incoming requests.

  Used for maintaining trace context across coordination boundaries.
  """
  def extract_coordination_context(headers) when is_list(headers) do
    headers_map = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)
    
    %{
      coordination_trace_id: Map.get(headers_map, "x-coordination-trace-id"),
      otel_trace_id: extract_otel_trace_id(headers_map),
      coordination_system: Map.get(headers_map, "x-coordination-system"),
      agent_id: Map.get(headers_map, "x-coordination-agent-id"),
      team: Map.get(headers_map, "x-coordination-team")
    }
  end

  ## Private Functions

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_current_agent_id do
    # Try to get agent ID from various sources
    System.get_env("COORDINATION_AGENT_ID") ||
      Process.get(:coordination_agent_id) ||
      "agent_#{System.system_time(:nanosecond)}"
  end

  defp format_traceparent(trace_id, span_ctx) do
    span_id = span_ctx |> elem(1) |> Integer.to_string(16)
    flags = if elem(span_ctx, 2), do: "01", else: "00"
    "00-#{trace_id}-#{span_id}-#{flags}"
  end

  defp extract_otel_trace_id(headers_map) do
    case Map.get(headers_map, "traceparent") do
      "00-" <> <<trace_id::binary-size(32), "-", _rest::binary>> -> trace_id
      _ -> nil
    end
  end

  @doc """
  Provides a using macro for easy integration.
  """
  defmacro __using__(_opts) do
    quote do
      import SelfSustaining.CoordinationTelemetryMiddleware
      require SelfSustaining.CoordinationTelemetryMiddleware
    end
  end
end