defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.EnrichmentMergeStep do
  @moduledoc """
  Merges all enrichment data into a unified structure.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    service_data = Map.get(arguments, :service_data)
    resource_data = Map.get(arguments, :resource_data)
    environment_data = Map.get(arguments, :environment_data)
    config = Map.get(arguments, :config, %{})
    
    # Extract trace ID from any source
    trace_id = Map.get(service_data, :trace_id) || 
               Map.get(resource_data, :trace_id) || 
               Map.get(environment_data, :trace_id)
    
    # Merge all enrichments
    merged_enrichment = %{
      service: Map.get(service_data, :service_enrichment, %{}),
      resource: Map.get(resource_data, :resource_enrichment, %{}),
      environment: Map.get(environment_data, :environment_enrichment, %{})
    }
    
    # Get original data from any source
    original_data = Map.get(service_data, :original_data) ||
                   Map.get(resource_data, :original_data) ||
                   Map.get(environment_data, :original_data)
    
    result = %{
      enriched_data: merged_enrichment,
      original_data: original_data,
      trace_id: trace_id,
      timestamp: DateTime.utc_now()
    }
    
    {:ok, result}
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options), do: :ok
end