defmodule AiSelfSustainingMinimalWeb.OtlpController do
  @moduledoc """
  Phoenix controller for OpenTelemetry data processing pipeline.
  Preserves OTLP endpoints from the original system.
  """
  
  use AiSelfSustainingMinimalWeb, :controller
  require Logger
  
  # OTLP data ingestion endpoints
  def ingest_traces(conn, params) do
    ingest_otlp_data(conn, params, "traces")
  end
  
  def ingest_metrics(conn, params) do
    ingest_otlp_data(conn, params, "metrics")
  end
  
  def ingest_logs(conn, params) do
    ingest_otlp_data(conn, params, "logs")
  end
  
  def ingest_otlp(conn, params) do
    ingest_otlp_data(conn, params, "mixed")
  end
  
  # Pipeline status and management endpoints
  def pipeline_status(conn, _params) do
    status = %{
      status: "operational",
      active_pipelines: 0,
      max_concurrent_pipelines: 5,
      success_rate: 1.0,
      uptime: System.system_time(:second)
    }
    
    json(conn, %{
      status: "ok",
      data: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
  
  def pipeline_statistics(conn, _params) do
    stats = %{
      total_processed: 0,
      average_processing_time_ms: 0,
      error_rate: 0.0,
      throughput_per_second: 0
    }
    
    json(conn, %{
      status: "ok",
      data: stats,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
  
  def health_check(conn, _params) do
    json(conn, %{
      status: "ok",
      health: "healthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: "minimal-0.1.0"
    })
  end
  
  # Private implementation
  
  defp ingest_otlp_data(conn, params, data_type) do
    start_time = System.monotonic_time()
    
    # Generate trace ID
    trace_id = generate_trace_id()
    
    # Build processing context
    context = %{
      source: "http_api",
      data_type: data_type,
      trace_id: trace_id,
      client_ip: get_client_ip(conn),
      received_at: DateTime.utc_now()
    }
    
    # Store telemetry event using Ash
    case record_telemetry_event(data_type, params, context) do
      {:ok, _event} ->
        processing_time = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)
        
        Logger.info("OTLP data processed successfully: #{data_type}, #{processing_time}ms")
        
        json(conn, %{
          status: "ok",
          message: "Data processed successfully",
          data: %{
            trace_id: trace_id,
            processing_time_ms: processing_time,
            data_type: data_type
          }
        })
      
      {:error, reason} ->
        Logger.error("OTLP data processing failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          status: "error",
          error: "processing_failed",
          message: "Failed to process telemetry data"
        })
    end
  end
  
  defp record_telemetry_event(data_type, params, context) do
    event_name = ["otlp_api", data_type, "received"]
    
    measurements = %{
      data_size: estimate_data_size(params),
      timestamp: System.system_time(:nanosecond)
    }
    
    metadata = %{
      source: context.source,
      client_ip: context.client_ip,
      received_at: context.received_at
    }
    
    AiSelfSustainingMinimal.Telemetry.TelemetryEvent
    |> Ash.Changeset.for_create(:record_event, %{
      event_name: event_name,
      measurements: measurements,
      metadata: metadata,
      trace_id: context.trace_id,
      source: "otlp_api"
    })
    |> Ash.create()
  end
  
  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded] -> 
        forwarded |> String.split(",") |> List.first() |> String.trim()
      [] ->
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          _ -> "unknown"
        end
    end
  end
  
  defp estimate_data_size(data) when is_binary(data), do: byte_size(data)
  defp estimate_data_size(data) when is_map(data) or is_list(data) do
    data
    |> Jason.encode!()
    |> byte_size()
  rescue
    _ -> 0
  end
  defp estimate_data_size(_), do: 0
  
  defp generate_trace_id do
    "minimal-#{System.system_time(:nanosecond)}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end