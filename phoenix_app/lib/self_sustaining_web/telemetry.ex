defmodule SelfSustainingWeb.Telemetry do
  @moduledoc """
  Phoenix telemetry supervisor for the SelfSustaining application.

  This module provides telemetry event handling and metric collection
  for Phoenix web requests and OpenTelemetry integration.
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("self_sustaining.repo.query.total_time",
        unit: {:native, :millisecond}
      ),
      summary("self_sustaining.repo.query.decode_time",
        unit: {:native, :millisecond}
      ),
      summary("self_sustaining.repo.query.query_time",
        unit: {:native, :millisecond}
      ),
      summary("self_sustaining.repo.query.queue_time",
        unit: {:native, :millisecond}
      ),
      summary("self_sustaining.repo.query.idle_time",
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # OpenTelemetry Integration
      counter("self_sustaining.telemetry.spans.created"),
      summary("self_sustaining.telemetry.trace.duration",
        unit: {:native, :millisecond}
      ),

      # Reactor Workflow Metrics
      counter("self_sustaining.reactor.workflows.executed"),
      summary("self_sustaining.reactor.workflow.duration",
        unit: {:native, :millisecond}
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {__MODULE__, :dispatch_vm_stats, []},
      {__MODULE__, :dispatch_database_stats, []}
    ]
  end

  def dispatch_vm_stats do
    # Convert keyword list to map for telemetry
    memory_data = :erlang.memory() |> Enum.into(%{})
    :telemetry.execute([:vm, :memory], memory_data, %{})

    # Get actual run queue lengths
    run_queue_lengths = :erlang.statistics(:total_run_queue_lengths)
    :telemetry.execute([:vm, :total_run_queue_lengths], %{lengths: run_queue_lengths}, %{})
  end

  def dispatch_database_stats do
    # Simple database stats without broken __pool__ call
    pool_size = Application.get_env(:self_sustaining, SelfSustaining.Repo)[:pool_size] || 10
    :telemetry.execute([:self_sustaining, :repo, :pool], %{size: pool_size}, %{})
  end
end
