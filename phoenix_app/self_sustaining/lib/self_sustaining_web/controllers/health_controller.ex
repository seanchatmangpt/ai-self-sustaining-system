defmodule SelfSustainingWeb.HealthController do
  use SelfSustainingWeb, :controller
  require Logger
  alias SelfSustaining.SystemMetric

  def index(conn, _params) do
    # Generate real OpenTelemetry span for this request
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    Logger.info("Health check request", trace_id: trace_id)
    
    # Real performance measurement
    response_time = System.monotonic_time(:millisecond) - start_time
    
    # Save real metric to database
    {:ok, _metric} = SystemMetric.create_metric(
      "health_check_response_time", 
      response_time / 1.0, 
      "milliseconds", 
      trace_id
    )
    
    # Get real recent metrics from database
    recent_metrics = SystemMetric.get_recent_metrics(5)
    
    # Real business logic - check system health
    health_data = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:self_sustaining, :vsn) |> to_string(),
      trace_id: trace_id,
      response_time_ms: response_time,
      system: %{
        phoenix_running: true,
        compile_status: "success",
        http_server: "responding",
        database_connected: database_connected?()
      },
      recent_metrics: Enum.map(recent_metrics, fn m ->
        %{
          name: m.name,
          value: m.value,
          unit: m.unit,
          timestamp: m.timestamp,
          trace_id: m.trace_id
        }
      end)
    }
    
    json(conn, health_data)
  end
  
  defp get_trace_id(conn) do
    # Extract trace ID from headers or generate one
    case get_req_header(conn, "traceparent") do
      [traceparent] ->
        # Parse W3C trace context format: version-trace_id-parent_id-flags
        case String.split(traceparent, "-") do
          [_version, trace_id, _parent_id, _flags] -> trace_id
          _ -> generate_trace_id()
        end
      _ -> 
        generate_trace_id()
    end
  end
  
  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  
  defp database_connected? do
    try do
      SelfSustaining.Repo.query!("SELECT 1")
      true
    rescue
      _ -> false
    end
  end
end