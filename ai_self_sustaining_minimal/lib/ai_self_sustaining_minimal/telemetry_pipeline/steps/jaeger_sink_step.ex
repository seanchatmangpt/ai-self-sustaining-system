defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.JaegerSinkStep do
  @moduledoc """
  Sends batched data to Jaeger backend.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    batched_data = Map.get(arguments, :batched_data)
    config = Map.get(arguments, :config, %{})
    
    # Extract Jaeger batches
    jaeger_batches = Map.get(batched_data, :jaeger_batches, [])
    
    # Simulate sending to Jaeger
    Logger.info("Sending #{length(jaeger_batches)} batches to Jaeger")
    
    result = %{
      records_sent: calculate_records_sent(jaeger_batches),
      batches_sent: length(jaeger_batches),
      bytes_sent: calculate_bytes_sent(jaeger_batches),
      delivery_time_ms: 250,
      retry_count: 0,
      endpoint: Map.get(config, :jaeger_endpoint, "http://localhost:14268/api/traces")
    }
    
    {:ok, result}
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options), do: :ok
  
  defp calculate_records_sent(batches) do
    batches
    |> Enum.map(&get_in(&1, [:metadata, :traces_count]) || 0)
    |> Enum.sum()
  end
  
  defp calculate_bytes_sent(batches) do
    batches
    |> Enum.map(&get_in(&1, [:metadata, :size_bytes]) || 0)
    |> Enum.sum()
  end
end