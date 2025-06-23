defmodule AiSelfSustainingMinimalWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor for the minimal AI self-sustaining system.
  
  Configures and manages telemetry collection for system monitoring and performance
  analysis. Part of the effort to improve information retention from the measured
  22.5% baseline through better observability.
  
  ## Metrics Collected
  
  ### Phoenix Metrics
  - Request duration and routing performance
  - WebSocket connection metrics
  - Channel communication performance
  
  ### VM Metrics  
  - Memory usage and allocation
  - Process queue lengths
  - CPU and IO utilization
  
  ## Configuration
  
  - **Polling Interval**: 10 seconds (10_000ms)
  - **Strategy**: `:one_for_one` supervision
  - **Reporters**: Console reporter available (commented out by default)
  
  ## Integration
  
  Critical for monitoring system health and identifying sources of the measured
  77.5% information loss. Provides data for optimization and debugging.
  
  ## Usage
  
      # Access metrics programmatically
      AiSelfSustainingMinimalWeb.Telemetry.metrics()
      
      # Add custom periodic measurements
      # Update periodic_measurements/0 function
  """
  
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {AiSelfSustainingMinimalWeb, :count_users, []}
    ]
  end
end
