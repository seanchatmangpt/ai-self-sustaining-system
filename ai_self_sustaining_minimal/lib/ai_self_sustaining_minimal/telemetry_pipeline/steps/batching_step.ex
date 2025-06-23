defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.BatchingStep do
  @moduledoc """
  Batches transformed telemetry data for efficient backend delivery.
  Organizes data by backend type and creates optimally sized batches.
  """
  
  use Reactor.Step
  require Logger
  
  @default_batch_size 1000
  @default_max_wait_time_ms 5000
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    jaeger_data = Map.get(arguments, :jaeger_data)
    prometheus_data = Map.get(arguments, :prometheus_data)
    elasticsearch_data = Map.get(arguments, :elasticsearch_data)
    config = Map.get(arguments, :config, %{})
    
    start_time = System.monotonic_time()
    
    # Extract common trace ID
    trace_id = extract_trace_id([jaeger_data, prometheus_data, elasticsearch_data])
    
    # Emit batching start telemetry
    :telemetry.execute([:otlp_pipeline, :batching, :start], %{
      jaeger_items: count_items(jaeger_data),
      prometheus_items: count_items(prometheus_data),
      elasticsearch_items: count_items(elasticsearch_data),
      timestamp: System.system_time(:microsecond)
    }, %{context: context, trace_id: trace_id})
    
    try do
      # Create batches for each backend
      jaeger_batches = create_jaeger_batches(jaeger_data, config)
      prometheus_batches = create_prometheus_batches(prometheus_data, config)
      elasticsearch_batches = create_elasticsearch_batches(elasticsearch_data, config)
      
      # Calculate batching statistics
      batching_stats = calculate_batching_stats(jaeger_batches, prometheus_batches, elasticsearch_batches)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        jaeger_batches: jaeger_batches,
        prometheus_batches: prometheus_batches,
        elasticsearch_batches: elasticsearch_batches,
        batching_stats: Map.put(batching_stats, :processing_time_ms, 
          System.convert_time_unit(processing_time, :native, :millisecond)),
        batch_metadata: %{
          created_at: DateTime.utc_now(),
          batch_strategy: Map.get(config, :batch_strategy, "size_based"),
          max_batch_size: Map.get(config, :max_batch_size, @default_batch_size)
        },
        trace_id: trace_id,
        timestamp: DateTime.utc_now()
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :batching, :success], %{
        total_batches: batching_stats.total_batches,
        jaeger_batches: batching_stats.jaeger_batches,
        prometheus_batches: batching_stats.prometheus_batches,
        elasticsearch_batches: batching_stats.elasticsearch_batches,
        processing_time_ms: batching_stats.processing_time_ms,
        compression_ratio: batching_stats.compression_ratio
      }, %{context: context, trace_id: trace_id})
      
      Logger.debug("Batching completed: #{batching_stats.total_batches} total batches created")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          stage: "batching"
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :batching, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: context, error: error_details, trace_id: trace_id})
        
        Logger.error("Batching failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options) do
    # No specific cleanup needed for batching
    :ok
  end
  
  # Private batching functions
  
  defp create_jaeger_batches(jaeger_data, config) do
    if jaeger_data && Map.get(jaeger_data, :jaeger_data) do
      batch_size = Map.get(config, :jaeger_batch_size, @default_batch_size)
      traces = get_in(jaeger_data, [:jaeger_data, :data]) || []
      
      traces
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.map(fn {batch_traces, index} ->
        create_jaeger_batch(batch_traces, index, config)
      end)
    else
      []
    end
  end
  
  defp create_prometheus_batches(prometheus_data, config) do
    if prometheus_data && Map.get(prometheus_data, :prometheus_data) do
      batch_size = Map.get(config, :prometheus_batch_size, @default_batch_size)
      metrics = get_in(prometheus_data, [:prometheus_data, :metrics]) || []
      
      metrics
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.map(fn {batch_metrics, index} ->
        create_prometheus_batch(batch_metrics, index, config)
      end)
    else
      []
    end
  end
  
  defp create_elasticsearch_batches(elasticsearch_data, config) do
    if elasticsearch_data && Map.get(elasticsearch_data, :elasticsearch_data) do
      batch_size = Map.get(config, :elasticsearch_batch_size, @default_batch_size)
      documents = get_in(elasticsearch_data, [:elasticsearch_data, :documents]) || []
      
      documents
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.map(fn {batch_docs, index} ->
        create_elasticsearch_batch(batch_docs, index, config)
      end)
    else
      []
    end
  end
  
  defp create_jaeger_batch(traces, batch_index, config) do
    compression = Map.get(config, :jaeger_compression, :gzip)
    
    batch_data = %{
      spans: extract_all_spans(traces),
      processes: extract_all_processes(traces)
    }
    
    # Apply compression if configured
    compressed_data = case compression do
      :gzip -> apply_gzip_compression(batch_data)
      :none -> batch_data
      _ -> batch_data
    end
    
    %{
      batch_id: "jaeger-#{batch_index}-#{System.unique_integer()}",
      backend: "jaeger",
      data: compressed_data,
      metadata: %{
        traces_count: length(traces),
        spans_count: count_spans_in_traces(traces),
        size_bytes: estimate_batch_size(compressed_data),
        compression: compression,
        created_at: DateTime.utc_now()
      },
      delivery_config: %{
        endpoint: Map.get(config, :jaeger_endpoint, "http://localhost:14268/api/traces"),
        headers: build_jaeger_headers(config),
        timeout_ms: Map.get(config, :jaeger_timeout_ms, 10_000),
        retry_attempts: Map.get(config, :jaeger_retry_attempts, 3)
      }
    }
  end
  
  defp create_prometheus_batch(metrics, batch_index, config) do
    batch_data = %{
      metrics: metrics,
      timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    }
    
    %{
      batch_id: "prometheus-#{batch_index}-#{System.unique_integer()}",
      backend: "prometheus",
      data: batch_data,
      metadata: %{
        metrics_count: length(metrics),
        size_bytes: estimate_batch_size(batch_data),
        created_at: DateTime.utc_now()
      },
      delivery_config: %{
        endpoint: Map.get(config, :prometheus_endpoint, "http://localhost:9090/api/v1/write"),
        headers: build_prometheus_headers(config),
        timeout_ms: Map.get(config, :prometheus_timeout_ms, 5_000),
        retry_attempts: Map.get(config, :prometheus_retry_attempts, 2)
      }
    }
  end
  
  defp create_elasticsearch_batch(documents, batch_index, config) do
    # Create Elasticsearch bulk format
    bulk_data = create_elasticsearch_bulk_format(documents, config)
    
    %{
      batch_id: "elasticsearch-#{batch_index}-#{System.unique_integer()}",
      backend: "elasticsearch",
      data: bulk_data,
      metadata: %{
        documents_count: length(documents),
        size_bytes: estimate_batch_size(bulk_data),
        index_name: Map.get(config, :elasticsearch_index, "telemetry"),
        created_at: DateTime.utc_now()
      },
      delivery_config: %{
        endpoint: Map.get(config, :elasticsearch_endpoint, "http://localhost:9200/_bulk"),
        headers: build_elasticsearch_headers(config),
        timeout_ms: Map.get(config, :elasticsearch_timeout_ms, 15_000),
        retry_attempts: Map.get(config, :elasticsearch_retry_attempts, 3)
      }
    }
  end
  
  # Helper functions
  
  defp extract_all_spans(traces) do
    traces
    |> Enum.flat_map(&Map.get(&1, :spans, []))
  end
  
  defp extract_all_processes(traces) do
    traces
    |> Enum.map(&Map.get(&1, :processes, %{}))
    |> Enum.reduce(%{}, &Map.merge/2)
  end
  
  defp count_spans_in_traces(traces) do
    traces
    |> Enum.map(&length(Map.get(&1, :spans, [])))
    |> Enum.sum()
  end
  
  defp apply_gzip_compression(data) do
    # In a real implementation, apply gzip compression
    # For now, just return the data
    data
  end
  
  defp create_elasticsearch_bulk_format(documents, config) do
    index_name = Map.get(config, :elasticsearch_index, "telemetry")
    
    documents
    |> Enum.flat_map(fn doc ->
      # Create index action and document
      action = %{
        index: %{
          _index: index_name,
          _id: Map.get(doc, :id, generate_doc_id())
        }
      }
      [action, doc]
    end)
    |> Enum.map(&Jason.encode!/1)
    |> Enum.join("\n")
    |> Kernel.<>("\n")  # Add final newline for Elasticsearch bulk format
  end
  
  defp build_jaeger_headers(config) do
    base_headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "otlp-pipeline/1.0"}
    ]
    
    # Add authentication if configured
    case Map.get(config, :jaeger_auth) do
      %{type: :bearer, token: token} ->
        [{"Authorization", "Bearer #{token}"} | base_headers]
      %{type: :basic, username: user, password: pass} ->
        auth = Base.encode64("#{user}:#{pass}")
        [{"Authorization", "Basic #{auth}"} | base_headers]
      _ ->
        base_headers
    end
  end
  
  defp build_prometheus_headers(config) do
    base_headers = [
      {"Content-Type", "application/x-protobuf"},
      {"Content-Encoding", "snappy"},
      {"X-Prometheus-Remote-Write-Version", "0.1.0"}
    ]
    
    # Add authentication if configured
    case Map.get(config, :prometheus_auth) do
      %{type: :bearer, token: token} ->
        [{"Authorization", "Bearer #{token}"} | base_headers]
      _ ->
        base_headers
    end
  end
  
  defp build_elasticsearch_headers(config) do
    base_headers = [
      {"Content-Type", "application/x-ndjson"}
    ]
    
    # Add authentication if configured
    case Map.get(config, :elasticsearch_auth) do
      %{type: :basic, username: user, password: pass} ->
        auth = Base.encode64("#{user}:#{pass}")
        [{"Authorization", "Basic #{auth}"} | base_headers]
      %{type: :api_key, key: key} ->
        [{"Authorization", "ApiKey #{key}"} | base_headers]
      _ ->
        base_headers
    end
  end
  
  defp estimate_batch_size(data) do
    data
    |> Jason.encode!()
    |> byte_size()
  rescue
    _ -> 0
  end
  
  defp generate_doc_id do
    "doc-#{System.unique_integer()}-#{System.system_time(:nanosecond)}"
  end
  
  defp count_items(nil), do: 0
  defp count_items(%{jaeger_data: %{data: traces}}), do: length(traces)
  defp count_items(%{prometheus_data: %{metrics: metrics}}), do: length(metrics)
  defp count_items(%{elasticsearch_data: %{documents: docs}}), do: length(docs)
  defp count_items(_), do: 0
  
  defp extract_trace_id([first_data | _rest]) do
    Map.get(first_data || %{}, :trace_id, generate_batch_trace_id())
  end
  defp extract_trace_id(_), do: generate_batch_trace_id()
  
  defp generate_batch_trace_id do
    "batch-#{System.system_time(:nanosecond)}"
  end
  
  defp calculate_batching_stats(jaeger_batches, prometheus_batches, elasticsearch_batches) do
    total_jaeger = length(jaeger_batches)
    total_prometheus = length(prometheus_batches)
    total_elasticsearch = length(elasticsearch_batches)
    total_batches = total_jaeger + total_prometheus + total_elasticsearch
    
    # Calculate total data sizes
    jaeger_size = Enum.sum(Enum.map(jaeger_batches, &get_in(&1, [:metadata, :size_bytes]) || 0))
    prometheus_size = Enum.sum(Enum.map(prometheus_batches, &get_in(&1, [:metadata, :size_bytes]) || 0))
    elasticsearch_size = Enum.sum(Enum.map(elasticsearch_batches, &get_in(&1, [:metadata, :size_bytes]) || 0))
    total_size = jaeger_size + prometheus_size + elasticsearch_size
    
    # Calculate compression ratio (simplified)
    compression_ratio = if total_size > 0, do: 1.0, else: 0.0
    
    %{
      total_batches: total_batches,
      jaeger_batches: total_jaeger,
      prometheus_batches: total_prometheus,
      elasticsearch_batches: total_elasticsearch,
      total_size_bytes: total_size,
      jaeger_size_bytes: jaeger_size,
      prometheus_size_bytes: prometheus_size,
      elasticsearch_size_bytes: elasticsearch_size,
      compression_ratio: compression_ratio,
      avg_batch_size: if(total_batches > 0, do: div(total_size, total_batches), else: 0)
    }
  end
end