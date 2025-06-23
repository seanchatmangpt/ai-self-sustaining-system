defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.OtlpParsingStep do
  @moduledoc """
  Parses and validates OTLP (OpenTelemetry Protocol) data structures.
  Extracts spans, metrics, and logs with proper validation and error handling.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    ingested_data = Map.get(arguments, :ingested_data)
    config = Map.get(arguments, :config, %{})
    
    start_time = System.monotonic_time()
    trace_id = get_in(ingested_data, [:trace_id])
    
    # Emit parsing start telemetry
    :telemetry.execute([:otlp_pipeline, :parsing, :start], %{
      records_count: get_in(ingested_data, [:ingestion_stats, :records_count]) || 0,
      timestamp: System.system_time(:microsecond)
    }, %{context: context, trace_id: trace_id})
    
    try do
      # Extract raw data
      raw_data = Map.get(ingested_data, :data, %{})
      
      # Parse different OTLP signal types
      parsed_traces = parse_traces(raw_data, config)
      parsed_metrics = parse_metrics(raw_data, config)
      parsed_logs = parse_logs(raw_data, config)
      
      # Validate parsed data
      validation_results = validate_parsed_data(parsed_traces, parsed_metrics, parsed_logs, config)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        traces: parsed_traces,
        metrics: parsed_metrics,
        logs: parsed_logs,
        validation: validation_results,
        parsing_stats: %{
          traces_count: count_items(parsed_traces),
          metrics_count: count_items(parsed_metrics),
          logs_count: count_items(parsed_logs),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          errors_count: count_validation_errors(validation_results)
        },
        metadata: Map.get(ingested_data, :metadata, %{}),
        trace_id: trace_id,
        timestamp: DateTime.utc_now()
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :parsing, :success], %{
        traces_parsed: result.parsing_stats.traces_count,
        metrics_parsed: result.parsing_stats.metrics_count,
        logs_parsed: result.parsing_stats.logs_count,
        processing_time_ms: result.parsing_stats.processing_time_ms,
        errors_count: result.parsing_stats.errors_count
      }, %{context: context, trace_id: trace_id})
      
      Logger.info("Parsed OTLP data: #{result.parsing_stats.traces_count} traces, #{result.parsing_stats.metrics_count} metrics, #{result.parsing_stats.logs_count} logs")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          stage: "otlp_parsing"
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :parsing, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: context, error: error_details, trace_id: trace_id})
        
        Logger.error("OTLP parsing failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options) do
    # No specific cleanup needed for parsing step
    :ok
  end
  
  # Private parsing functions
  
  defp parse_traces(data, config) do
    resource_spans = Map.get(data, "resourceSpans", [])
    
    traces = 
      resource_spans
      |> Enum.flat_map(&extract_spans_from_resource(&1, config))
      |> group_spans_by_trace_id()
      |> Enum.map(&build_trace_from_spans/1)
    
    %{
      traces: traces,
      total_spans: count_total_spans(resource_spans),
      resource_count: length(resource_spans)
    }
  end
  
  defp parse_metrics(data, config) do
    resource_metrics = Map.get(data, "resourceMetrics", [])
    
    metrics =
      resource_metrics
      |> Enum.flat_map(&extract_metrics_from_resource(&1, config))
      |> group_metrics_by_name()
    
    %{
      metrics: metrics,
      total_data_points: count_total_data_points(resource_metrics),
      resource_count: length(resource_metrics)
    }
  end
  
  defp parse_logs(data, config) do
    resource_logs = Map.get(data, "resourceLogs", [])
    
    logs =
      resource_logs
      |> Enum.flat_map(&extract_logs_from_resource(&1, config))
      |> sort_logs_by_timestamp()
    
    %{
      logs: logs,
      total_records: length(logs),
      resource_count: length(resource_logs)
    }
  end
  
  defp extract_spans_from_resource(resource_span, config) do
    resource = Map.get(resource_span, "resource", %{})
    scope_spans = Map.get(resource_span, "scopeSpans", [])
    
    scope_spans
    |> Enum.flat_map(fn scope_span ->
      scope = Map.get(scope_span, "scope", %{})
      spans = Map.get(scope_span, "spans", [])
      
      Enum.map(spans, fn span ->
        enrich_span_with_context(span, resource, scope, config)
      end)
    end)
  end
  
  defp extract_metrics_from_resource(resource_metric, config) do
    resource = Map.get(resource_metric, "resource", %{})
    scope_metrics = Map.get(resource_metric, "scopeMetrics", [])
    
    scope_metrics
    |> Enum.flat_map(fn scope_metric ->
      scope = Map.get(scope_metric, "scope", %{})
      metrics = Map.get(scope_metric, "metrics", [])
      
      Enum.map(metrics, fn metric ->
        enrich_metric_with_context(metric, resource, scope, config)
      end)
    end)
  end
  
  defp extract_logs_from_resource(resource_log, config) do
    resource = Map.get(resource_log, "resource", %{})
    scope_logs = Map.get(resource_log, "scopeLogs", [])
    
    scope_logs
    |> Enum.flat_map(fn scope_log ->
      scope = Map.get(scope_log, "scope", %{})
      logs = Map.get(scope_log, "logRecords", [])
      
      Enum.map(logs, fn log ->
        enrich_log_with_context(log, resource, scope, config)
      end)
    end)
  end
  
  defp enrich_span_with_context(span, resource, scope, _config) do
    span
    |> Map.put("resource", resource)
    |> Map.put("scope", scope)
    |> Map.put("trace_id", Map.get(span, "traceId"))
    |> Map.put("span_id", Map.get(span, "spanId"))
    |> Map.put("parent_span_id", Map.get(span, "parentSpanId"))
    |> Map.put("start_time", parse_timestamp(Map.get(span, "startTimeUnixNano")))
    |> Map.put("end_time", parse_timestamp(Map.get(span, "endTimeUnixNano")))
    |> Map.put("duration_ns", calculate_span_duration(span))
  end
  
  defp enrich_metric_with_context(metric, resource, scope, _config) do
    metric
    |> Map.put("resource", resource)
    |> Map.put("scope", scope)
    |> Map.put("metric_name", Map.get(metric, "name"))
    |> Map.put("data_points", extract_metric_data_points(metric))
  end
  
  defp enrich_log_with_context(log, resource, scope, _config) do
    log
    |> Map.put("resource", resource)
    |> Map.put("scope", scope)
    |> Map.put("timestamp", parse_timestamp(Map.get(log, "timeUnixNano")))
    |> Map.put("severity", Map.get(log, "severityText"))
    |> Map.put("body", Map.get(log, "body"))
  end
  
  defp group_spans_by_trace_id(spans) do
    spans
    |> Enum.group_by(&Map.get(&1, "trace_id"))
    |> Enum.map(fn {trace_id, trace_spans} ->
      {trace_id, Enum.sort_by(trace_spans, &Map.get(&1, "start_time", 0))}
    end)
  end
  
  defp build_trace_from_spans({trace_id, spans}) do
    root_span = Enum.find(spans, &(Map.get(&1, "parent_span_id") == nil))
    
    %{
      trace_id: trace_id,
      root_span: root_span,
      spans: spans,
      span_count: length(spans),
      start_time: spans |> Enum.map(&Map.get(&1, "start_time", 0)) |> Enum.min(),
      end_time: spans |> Enum.map(&Map.get(&1, "end_time", 0)) |> Enum.max(),
      duration_ns: calculate_trace_duration(spans),
      services: extract_services_from_spans(spans)
    }
  end
  
  defp group_metrics_by_name(metrics) do
    metrics
    |> Enum.group_by(&Map.get(&1, "metric_name"))
  end
  
  defp sort_logs_by_timestamp(logs) do
    logs
    |> Enum.sort_by(&Map.get(&1, "timestamp", 0))
  end
  
  defp extract_metric_data_points(metric) do
    # Extract data points based on metric type
    cond do
      Map.has_key?(metric, "gauge") ->
        Map.get(metric, "gauge", %{}) |> Map.get("dataPoints", [])
      Map.has_key?(metric, "sum") ->
        Map.get(metric, "sum", %{}) |> Map.get("dataPoints", [])
      Map.has_key?(metric, "histogram") ->
        Map.get(metric, "histogram", %{}) |> Map.get("dataPoints", [])
      true ->
        []
    end
  end
  
  defp parse_timestamp(nil), do: 0
  defp parse_timestamp(nano_timestamp) when is_binary(nano_timestamp) do
    case Integer.parse(nano_timestamp) do
      {timestamp, _} -> timestamp
      :error -> 0
    end
  end
  defp parse_timestamp(nano_timestamp) when is_integer(nano_timestamp), do: nano_timestamp
  defp parse_timestamp(_), do: 0
  
  defp calculate_span_duration(span) do
    start_time = parse_timestamp(Map.get(span, "startTimeUnixNano"))
    end_time = parse_timestamp(Map.get(span, "endTimeUnixNano"))
    
    if start_time > 0 and end_time > 0 do
      end_time - start_time
    else
      0
    end
  end
  
  defp calculate_trace_duration(spans) when length(spans) > 0 do
    start_times = Enum.map(spans, &Map.get(&1, "start_time", 0))
    end_times = Enum.map(spans, &Map.get(&1, "end_time", 0))
    
    min_start = Enum.min(start_times)
    max_end = Enum.max(end_times)
    
    if min_start > 0 and max_end > 0 do
      max_end - min_start
    else
      0
    end
  end
  defp calculate_trace_duration(_), do: 0
  
  defp extract_services_from_spans(spans) do
    spans
    |> Enum.map(&get_in(&1, ["resource", "attributes"]))
    |> Enum.filter(& &1)
    |> Enum.map(&extract_service_name/1)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
  
  defp extract_service_name(attributes) when is_list(attributes) do
    service_attr = Enum.find(attributes, &(Map.get(&1, "key") == "service.name"))
    case service_attr do
      %{"value" => %{"stringValue" => service_name}} -> service_name
      _ -> nil
    end
  end
  defp extract_service_name(_), do: nil
  
  defp count_total_spans(resource_spans) do
    resource_spans
    |> Enum.map(fn resource_span ->
      resource_span
      |> Map.get("scopeSpans", [])
      |> Enum.map(&(Map.get(&1, "spans", []) |> length()))
      |> Enum.sum()
    end)
    |> Enum.sum()
  end
  
  defp count_total_data_points(resource_metrics) do
    resource_metrics
    |> Enum.map(fn resource_metric ->
      resource_metric
      |> Map.get("scopeMetrics", [])
      |> Enum.map(fn scope_metric ->
        scope_metric
        |> Map.get("metrics", [])
        |> Enum.map(&count_metric_data_points/1)
        |> Enum.sum()
      end)
      |> Enum.sum()
    end)
    |> Enum.sum()
  end
  
  defp count_metric_data_points(metric) do
    extract_metric_data_points(metric) |> length()
  end
  
  defp validate_parsed_data(traces, metrics, logs, config) do
    trace_validation = validate_traces(traces, config)
    metric_validation = validate_metrics(metrics, config)
    log_validation = validate_logs(logs, config)
    
    %{
      traces: trace_validation,
      metrics: metric_validation,
      logs: log_validation,
      overall_valid: trace_validation.valid and metric_validation.valid and log_validation.valid
    }
  end
  
  defp validate_traces(traces_data, _config) do
    traces = Map.get(traces_data, :traces, [])
    
    # Validate trace structure
    invalid_traces = 
      traces
      |> Enum.reject(&valid_trace?/1)
    
    %{
      valid: length(invalid_traces) == 0,
      total_traces: length(traces),
      invalid_count: length(invalid_traces),
      errors: Enum.map(invalid_traces, &describe_trace_error/1)
    }
  end
  
  defp validate_metrics(metrics_data, _config) do
    metrics = Map.get(metrics_data, :metrics, %{})
    
    # Basic metric validation
    metric_count = map_size(metrics)
    
    %{
      valid: metric_count >= 0,
      total_metrics: metric_count,
      invalid_count: 0,
      errors: []
    }
  end
  
  defp validate_logs(logs_data, _config) do
    logs = Map.get(logs_data, :logs, [])
    
    # Basic log validation
    invalid_logs = 
      logs
      |> Enum.reject(&valid_log?/1)
    
    %{
      valid: length(invalid_logs) == 0,
      total_logs: length(logs),
      invalid_count: length(invalid_logs),
      errors: Enum.map(invalid_logs, &describe_log_error/1)
    }
  end
  
  defp valid_trace?(trace) do
    Map.has_key?(trace, :trace_id) and
    Map.has_key?(trace, :spans) and
    is_list(Map.get(trace, :spans))
  end
  
  defp valid_log?(log) do
    Map.has_key?(log, "timestamp") and
    Map.has_key?(log, "body")
  end
  
  defp describe_trace_error(trace) do
    "Invalid trace structure: #{inspect(Map.take(trace, [:trace_id, :span_count]))}"
  end
  
  defp describe_log_error(log) do
    "Invalid log structure: missing required fields"
  end
  
  defp count_items(%{traces: traces}), do: length(traces)
  defp count_items(%{metrics: metrics}), do: map_size(metrics)
  defp count_items(%{logs: logs}), do: length(logs)
  defp count_items(_), do: 0
  
  defp count_validation_errors(validation) do
    (get_in(validation, [:traces, :invalid_count]) || 0) +
    (get_in(validation, [:metrics, :invalid_count]) || 0) +
    (get_in(validation, [:logs, :invalid_count]) || 0)
  end
end