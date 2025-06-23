defmodule SelfSustainingWeb.HealthController do
  @moduledoc """
  Health check controller for monitoring and service discovery.
  """

  use SelfSustainingWeb, :controller

  def index(conn, _params) do
    # Get trace ID from conn assigns (set by router pipeline)
    trace_id = conn.assigns[:trace_id] || "unknown"
    
    # Basic health check response with distributed tracing
    health_status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:self_sustaining, :vsn) |> to_string(),
      trace_id: trace_id,
      services: %{
        database: check_database(),
        oban: check_oban(),
        telemetry: "ok"
      }
    }

    # Emit telemetry event for health check with trace context
    :telemetry.execute(
      [:self_sustaining, :health_check],
      %{response_time: 0, timestamp: System.system_time(:millisecond)},
      %{trace_id: trace_id, status: "ok"}
    )

    json(conn, health_status)
  end

  defp check_database do
    try do
      SelfSustaining.Repo.query!("SELECT 1")
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp check_oban do
    try do
      Oban.check_queue(:default)
      "ok"
    rescue
      _ -> "error"
    end
  end
end
