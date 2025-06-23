defmodule BeamopsWeb.HealthController do
  use BeamopsWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      service: "BEAMOPS v3",
      version: "3.0.0",
      timestamp: DateTime.utc_now()
    })
  end

  def health(conn, _params) do
    health_status = %{
      status: "healthy",
      service: "beamops_v3",
      checks: %{
        database: "unknown",
        redis: "unknown",
        coordination: "active"
      },
      metrics: %{
        uptime: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
        memory_usage: :erlang.memory(:total),
        process_count: :erlang.system_info(:process_count)
      },
      timestamp: DateTime.utc_now()
    }

    conn
    |> put_status(:ok)
    |> json(health_status)
  end
end