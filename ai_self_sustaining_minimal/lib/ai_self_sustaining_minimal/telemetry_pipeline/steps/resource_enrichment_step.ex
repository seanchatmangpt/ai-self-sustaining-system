defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.ResourceEnrichmentStep do
  @moduledoc """
  Enriches telemetry data with resource-level metadata.
  Adds infrastructure, hardware, and platform information.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    parsed_data = Map.get(arguments, :parsed_data)
    config = Map.get(arguments, :config, %{})
    trace_id = Map.get(parsed_data, :trace_id)
    
    # Simple resource enrichment
    resource_enrichment = %{
      infrastructure: %{
        cloud_provider: "aws",
        region: "us-west-2",
        availability_zone: "us-west-2a"
      },
      platform: %{
        os: "linux",
        arch: "x86_64",
        runtime: "beam"
      }
    }
    
    result = %{
      resource_enrichment: resource_enrichment,
      original_data: parsed_data,
      trace_id: trace_id,
      timestamp: DateTime.utc_now()
    }
    
    {:ok, result}
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options), do: :ok
end