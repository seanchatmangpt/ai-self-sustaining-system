defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.SamplingStep do
  @moduledoc """
  Applies intelligent sampling strategies to telemetry data.
  Supports multiple sampling algorithms:
  - Probabilistic sampling
  - Rate limiting
  - Tail-based sampling
  - Error-biased sampling
  - Service-aware sampling
  """
  
  use Reactor.Step
  require Logger
  
  @default_sampling_rate 0.1  # 10% sampling by default
  @error_sampling_rate 1.0    # Always sample errors
  @critical_service_rate 0.5  # 50% for critical services
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    enriched_data = Map.get(arguments, :enriched_data)
    config = Map.get(arguments, :config, %{})
    
    start_time = System.monotonic_time()
    trace_id = Map.get(enriched_data, :trace_id)
    
    # Emit sampling start telemetry
    :telemetry.execute([:otlp_pipeline, :sampling, :start], %{
      traces_count: count_traces(enriched_data),
      metrics_count: count_metrics(enriched_data),
      logs_count: count_logs(enriched_data),
      timestamp: System.system_time(:microsecond)
    }, %{context: context, trace_id: trace_id})
    
    try do
      # Apply sampling strategies
      sampled_traces = apply_trace_sampling(enriched_data, config)
      sampled_metrics = apply_metric_sampling(enriched_data, config)
      sampled_logs = apply_log_sampling(enriched_data, config)
      
      # Calculate sampling statistics
      sampling_stats = calculate_sampling_stats(enriched_data, sampled_traces, sampled_metrics, sampled_logs)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        traces: sampled_traces,
        metrics: sampled_metrics,
        logs: sampled_logs,
        sampling_stats: Map.put(sampling_stats, :processing_time_ms, 
          System.convert_time_unit(processing_time, :native, :millisecond)),
        sampling_config: extract_sampling_config(config),
        original_enriched_data: enriched_data,
        trace_id: trace_id,
        timestamp: DateTime.utc_now()
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :sampling, :success], %{
        traces_sampled: sampling_stats.traces_sampled,
        metrics_sampled: sampling_stats.metrics_sampled,
        logs_sampled: sampling_stats.logs_sampled,
        sampling_rate: sampling_stats.overall_sampling_rate,
        processing_time_ms: sampling_stats.processing_time_ms
      }, %{context: context, trace_id: trace_id})
      
      Logger.info("Sampling completed: #{sampling_stats.traces_sampled}/#{sampling_stats.traces_total} traces, " <>
                  "#{sampling_stats.metrics_sampled}/#{sampling_stats.metrics_total} metrics, " <>
                  "#{sampling_stats.logs_sampled}/#{sampling_stats.logs_total} logs")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          stage: "sampling"
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :sampling, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: context, error: error_details, trace_id: trace_id})
        
        Logger.error("Sampling failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options) do
    # No specific cleanup needed for sampling
    :ok
  end
  
  # Trace sampling strategies
  
  defp apply_trace_sampling(enriched_data, config) do
    traces = extract_traces_from_enriched_data(enriched_data)
    sampling_strategy = Map.get(config, :trace_sampling_strategy, :probabilistic)
    
    case sampling_strategy do
      :probabilistic -> apply_probabilistic_trace_sampling(traces, config)
      :tail_based -> apply_tail_based_trace_sampling(traces, config)
      :error_biased -> apply_error_biased_trace_sampling(traces, config)
      :service_aware -> apply_service_aware_trace_sampling(traces, config)
      :rate_limited -> apply_rate_limited_trace_sampling(traces, config)
      _ -> apply_probabilistic_trace_sampling(traces, config)
    end
  end
  
  defp apply_probabilistic_trace_sampling(traces, config) do
    sampling_rate = Map.get(config, :trace_sampling_rate, @default_sampling_rate)
    
    traces
    |> Enum.filter(fn trace ->
      # Use trace ID for deterministic sampling
      trace_id = Map.get(trace, :trace_id, "")
      hash_value = :erlang.phash2(trace_id, 1000)
      hash_value < (sampling_rate * 1000)
    end)
  end
  
  defp apply_tail_based_trace_sampling(traces, config) do
    # Sample based on complete trace characteristics
    error_rate = Map.get(config, :error_sampling_rate, @error_sampling_rate)
    default_rate = Map.get(config, :trace_sampling_rate, @default_sampling_rate)
    
    traces
    |> Enum.filter(fn trace ->
      cond do
        # Always sample error traces
        trace_has_errors?(trace) -> 
          sample_with_rate(trace, error_rate)
        
        # Sample slow traces more frequently
        trace_is_slow?(trace, config) ->
          sample_with_rate(trace, default_rate * 2)
        
        # Default sampling
        true ->
          sample_with_rate(trace, default_rate)
      end
    end)
  end
  
  defp apply_error_biased_trace_sampling(traces, config) do
    error_rate = Map.get(config, :error_sampling_rate, @error_sampling_rate)
    success_rate = Map.get(config, :success_sampling_rate, @default_sampling_rate)
    
    traces
    |> Enum.filter(fn trace ->
      if trace_has_errors?(trace) do
        sample_with_rate(trace, error_rate)
      else
        sample_with_rate(trace, success_rate)
      end
    end)
  end
  
  defp apply_service_aware_trace_sampling(traces, config) do
    service_rates = Map.get(config, :service_sampling_rates, %{})
    default_rate = Map.get(config, :trace_sampling_rate, @default_sampling_rate)
    
    traces
    |> Enum.filter(fn trace ->
      primary_service = get_primary_service(trace)
      sampling_rate = Map.get(service_rates, primary_service, default_rate)
      sample_with_rate(trace, sampling_rate)
    end)
  end
  
  defp apply_rate_limited_trace_sampling(traces, config) do
    max_traces_per_second = Map.get(config, :max_traces_per_second, 1000)
    current_second = System.system_time(:second)
    
    # Simple rate limiting - in production, use more sophisticated algorithms
    traces
    |> Enum.take(max_traces_per_second)
  end
  
  # Metric sampling strategies
  
  defp apply_metric_sampling(enriched_data, config) do
    metrics = extract_metrics_from_enriched_data(enriched_data)
    sampling_strategy = Map.get(config, :metric_sampling_strategy, :time_based)
    
    case sampling_strategy do
      :time_based -> apply_time_based_metric_sampling(metrics, config)
      :value_based -> apply_value_based_metric_sampling(metrics, config)
      :statistical -> apply_statistical_metric_sampling(metrics, config)
      _ -> apply_time_based_metric_sampling(metrics, config)
    end
  end
  
  defp apply_time_based_metric_sampling(metrics, config) do
    sampling_interval = Map.get(config, :metric_sampling_interval_seconds, 60)
    current_time = System.system_time(:second)
    
    # Sample metrics at regular intervals
    metrics
    |> Enum.filter(fn {metric_name, metric_data} ->
      # Use metric name and time for deterministic sampling
      hash_value = :erlang.phash2({metric_name, div(current_time, sampling_interval)}, 100)
      hash_value < 10  # 10% sampling
    end)
    |> Enum.into(%{})
  end
  
  defp apply_value_based_metric_sampling(metrics, config) do
    # Sample based on metric value significance
    threshold_config = Map.get(config, :metric_value_thresholds, %{})
    
    metrics
    |> Enum.filter(fn {metric_name, metric_data} ->
      threshold = Map.get(threshold_config, metric_name, 0)
      has_significant_values?(metric_data, threshold)
    end)
    |> Enum.into(%{})
  end
  
  defp apply_statistical_metric_sampling(metrics, config) do
    # Sample based on statistical significance
    sample_rate = Map.get(config, :metric_sampling_rate, 0.1)
    
    metrics
    |> Enum.filter(fn {metric_name, _metric_data} ->
      hash_value = :erlang.phash2(metric_name, 1000)
      hash_value < (sample_rate * 1000)
    end)
    |> Enum.into(%{})
  end
  
  # Log sampling strategies
  
  defp apply_log_sampling(enriched_data, config) do
    logs = extract_logs_from_enriched_data(enriched_data)
    sampling_strategy = Map.get(config, :log_sampling_strategy, :severity_based)
    
    case sampling_strategy do
      :severity_based -> apply_severity_based_log_sampling(logs, config)
      :probabilistic -> apply_probabilistic_log_sampling(logs, config)
      :burst_detection -> apply_burst_detection_log_sampling(logs, config)
      _ -> apply_severity_based_log_sampling(logs, config)
    end
  end
  
  defp apply_severity_based_log_sampling(logs, config) do
    severity_rates = Map.get(config, :log_severity_sampling_rates, %{
      "ERROR" => 1.0,     # Always sample errors
      "WARN" => 0.5,      # 50% of warnings
      "INFO" => 0.1,      # 10% of info logs
      "DEBUG" => 0.01     # 1% of debug logs
    })
    
    logs
    |> Enum.filter(fn log ->
      severity = Map.get(log, "severity", "INFO")
      sampling_rate = Map.get(severity_rates, severity, 0.1)
      sample_with_rate(log, sampling_rate)
    end)
  end
  
  defp apply_probabilistic_log_sampling(logs, config) do
    sampling_rate = Map.get(config, :log_sampling_rate, 0.1)
    
    logs
    |> Enum.filter(fn log ->
      sample_with_rate(log, sampling_rate)
    end)
  end
  
  defp apply_burst_detection_log_sampling(logs, config) do
    # Detect log bursts and sample differently
    burst_threshold = Map.get(config, :log_burst_threshold, 100)
    burst_sampling_rate = Map.get(config, :log_burst_sampling_rate, 0.01)
    normal_sampling_rate = Map.get(config, :log_sampling_rate, 0.1)
    
    if length(logs) > burst_threshold do
      # Apply aggressive sampling during bursts
      logs
      |> Enum.filter(fn log ->
        sample_with_rate(log, burst_sampling_rate)
      end)
    else
      # Normal sampling
      logs
      |> Enum.filter(fn log ->
        sample_with_rate(log, normal_sampling_rate)
      end)
    end
  end
  
  # Helper functions
  
  defp extract_traces_from_enriched_data(enriched_data) do
    enriched_data
    |> Map.get(:original_data, %{})
    |> Map.get(:traces, %{})
    |> Map.get(:traces, [])
  end
  
  defp extract_metrics_from_enriched_data(enriched_data) do
    enriched_data
    |> Map.get(:original_data, %{})
    |> Map.get(:metrics, %{})
    |> Map.get(:metrics, %{})
  end
  
  defp extract_logs_from_enriched_data(enriched_data) do
    enriched_data
    |> Map.get(:original_data, %{})
    |> Map.get(:logs, %{})
    |> Map.get(:logs, [])
  end
  
  defp sample_with_rate(item, rate) do
    # Generate deterministic hash for consistent sampling
    item_id = extract_item_id(item)
    hash_value = :erlang.phash2(item_id, 1000)
    hash_value < (rate * 1000)
  end
  
  defp extract_item_id(item) when is_map(item) do
    Map.get(item, :trace_id) || 
    Map.get(item, "traceId") ||
    Map.get(item, :id) ||
    Map.get(item, "timestamp") ||
    :crypto.strong_rand_bytes(8)
  end
  defp extract_item_id(_), do: :crypto.strong_rand_bytes(8)
  
  defp trace_has_errors?(trace) do
    trace
    |> Map.get(:spans, [])
    |> Enum.any?(&span_has_error?/1)
  end
  
  defp span_has_error?(span) do
    status = Map.get(span, "status", %{})
    Map.get(status, "code") == "ERROR" or Map.get(status, "code") == 2
  end
  
  defp trace_is_slow?(trace, config) do
    slow_threshold_ns = Map.get(config, :slow_trace_threshold_ns, 1_000_000_000)  # 1 second
    duration = Map.get(trace, :duration_ns, 0)
    duration > slow_threshold_ns
  end
  
  defp get_primary_service(trace) do
    trace
    |> Map.get(:services, [])
    |> List.first()
    |> case do
      nil -> "unknown"
      service -> service
    end
  end
  
  defp has_significant_values?(metric_data, threshold) do
    metric_data
    |> Enum.any?(fn metric ->
      metric
      |> Map.get("data_points", [])
      |> Enum.any?(&(extract_metric_value(&1) > threshold))
    end)
  end
  
  defp extract_metric_value(data_point) do
    cond do
      Map.has_key?(data_point, "asInt") -> Map.get(data_point, "asInt", 0)
      Map.has_key?(data_point, "asDouble") -> Map.get(data_point, "asDouble", 0.0)
      true -> 0
    end
  end
  
  defp count_traces(enriched_data), do: length(extract_traces_from_enriched_data(enriched_data))
  defp count_metrics(enriched_data), do: map_size(extract_metrics_from_enriched_data(enriched_data))
  defp count_logs(enriched_data), do: length(extract_logs_from_enriched_data(enriched_data))
  
  defp calculate_sampling_stats(original_data, sampled_traces, sampled_metrics, sampled_logs) do
    traces_total = count_traces(original_data)
    metrics_total = count_metrics(original_data)
    logs_total = count_logs(original_data)
    
    traces_sampled = length(sampled_traces)
    metrics_sampled = map_size(sampled_metrics)
    logs_sampled = length(sampled_logs)
    
    total_original = traces_total + metrics_total + logs_total
    total_sampled = traces_sampled + metrics_sampled + logs_sampled
    
    %{
      traces_total: traces_total,
      traces_sampled: traces_sampled,
      traces_sampling_rate: if(traces_total > 0, do: traces_sampled / traces_total, else: 0),
      
      metrics_total: metrics_total,
      metrics_sampled: metrics_sampled,
      metrics_sampling_rate: if(metrics_total > 0, do: metrics_sampled / metrics_total, else: 0),
      
      logs_total: logs_total,
      logs_sampled: logs_sampled,
      logs_sampling_rate: if(logs_total > 0, do: logs_sampled / logs_total, else: 0),
      
      overall_sampling_rate: if(total_original > 0, do: total_sampled / total_original, else: 0),
      data_reduction_percentage: if(total_original > 0, do: (1 - total_sampled / total_original) * 100, else: 0)
    }
  end
  
  defp extract_sampling_config(config) do
    %{
      trace_strategy: Map.get(config, :trace_sampling_strategy, :probabilistic),
      trace_rate: Map.get(config, :trace_sampling_rate, @default_sampling_rate),
      metric_strategy: Map.get(config, :metric_sampling_strategy, :time_based),
      log_strategy: Map.get(config, :log_sampling_strategy, :severity_based),
      error_rate: Map.get(config, :error_sampling_rate, @error_sampling_rate)
    }
  end
end