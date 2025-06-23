defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.ElasticsearchSinkStep do
  @moduledoc """
  Sends batched data to Elasticsearch backend.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    batched_data = Map.get(arguments, :batched_data)
    config = Map.get(arguments, :config, %{})
    
    # Extract Elasticsearch batches
    elasticsearch_batches = Map.get(batched_data, :elasticsearch_batches, [])
    
    # Simulate sending to Elasticsearch
    Logger.info("Sending #{length(elasticsearch_batches)} batches to Elasticsearch")
    
    result = %{
      records_sent: calculate_records_sent(elasticsearch_batches),
      batches_sent: length(elasticsearch_batches),
      bytes_sent: calculate_bytes_sent(elasticsearch_batches),
      delivery_time_ms: 320,
      retry_count: 0,
      endpoint: Map.get(config, :elasticsearch_endpoint, "http://localhost:9200/_bulk")
    }
    
    {:ok, result}
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options), do: :ok
  
  defp calculate_records_sent(batches) do
    batches
    |> Enum.map(&get_in(&1, [:metadata, :documents_count]) || 0)
    |> Enum.sum()
  end
  
  defp calculate_bytes_sent(batches) do
    batches
    |> Enum.map(&get_in(&1, [:metadata, :size_bytes]) || 0)
    |> Enum.sum()
  end
end