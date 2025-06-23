defmodule BeamopsWeb.MetricsController do
  use BeamopsWeb, :controller

  def metrics(conn, _params) do
    # Basic Prometheus-style metrics
    metrics = """
    # HELP beamops_uptime_seconds Total uptime in seconds
    # TYPE beamops_uptime_seconds counter
    beamops_uptime_seconds #{:erlang.statistics(:wall_clock) |> elem(0) |> div(1000)}
    
    # HELP beamops_memory_usage_bytes Memory usage in bytes
    # TYPE beamops_memory_usage_bytes gauge
    beamops_memory_usage_bytes #{:erlang.memory(:total)}
    
    # HELP beamops_process_count Number of Erlang processes
    # TYPE beamops_process_count gauge
    beamops_process_count #{:erlang.system_info(:process_count)}
    
    # HELP beamops_build_info Build information
    # TYPE beamops_build_info gauge
    beamops_build_info{version="3.0.0",service="beamops_v3"} 1
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end