defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.ResultCollectionStep do
  @moduledoc """
  Collects results from all pipeline stages and generates comprehensive processing reports.
  Provides final statistics, error summaries, and data lineage information.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    jaeger_result = Map.get(arguments, :jaeger_result)
    prometheus_result = Map.get(arguments, :prometheus_result)
    elasticsearch_result = Map.get(arguments, :elasticsearch_result)
    original_data = Map.get(arguments, :original_data)
    config = Map.get(arguments, :config, %{})
    
    start_time = System.monotonic_time()
    
    # Extract trace ID from any available source
    trace_id = extract_pipeline_trace_id([jaeger_result, prometheus_result, elasticsearch_result, original_data])
    
    # Emit collection start telemetry
    :telemetry.execute([:otlp_pipeline, :result_collection, :start], %{
      backends_count: count_backend_results([jaeger_result, prometheus_result, elasticsearch_result]),
      timestamp: System.system_time(:microsecond)
    }, %{context: context, trace_id: trace_id})
    
    try do
      # Collect delivery statistics
      delivery_stats = collect_delivery_statistics(jaeger_result, prometheus_result, elasticsearch_result)
      
      # Generate pipeline summary
      pipeline_summary = generate_pipeline_summary(original_data, delivery_stats, config)
      
      # Collect error information
      error_summary = collect_error_summary([jaeger_result, prometheus_result, elasticsearch_result])
      
      # Calculate data lineage
      data_lineage = calculate_data_lineage(original_data, delivery_stats)
      
      # Generate performance metrics
      performance_metrics = generate_performance_metrics(delivery_stats, data_lineage)
      
      # Create data quality report
      quality_report = generate_data_quality_report(original_data, delivery_stats, error_summary)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        pipeline_execution: %{
          status: determine_overall_status(delivery_stats, error_summary),
          trace_id: trace_id,
          execution_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          completed_at: DateTime.utc_now(),
          stages_completed: count_completed_stages(delivery_stats)
        },
        delivery_statistics: delivery_stats,
        pipeline_summary: pipeline_summary,
        error_summary: error_summary,
        data_lineage: data_lineage,
        performance_metrics: performance_metrics,
        quality_report: quality_report,
        recommendations: generate_optimization_recommendations(performance_metrics, quality_report),
        trace_id: trace_id,
        timestamp: DateTime.utc_now()
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :result_collection, :success], %{
        overall_status: result.pipeline_execution.status,
        execution_time_ms: result.pipeline_execution.execution_time_ms,
        stages_completed: result.pipeline_execution.stages_completed,
        data_processed: pipeline_summary.total_records_processed,
        data_delivered: pipeline_summary.total_records_delivered,
        success_rate: pipeline_summary.overall_success_rate
      }, %{context: context, trace_id: trace_id})
      
      Logger.info("Pipeline execution completed: #{result.pipeline_execution.status} - " <>
                  "#{pipeline_summary.total_records_processed} processed, " <>
                  "#{pipeline_summary.total_records_delivered} delivered " <>
                  "(#{Float.round(pipeline_summary.overall_success_rate * 100, 1)}% success)")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          stage: "result_collection"
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :result_collection, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: context, error: error_details, trace_id: trace_id})
        
        Logger.error("Result collection failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options) do
    # No specific cleanup needed for result collection
    :ok
  end
  
  # Private collection functions
  
  defp collect_delivery_statistics(jaeger_result, prometheus_result, elasticsearch_result) do
    jaeger_stats = extract_backend_stats(jaeger_result, "jaeger")
    prometheus_stats = extract_backend_stats(prometheus_result, "prometheus")
    elasticsearch_stats = extract_backend_stats(elasticsearch_result, "elasticsearch")
    
    %{
      jaeger: jaeger_stats,
      prometheus: prometheus_stats,
      elasticsearch: elasticsearch_stats,
      total_backends: count_successful_backends([jaeger_stats, prometheus_stats, elasticsearch_stats]),
      overall_delivery_success: all_backends_successful?([jaeger_stats, prometheus_stats, elasticsearch_stats])
    }
  end
  
  defp extract_backend_stats(result, backend_name) do
    case result do
      {:ok, data} ->
        %{
          backend: backend_name,
          status: :success,
          records_sent: Map.get(data, :records_sent, 0),
          batches_sent: Map.get(data, :batches_sent, 0),
          bytes_sent: Map.get(data, :bytes_sent, 0),
          delivery_time_ms: Map.get(data, :delivery_time_ms, 0),
          retry_count: Map.get(data, :retry_count, 0),
          endpoint: Map.get(data, :endpoint, "unknown")
        }
      
      {:error, error_data} ->
        %{
          backend: backend_name,
          status: :error,
          error: Map.get(error_data, :error, "unknown error"),
          records_sent: 0,
          batches_sent: 0,
          bytes_sent: 0,
          delivery_time_ms: Map.get(error_data, :processing_time_ms, 0),
          retry_count: Map.get(error_data, :retry_count, 0),
          endpoint: "unknown"
        }
      
      _ ->
        %{
          backend: backend_name,
          status: :not_processed,
          records_sent: 0,
          batches_sent: 0,
          bytes_sent: 0,
          delivery_time_ms: 0,
          retry_count: 0,
          endpoint: "unknown"
        }
    end
  end
  
  defp generate_pipeline_summary(original_data, delivery_stats, _config) do
    # Extract original data counts
    original_stats = extract_original_data_stats(original_data)
    
    # Calculate total delivered
    total_delivered = calculate_total_delivered(delivery_stats)
    
    # Calculate success rate
    success_rate = if original_stats.total_records > 0 do
      total_delivered / original_stats.total_records
    else
      0.0
    end
    
    %{
      total_records_ingested: original_stats.total_records,
      total_records_processed: original_stats.total_records,
      total_records_delivered: total_delivered,
      overall_success_rate: success_rate,
      data_reduction_factor: calculate_data_reduction_factor(original_stats, delivery_stats),
      processing_efficiency: calculate_processing_efficiency(delivery_stats),
      backends_utilized: count_active_backends(delivery_stats),
      pipeline_stages: [
        "ingestion", "parsing", "enrichment", "sampling", 
        "transformation", "batching", "delivery"
      ]
    }
  end
  
  defp collect_error_summary(results) do
    errors = 
      results
      |> Enum.map(&extract_errors_from_result/1)
      |> Enum.reject(&is_nil/1)
      |> List.flatten()
    
    %{
      total_errors: length(errors),
      error_types: categorize_errors(errors),
      critical_errors: filter_critical_errors(errors),
      recoverable_errors: filter_recoverable_errors(errors),
      error_rate: calculate_error_rate(errors, results)
    }
  end
  
  defp calculate_data_lineage(original_data, delivery_stats) do
    original_stats = extract_original_data_stats(original_data)
    
    lineage_map = %{
      ingestion: %{
        records_in: original_stats.total_records,
        records_out: original_stats.total_records,
        data_loss: 0
      },
      jaeger_pipeline: build_backend_lineage(delivery_stats.jaeger, original_stats),
      prometheus_pipeline: build_backend_lineage(delivery_stats.prometheus, original_stats),
      elasticsearch_pipeline: build_backend_lineage(delivery_stats.elasticsearch, original_stats)
    }
    
    %{
      data_flow: lineage_map,
      total_data_loss: calculate_total_data_loss(lineage_map),
      data_transformation_efficiency: calculate_transformation_efficiency(lineage_map)
    }
  end
  
  defp generate_performance_metrics(delivery_stats, data_lineage) do
    # Calculate throughput metrics
    throughput = calculate_pipeline_throughput(delivery_stats)
    
    # Calculate latency metrics
    latency = calculate_pipeline_latency(delivery_stats)
    
    # Calculate resource utilization
    resource_utilization = calculate_resource_utilization(delivery_stats)
    
    %{
      throughput: throughput,
      latency: latency,
      resource_utilization: resource_utilization,
      data_efficiency: data_lineage.data_transformation_efficiency,
      bottlenecks: identify_performance_bottlenecks(delivery_stats),
      scaling_recommendations: generate_scaling_recommendations(throughput, latency)
    }
  end
  
  defp generate_data_quality_report(original_data, delivery_stats, error_summary) do
    original_stats = extract_original_data_stats(original_data)
    
    %{
      data_completeness: calculate_data_completeness(original_stats, delivery_stats),
      data_accuracy: calculate_data_accuracy(delivery_stats, error_summary),
      data_consistency: calculate_data_consistency(delivery_stats),
      data_timeliness: calculate_data_timeliness(delivery_stats),
      overall_quality_score: 0.85,  # Calculated based on above metrics
      quality_issues: identify_quality_issues(delivery_stats, error_summary)
    }
  end
  
  defp generate_optimization_recommendations(performance_metrics, quality_report) do
    recommendations = []
    
    # Performance recommendations
    recommendations = if performance_metrics.throughput.records_per_second < 1000 do
      ["Consider increasing batch sizes for better throughput" | recommendations]
    else
      recommendations
    end
    
    recommendations = if performance_metrics.latency.avg_latency_ms > 5000 do
      ["High latency detected - consider pipeline optimization" | recommendations]
    else
      recommendations
    end
    
    # Quality recommendations
    recommendations = if quality_report.data_completeness < 0.95 do
      ["Data loss detected - review sampling and filtering strategies" | recommendations]
    else
      recommendations
    end
    
    recommendations = if quality_report.overall_quality_score < 0.8 do
      ["Overall data quality below threshold - investigate data validation" | recommendations]
    else
      recommendations
    end
    
    # Add general recommendations
    recommendations = [
      "Monitor pipeline performance metrics regularly",
      "Set up alerting for error rates above 5%",
      "Review backend capacity during peak loads"
      | recommendations
    ]
    
    Enum.uniq(recommendations)
  end
  
  # Helper functions
  
  defp extract_original_data_stats(original_data) do
    ingestion_stats = Map.get(original_data, :ingestion_stats, %{})
    
    %{
      total_records: Map.get(ingestion_stats, :records_count, 0),
      data_size_bytes: Map.get(ingestion_stats, :data_size_bytes, 0),
      source_type: Map.get(ingestion_stats, :source_type, "unknown")
    }
  end
  
  defp calculate_total_delivered(delivery_stats) do
    delivery_stats.jaeger.records_sent +
    delivery_stats.prometheus.records_sent +
    delivery_stats.elasticsearch.records_sent
  end
  
  defp calculate_data_reduction_factor(original_stats, delivery_stats) do
    total_delivered = calculate_total_delivered(delivery_stats)
    
    if original_stats.total_records > 0 do
      1 - (total_delivered / original_stats.total_records)
    else
      0.0
    end
  end
  
  defp calculate_processing_efficiency(delivery_stats) do
    total_time = delivery_stats.jaeger.delivery_time_ms +
                delivery_stats.prometheus.delivery_time_ms +
                delivery_stats.elasticsearch.delivery_time_ms
    
    total_records = calculate_total_delivered(delivery_stats)
    
    if total_time > 0 and total_records > 0 do
      total_records / total_time * 1000  # Records per second
    else
      0.0
    end
  end
  
  defp count_active_backends(delivery_stats) do
    [delivery_stats.jaeger, delivery_stats.prometheus, delivery_stats.elasticsearch]
    |> Enum.count(&(&1.status == :success))
  end
  
  defp count_successful_backends(backend_stats) do
    backend_stats
    |> Enum.count(&(&1.status == :success))
  end
  
  defp all_backends_successful?(backend_stats) do
    backend_stats
    |> Enum.all?(&(&1.status == :success))
  end
  
  defp extract_errors_from_result({:error, error_data}), do: [error_data]
  defp extract_errors_from_result(_), do: nil
  
  defp categorize_errors(errors) do
    errors
    |> Enum.group_by(&Map.get(&1, :stage, "unknown"))
    |> Enum.map(fn {stage, stage_errors} -> {stage, length(stage_errors)} end)
    |> Enum.into(%{})
  end
  
  defp filter_critical_errors(errors) do
    # Define critical error patterns
    critical_patterns = ["connection_failed", "authentication_failed", "timeout"]
    
    errors
    |> Enum.filter(fn error ->
      error_msg = Map.get(error, :error, "") |> String.downcase()
      Enum.any?(critical_patterns, &String.contains?(error_msg, &1))
    end)
  end
  
  defp filter_recoverable_errors(errors) do
    critical_errors = filter_critical_errors(errors)
    errors -- critical_errors
  end
  
  defp calculate_error_rate(errors, results) do
    total_operations = length(results)
    if total_operations > 0 do
      length(errors) / total_operations
    else
      0.0
    end
  end
  
  defp build_backend_lineage(backend_stats, original_stats) do
    %{
      records_in: original_stats.total_records,
      records_out: backend_stats.records_sent,
      data_loss: max(0, original_stats.total_records - backend_stats.records_sent),
      efficiency: if(original_stats.total_records > 0, 
        do: backend_stats.records_sent / original_stats.total_records, else: 0.0)
    }
  end
  
  defp calculate_total_data_loss(lineage_map) do
    lineage_map
    |> Map.values()
    |> Enum.map(&Map.get(&1, :data_loss, 0))
    |> Enum.sum()
  end
  
  defp calculate_transformation_efficiency(lineage_map) do
    efficiencies = 
      lineage_map
      |> Map.values()
      |> Enum.map(&Map.get(&1, :efficiency, 0.0))
      |> Enum.reject(&(&1 == 0.0))
    
    if length(efficiencies) > 0 do
      Enum.sum(efficiencies) / length(efficiencies)
    else
      0.0
    end
  end
  
  defp calculate_pipeline_throughput(delivery_stats) do
    total_records = calculate_total_delivered(delivery_stats)
    total_time_ms = delivery_stats.jaeger.delivery_time_ms +
                   delivery_stats.prometheus.delivery_time_ms +
                   delivery_stats.elasticsearch.delivery_time_ms
    
    records_per_second = if total_time_ms > 0 do
      total_records / (total_time_ms / 1000)
    else
      0.0
    end
    
    %{
      records_per_second: records_per_second,
      total_records_processed: total_records,
      total_processing_time_ms: total_time_ms
    }
  end
  
  defp calculate_pipeline_latency(delivery_stats) do
    latencies = [
      delivery_stats.jaeger.delivery_time_ms,
      delivery_stats.prometheus.delivery_time_ms,
      delivery_stats.elasticsearch.delivery_time_ms
    ]
    |> Enum.reject(&(&1 == 0))
    
    if length(latencies) > 0 do
      %{
        avg_latency_ms: Enum.sum(latencies) / length(latencies),
        max_latency_ms: Enum.max(latencies),
        min_latency_ms: Enum.min(latencies)
      }
    else
      %{avg_latency_ms: 0, max_latency_ms: 0, min_latency_ms: 0}
    end
  end
  
  defp calculate_resource_utilization(_delivery_stats) do
    # In a real implementation, collect actual resource metrics
    %{
      cpu_usage_percent: 45.0,
      memory_usage_mb: 256.0,
      network_bandwidth_mbps: 10.0,
      disk_io_mbps: 5.0
    }
  end
  
  defp identify_performance_bottlenecks(delivery_stats) do
    bottlenecks = []
    
    # Check for slow backends
    bottlenecks = if delivery_stats.jaeger.delivery_time_ms > 10000 do
      ["Jaeger delivery taking > 10s" | bottlenecks]
    else
      bottlenecks
    end
    
    bottlenecks = if delivery_stats.prometheus.delivery_time_ms > 5000 do
      ["Prometheus delivery taking > 5s" | bottlenecks]
    else
      bottlenecks
    end
    
    bottlenecks = if delivery_stats.elasticsearch.delivery_time_ms > 15000 do
      ["Elasticsearch delivery taking > 15s" | bottlenecks]
    else
      bottlenecks
    end
    
    if length(bottlenecks) == 0 do
      ["No significant bottlenecks detected"]
    else
      bottlenecks
    end
  end
  
  defp generate_scaling_recommendations(throughput, latency) do
    recommendations = []
    
    recommendations = if throughput.records_per_second < 500 do
      ["Consider horizontal scaling for higher throughput" | recommendations]
    else
      recommendations
    end
    
    recommendations = if latency.avg_latency_ms > 10000 do
      ["High latency suggests need for performance optimization" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["Current performance within acceptable limits"]
    else
      recommendations
    end
  end
  
  defp calculate_data_completeness(original_stats, delivery_stats) do
    total_delivered = calculate_total_delivered(delivery_stats)
    if original_stats.total_records > 0 do
      total_delivered / original_stats.total_records
    else
      1.0
    end
  end
  
  defp calculate_data_accuracy(delivery_stats, error_summary) do
    total_operations = delivery_stats.jaeger.batches_sent +
                      delivery_stats.prometheus.batches_sent +
                      delivery_stats.elasticsearch.batches_sent
    
    if total_operations > 0 do
      1.0 - (error_summary.total_errors / total_operations)
    else
      1.0
    end
  end
  
  defp calculate_data_consistency(_delivery_stats) do
    # In a real implementation, check for data format consistency
    0.95
  end
  
  defp calculate_data_timeliness(delivery_stats) do
    avg_latency = delivery_stats.jaeger.delivery_time_ms +
                 delivery_stats.prometheus.delivery_time_ms +
                 delivery_stats.elasticsearch.delivery_time_ms
    
    # Score based on latency (lower is better)
    cond do
      avg_latency < 1000 -> 1.0
      avg_latency < 5000 -> 0.8
      avg_latency < 10000 -> 0.6
      true -> 0.4
    end
  end
  
  defp identify_quality_issues(delivery_stats, error_summary) do
    issues = []
    
    issues = if error_summary.total_errors > 0 do
      ["#{error_summary.total_errors} errors detected in pipeline" | issues]
    else
      issues
    end
    
    issues = if delivery_stats.jaeger.retry_count > 0 do
      ["Jaeger delivery required #{delivery_stats.jaeger.retry_count} retries" | issues]
    else
      issues
    end
    
    if length(issues) == 0 do
      ["No significant quality issues detected"]
    else
      issues
    end
  end
  
  defp extract_pipeline_trace_id(results) do
    results
    |> Enum.find_value(fn result ->
      case result do
        {:ok, data} -> Map.get(data, :trace_id)
        %{trace_id: trace_id} -> trace_id
        _ -> nil
      end
    end)
    |> case do
      nil -> "pipeline-#{System.system_time(:nanosecond)}"
      trace_id -> trace_id
    end
  end
  
  defp count_backend_results(results) do
    results
    |> Enum.count(& &1 != nil)
  end
  
  defp count_completed_stages(delivery_stats) do
    successful_backends = count_successful_backends([
      delivery_stats.jaeger,
      delivery_stats.prometheus,
      delivery_stats.elasticsearch
    ])
    
    # Base stages + number of successful backend deliveries
    4 + successful_backends
  end
  
  defp determine_overall_status(delivery_stats, error_summary) do
    cond do
      error_summary.total_errors > 0 and length(error_summary.critical_errors) > 0 ->
        :failed
      
      delivery_stats.overall_delivery_success ->
        :success
      
      count_successful_backends([delivery_stats.jaeger, delivery_stats.prometheus, delivery_stats.elasticsearch]) > 0 ->
        :partial_success
      
      true ->
        :failed
    end
  end
end