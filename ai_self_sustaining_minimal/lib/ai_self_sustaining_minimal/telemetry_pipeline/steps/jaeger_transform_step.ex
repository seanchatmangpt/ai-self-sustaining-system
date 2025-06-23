defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.JaegerTransformStep do
  @moduledoc """
  Transforms OTLP telemetry data to Jaeger format.
  Converts spans, traces, and related metadata to Jaeger-compatible JSON structure.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    sampled_data = Map.get(arguments, :sampled_data)
    config = Map.get(arguments, :config, %{})
    
    start_time = System.monotonic_time()
    trace_id = Map.get(sampled_data, :trace_id)
    
    # Emit transformation start telemetry
    :telemetry.execute([:otlp_pipeline, :jaeger_transform, :start], %{
      traces_count: length(Map.get(sampled_data, :traces, [])),
      timestamp: System.system_time(:microsecond)
    }, %{context: context, trace_id: trace_id})
    
    try do
      # Transform traces to Jaeger format
      jaeger_traces = transform_traces_to_jaeger(sampled_data, config)
      
      # Transform metrics to Jaeger format (if applicable)
      jaeger_metrics = transform_metrics_to_jaeger(sampled_data, config)
      
      # Generate Jaeger batch
      jaeger_batch = build_jaeger_batch(jaeger_traces, jaeger_metrics, config)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        jaeger_data: jaeger_batch,
        transform_stats: %{
          traces_transformed: length(jaeger_traces),
          spans_transformed: count_jaeger_spans(jaeger_traces),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          data_size_bytes: estimate_jaeger_size(jaeger_batch)
        },
        format: "jaeger",
        version: "1.0",
        trace_id: trace_id,
        timestamp: DateTime.utc_now()
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :jaeger_transform, :success], %{
        traces_transformed: result.transform_stats.traces_transformed,
        spans_transformed: result.transform_stats.spans_transformed,
        processing_time_ms: result.transform_stats.processing_time_ms,
        data_size_bytes: result.transform_stats.data_size_bytes
      }, %{context: context, trace_id: trace_id})
      
      Logger.debug("Jaeger transformation completed: #{result.transform_stats.traces_transformed} traces, " <>
                   "#{result.transform_stats.spans_transformed} spans")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          stage: "jaeger_transform"
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :jaeger_transform, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: context, error: error_details, trace_id: trace_id})
        
        Logger.error("Jaeger transformation failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options) do
    # No specific cleanup needed for transformation
    :ok
  end
  
  # Private transformation functions
  
  defp transform_traces_to_jaeger(sampled_data, config) do
    traces = Map.get(sampled_data, :traces, [])
    
    traces
    |> Enum.map(&transform_trace_to_jaeger(&1, config))
    |> Enum.reject(&is_nil/1)
  end
  
  defp transform_trace_to_jaeger(trace, config) do
    trace_id = Map.get(trace, :trace_id)
    spans = Map.get(trace, :spans, [])
    
    if trace_id && length(spans) > 0 do
      %{
        traceID: format_jaeger_trace_id(trace_id),
        spans: Enum.map(spans, &transform_span_to_jaeger(&1, config)),
        processes: extract_jaeger_processes(spans, config),
        warnings: []
      }
    else
      nil
    end
  end
  
  defp transform_span_to_jaeger(span, _config) do
    trace_id = Map.get(span, "trace_id") || Map.get(span, "traceId")
    span_id = Map.get(span, "span_id") || Map.get(span, "spanId")
    parent_span_id = Map.get(span, "parent_span_id") || Map.get(span, "parentSpanId")
    
    operation_name = Map.get(span, "name", "unknown")
    start_time = parse_jaeger_timestamp(Map.get(span, "start_time") || Map.get(span, "startTimeUnixNano"))
    duration = Map.get(span, "duration_ns", 0)
    
    # Convert OTLP attributes to Jaeger tags
    tags = convert_attributes_to_jaeger_tags(span)
    
    # Convert OTLP events to Jaeger logs
    logs = convert_events_to_jaeger_logs(span)
    
    # Extract process information
    process_id = extract_process_id(span)
    
    jaeger_span = %{
      traceID: format_jaeger_trace_id(trace_id),
      spanID: format_jaeger_span_id(span_id),
      operationName: operation_name,
      startTime: start_time,
      duration: duration,
      tags: tags,
      logs: logs,
      processID: process_id,
      warnings: []
    }
    
    # Add parent span ID if present
    if parent_span_id do
      Map.put(jaeger_span, :parentSpanID, format_jaeger_span_id(parent_span_id))
    else
      jaeger_span
    end
  end
  
  defp format_jaeger_trace_id(trace_id) when is_binary(trace_id) do
    # Convert hex string to Jaeger format
    case String.length(trace_id) do
      32 -> trace_id  # Already 128-bit hex
      16 -> String.pad_leading(trace_id, 32, "0")  # Pad 64-bit to 128-bit
      _ -> 
        # Hash to create consistent trace ID
        :crypto.hash(:md5, trace_id) |> Base.encode16(case: :lower)
    end
  end
  defp format_jaeger_trace_id(_), do: "00000000000000000000000000000000"
  
  defp format_jaeger_span_id(span_id) when is_binary(span_id) do
    case String.length(span_id) do
      16 -> span_id  # Already 64-bit hex
      _ -> 
        # Hash to create consistent span ID
        :crypto.hash(:sha256, span_id) |> Base.encode16(case: :lower) |> String.slice(0, 16)
    end
  end
  defp format_jaeger_span_id(_), do: "0000000000000000"
  
  defp parse_jaeger_timestamp(nil), do: 0
  defp parse_jaeger_timestamp(timestamp) when is_integer(timestamp) do
    # Convert nanoseconds to microseconds for Jaeger
    div(timestamp, 1000)
  end
  defp parse_jaeger_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {nano_time, _} -> div(nano_time, 1000)
      :error -> 0
    end
  end
  defp parse_jaeger_timestamp(_), do: 0
  
  defp convert_attributes_to_jaeger_tags(span) do
    attributes = Map.get(span, "attributes", [])
    
    # Convert OTLP attributes to Jaeger tags
    otlp_tags = 
      attributes
      |> Enum.map(&convert_otlp_attribute_to_jaeger_tag/1)
      |> Enum.reject(&is_nil/1)
    
    # Add span kind as tag
    span_kind_tag = create_span_kind_tag(span)
    
    # Add status as tags
    status_tags = create_status_tags(span)
    
    # Combine all tags
    [span_kind_tag | status_tags] ++ otlp_tags
    |> Enum.reject(&is_nil/1)
  end
  
  defp convert_otlp_attribute_to_jaeger_tag(attribute) when is_map(attribute) do
    key = Map.get(attribute, "key")
    value = extract_otlp_attribute_value(Map.get(attribute, "value", %{}))
    
    if key && value do
      %{
        key: key,
        type: determine_jaeger_tag_type(value),
        value: to_string(value)
      }
    else
      nil
    end
  end
  defp convert_otlp_attribute_to_jaeger_tag(_), do: nil
  
  defp extract_otlp_attribute_value(value) when is_map(value) do
    cond do
      Map.has_key?(value, "stringValue") -> Map.get(value, "stringValue")
      Map.has_key?(value, "intValue") -> Map.get(value, "intValue")
      Map.has_key?(value, "doubleValue") -> Map.get(value, "doubleValue")
      Map.has_key?(value, "boolValue") -> Map.get(value, "boolValue")
      Map.has_key?(value, "bytesValue") -> Map.get(value, "bytesValue")
      true -> inspect(value)
    end
  end
  defp extract_otlp_attribute_value(value), do: value
  
  defp determine_jaeger_tag_type(value) when is_binary(value), do: "string"
  defp determine_jaeger_tag_type(value) when is_integer(value), do: "number"
  defp determine_jaeger_tag_type(value) when is_float(value), do: "number"
  defp determine_jaeger_tag_type(value) when is_boolean(value), do: "bool"
  defp determine_jaeger_tag_type(_), do: "string"
  
  defp create_span_kind_tag(span) do
    span_kind = Map.get(span, "kind", 0)
    
    kind_name = case span_kind do
      0 -> "SPAN_KIND_UNSPECIFIED"
      1 -> "SPAN_KIND_INTERNAL"
      2 -> "SPAN_KIND_SERVER"
      3 -> "SPAN_KIND_CLIENT"
      4 -> "SPAN_KIND_PRODUCER"
      5 -> "SPAN_KIND_CONSUMER"
      _ -> "SPAN_KIND_UNSPECIFIED"
    end
    
    %{
      key: "span.kind",
      type: "string",
      value: kind_name
    }
  end
  
  defp create_status_tags(span) do
    status = Map.get(span, "status", %{})
    
    tags = []
    
    # Add status code
    tags = if status_code = Map.get(status, "code") do
      status_name = case status_code do
        0 -> "UNSET"
        1 -> "OK"
        2 -> "ERROR"
        _ -> "UNSET"
      end
      
      [%{key: "otel.status_code", type: "string", value: status_name} | tags]
    else
      tags
    end
    
    # Add status message if present
    tags = if status_message = Map.get(status, "message") do
      [%{key: "otel.status_description", type: "string", value: status_message} | tags]
    else
      tags
    end
    
    # Add error tag if status is error
    tags = if Map.get(status, "code") == 2 do
      [%{key: "error", type: "bool", value: "true"} | tags]
    else
      tags
    end
    
    tags
  end
  
  defp convert_events_to_jaeger_logs(span) do
    events = Map.get(span, "events", [])
    
    events
    |> Enum.map(&convert_otlp_event_to_jaeger_log/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp convert_otlp_event_to_jaeger_log(event) when is_map(event) do
    timestamp = parse_jaeger_timestamp(Map.get(event, "timeUnixNano"))
    
    # Convert event attributes to log fields
    fields = 
      event
      |> Map.get("attributes", [])
      |> Enum.map(&convert_otlp_attribute_to_jaeger_tag/1)
      |> Enum.reject(&is_nil/1)
    
    # Add event name as a field
    name_field = %{
      key: "event",
      type: "string",
      value: Map.get(event, "name", "")
    }
    
    %{
      timestamp: timestamp,
      fields: [name_field | fields]
    }
  end
  defp convert_otlp_event_to_jaeger_log(_), do: nil
  
  defp extract_jaeger_processes(spans, _config) do
    # Group spans by service to create process definitions
    spans
    |> Enum.group_by(&extract_process_id/1)
    |> Enum.map(fn {process_id, process_spans} ->
      # Get resource information from first span
      resource = get_span_resource(List.first(process_spans))
      
      {process_id, %{
        serviceName: extract_service_name(resource),
        tags: convert_resource_to_jaeger_tags(resource)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp extract_process_id(span) do
    # Create consistent process ID based on service name and resource
    service_name = extract_service_name(get_span_resource(span))
    "p#{:crypto.hash(:md5, service_name) |> Base.encode16(case: :lower) |> String.slice(0, 8)}"
  end
  
  defp get_span_resource(span) do
    Map.get(span, "resource", %{})
  end
  
  defp extract_service_name(resource) do
    resource
    |> Map.get("attributes", [])
    |> find_service_name_attribute()
    |> case do
      nil -> "unknown_service"
      service_name -> service_name
    end
  end
  
  defp find_service_name_attribute(attributes) when is_list(attributes) do
    service_attr = Enum.find(attributes, &(Map.get(&1, "key") == "service.name"))
    case service_attr do
      %{"value" => %{"stringValue" => service_name}} -> service_name
      _ -> nil
    end
  end
  defp find_service_name_attribute(_), do: nil
  
  defp convert_resource_to_jaeger_tags(resource) do
    resource
    |> Map.get("attributes", [])
    |> Enum.map(&convert_otlp_attribute_to_jaeger_tag/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp transform_metrics_to_jaeger(sampled_data, _config) do
    # Jaeger doesn't directly support metrics, but we can create spans for metric events
    metrics = Map.get(sampled_data, :metrics, %{})
    
    # Convert significant metrics to trace events (optional)
    []
  end
  
  defp build_jaeger_batch(jaeger_traces, _jaeger_metrics, _config) do
    %{
      data: jaeger_traces,
      total: length(jaeger_traces)
    }
  end
  
  defp count_jaeger_spans(jaeger_traces) do
    jaeger_traces
    |> Enum.map(&length(Map.get(&1, :spans, [])))
    |> Enum.sum()
  end
  
  defp estimate_jaeger_size(jaeger_batch) do
    jaeger_batch
    |> Jason.encode!()
    |> byte_size()
  rescue
    _ -> 0
  end
end