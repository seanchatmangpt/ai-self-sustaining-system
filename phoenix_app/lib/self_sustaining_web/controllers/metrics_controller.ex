defmodule SelfSustainingWeb.MetricsController do
  @moduledoc """
  Metrics controller for Prometheus metrics export.
  """

  use SelfSustainingWeb, :controller

  def index(conn, _params) do
    # Return Prometheus metrics format
    metrics = generate_prometheus_metrics()

    conn
    |> put_resp_content_type("text/plain")
    |> text(metrics)
  end

  defp generate_prometheus_metrics do
    # Get REAL system metrics that can be verified
    memory = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    uptime = :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)

    """
    # HELP self_sustaining_memory_bytes Total memory usage in bytes
    # TYPE self_sustaining_memory_bytes gauge
    self_sustaining_memory_bytes{type="total"} #{memory[:total]}
    self_sustaining_memory_bytes{type="processes"} #{memory[:processes]}
    self_sustaining_memory_bytes{type="system"} #{memory[:system]}

    # HELP self_sustaining_process_count Current Erlang process count
    # TYPE self_sustaining_process_count gauge
    self_sustaining_process_count #{process_count}

    # HELP self_sustaining_uptime_seconds Server uptime in seconds
    # TYPE self_sustaining_uptime_seconds counter
    self_sustaining_uptime_seconds #{uptime}
    """
  end
end
