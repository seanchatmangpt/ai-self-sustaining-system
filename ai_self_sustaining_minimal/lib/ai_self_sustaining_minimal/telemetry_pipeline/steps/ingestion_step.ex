defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.IngestionStep do
  @moduledoc """
  Ingests telemetry data from multiple sources with validation and normalization.
  Supports OTLP, HTTP, file, and streaming sources.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    raw_data = Map.get(arguments, :raw_data)
    config = Map.get(arguments, :config, %{})
    processing_context = Map.get(arguments, :context, %{})
    
    start_time = System.monotonic_time()
    
    # Emit telemetry for ingestion start
    :telemetry.execute([:otlp_pipeline, :ingestion, :start], %{
      data_size: estimate_data_size(raw_data),
      source_type: determine_source_type(raw_data),
      timestamp: System.system_time(:microsecond)
    }, %{context: processing_context})
    
    try do
      # Normalize input data format
      normalized_data = normalize_input_data(raw_data, config)
      
      # Validate data structure
      validated_data = validate_data_structure(normalized_data, config)
      
      # Extract metadata
      metadata = extract_ingestion_metadata(validated_data, processing_context)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        data: validated_data,
        metadata: metadata,
        ingestion_stats: %{
          records_count: count_records(validated_data),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          source_type: determine_source_type(raw_data),
          data_size_bytes: estimate_data_size(raw_data)
        },
        timestamp: DateTime.utc_now(),
        trace_id: Map.get(processing_context, :trace_id, generate_trace_id())
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :ingestion, :success], %{
        records_processed: result.ingestion_stats.records_count,
        processing_time_ms: result.ingestion_stats.processing_time_ms,
        data_size_bytes: result.ingestion_stats.data_size_bytes
      }, %{context: processing_context, result: result})
      
      Logger.info("Successfully ingested #{result.ingestion_stats.records_count} telemetry records")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          data_type: determine_source_type(raw_data)
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :ingestion, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: processing_context, error: error_details})
        
        Logger.error("Ingestion failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(result, _arguments, _context, _options) do
    # Clean up any temporary resources created during ingestion
    case result do
      {:ok, %{metadata: %{temp_files: temp_files}}} ->
        Enum.each(temp_files, fn file ->
          File.rm(file)
          Logger.debug("Cleaned up temporary file: #{file}")
        end)
      _ -> :ok
    end
    
    :ok
  end
  
  # Private helper functions
  
  defp normalize_input_data(data, config) when is_binary(data) do
    # Handle raw binary/string data (e.g., from HTTP)
    case Jason.decode(data) do
      {:ok, decoded} -> normalize_input_data(decoded, config)
      {:error, _} -> 
        # Try to parse as OTLP protobuf if JSON fails
        parse_otlp_protobuf(data, config)
    end
  end
  
  defp normalize_input_data(data, _config) when is_map(data) do
    # Already in map format
    data
  end
  
  defp normalize_input_data(data, _config) when is_list(data) do
    # Convert list to batch format
    %{
      "batch" => data,
      "resourceSpans" => data
    }
  end
  
  defp normalize_input_data(data, _config) do
    # Fallback: wrap in batch format
    %{
      "batch" => [data],
      "resourceSpans" => [data]
    }
  end
  
  defp validate_data_structure(data, config) do
    required_fields = Map.get(config, :required_fields, ["resourceSpans"])
    
    # Check for required OTLP fields
    case validate_otlp_structure(data, required_fields) do
      :ok -> data
      {:error, missing_fields} ->
        # Try to repair the structure
        repair_data_structure(data, missing_fields, config)
    end
  end
  
  defp validate_otlp_structure(data, required_fields) do
    missing_fields = 
      required_fields
      |> Enum.reject(&Map.has_key?(data, &1))
    
    if length(missing_fields) == 0 do
      :ok
    else
      {:error, missing_fields}
    end
  end
  
  defp repair_data_structure(data, missing_fields, _config) do
    # Add missing OTLP structure
    Enum.reduce(missing_fields, data, fn field, acc ->
      case field do
        "resourceSpans" ->
          Map.put(acc, "resourceSpans", [%{
            "resource" => %{},
            "scopeSpans" => []
          }])
        "resourceMetrics" ->
          Map.put(acc, "resourceMetrics", [%{
            "resource" => %{},
            "scopeMetrics" => []
          }])
        "resourceLogs" ->
          Map.put(acc, "resourceLogs", [%{
            "resource" => %{},
            "scopeLogs" => []
          }])
        _ ->
          Map.put(acc, field, [])
      end
    end)
  end
  
  defp extract_ingestion_metadata(data, context) do
    %{
      ingested_at: DateTime.utc_now(),
      source: Map.get(context, :source, "unknown"),
      data_format: detect_data_format(data),
      schema_version: extract_schema_version(data),
      temp_files: [],
      processing_node: Node.self()
    }
  end
  
  defp detect_data_format(data) do
    cond do
      Map.has_key?(data, "resourceSpans") -> "otlp_traces"
      Map.has_key?(data, "resourceMetrics") -> "otlp_metrics"
      Map.has_key?(data, "resourceLogs") -> "otlp_logs"
      Map.has_key?(data, "batch") -> "batch_format"
      true -> "unknown"
    end
  end
  
  defp extract_schema_version(data) do
    # Extract OTLP schema version if available
    data
    |> get_in(["resourceSpans", Access.at(0), "schemaUrl"])
    |> case do
      nil -> "1.0.0"
      url when is_binary(url) -> String.replace(url, ~r/.*\/v/, "")
      _ -> "1.0.0"
    end
  end
  
  defp count_records(data) do
    spans_count = 
      data
      |> Map.get("resourceSpans", [])
      |> Enum.map(&count_spans_in_resource/1)
      |> Enum.sum()
    
    metrics_count = 
      data
      |> Map.get("resourceMetrics", [])
      |> Enum.map(&count_metrics_in_resource/1)
      |> Enum.sum()
    
    logs_count = 
      data
      |> Map.get("resourceLogs", [])
      |> Enum.map(&count_logs_in_resource/1)
      |> Enum.sum()
    
    spans_count + metrics_count + logs_count
  end
  
  defp count_spans_in_resource(resource_span) do
    resource_span
    |> Map.get("scopeSpans", [])
    |> Enum.map(fn scope_span -> 
      scope_span
      |> Map.get("spans", [])
      |> length()
    end)
    |> Enum.sum()
  end
  
  defp count_metrics_in_resource(resource_metric) do
    resource_metric
    |> Map.get("scopeMetrics", [])
    |> Enum.map(fn scope_metric ->
      scope_metric
      |> Map.get("metrics", [])
      |> length()
    end)
    |> Enum.sum()
  end
  
  defp count_logs_in_resource(resource_log) do
    resource_log
    |> Map.get("scopeLogs", [])
    |> Enum.map(fn scope_log ->
      scope_log
      |> Map.get("logRecords", [])
      |> length()
    end)
    |> Enum.sum()
  end
  
  defp estimate_data_size(data) when is_binary(data), do: byte_size(data)
  defp estimate_data_size(data) when is_map(data) or is_list(data) do
    data
    |> Jason.encode!()
    |> byte_size()
  end
  defp estimate_data_size(_), do: 0
  
  defp determine_source_type(data) when is_binary(data) do
    cond do
      String.starts_with?(data, "POST") -> "http_request"
      String.contains?(data, "resourceSpans") -> "otlp_json"
      true -> "raw_binary"
    end
  end
  
  defp determine_source_type(data) when is_map(data) do
    cond do
      Map.has_key?(data, "resourceSpans") -> "otlp_traces"
      Map.has_key?(data, "resourceMetrics") -> "otlp_metrics"
      Map.has_key?(data, "resourceLogs") -> "otlp_logs"
      true -> "structured_data"
    end
  end
  
  defp determine_source_type(_), do: "unknown"
  
  defp parse_otlp_protobuf(_data, _config) do
    # TODO: Implement protobuf parsing for OTLP binary format
    # For now, return empty structure
    %{
      "resourceSpans" => [],
      "resourceMetrics" => [],
      "resourceLogs" => []
    }
  end
  
  defp generate_trace_id do
    "ingestion-#{System.system_time(:nanosecond)}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  end
end