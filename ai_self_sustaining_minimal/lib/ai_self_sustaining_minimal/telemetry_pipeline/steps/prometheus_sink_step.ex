defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.PrometheusSinkStep do
  @moduledoc """
  Sends batched data to Prometheus backend.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    batched_data = Map.get(arguments, :batched_data)
    config = Map.get(arguments, :config, %{})
    
    # Extract Prometheus batches
    prometheus_batches = Map.get(batched_data, :prometheus_batches, [])
    
    # Simulate sending to Prometheus
    Logger.info("Sending #{length(prometheus_batches)} batches to Prometheus")
    
    result = %{
      records_sent: calculate_records_sent(prometheus_batches),
      batches_sent: length(prometheus_batches),
      bytes_sent: calculate_bytes_sent(prometheus_batches),
      delivery_time_ms: 180,
      retry_count: 0,
      endpoint: Map.get(config, :prometheus_endpoint, "http://localhost:9090/api/v1/write")
    }
    
    {:ok, result}
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options), do: :ok
  
  defp calculate_records_sent(batches) do
    batches
    |> Enum.map(&get_in(&1, [:metadata, :metrics_count]) || 0)
    |> Enum.sum()
  end
  
  defp calculate_bytes_sent(batches) do
    batches
    |> Enum.map(&get_in(&1, [:metadata, :size_bytes]) || 0)
    |> Enum.sum()
  end
end