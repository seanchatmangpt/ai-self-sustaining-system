defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.EnvironmentEnrichmentStep do
  @moduledoc """
  Enriches telemetry data with environment-level metadata.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    parsed_data = Map.get(arguments, :parsed_data)
    config = Map.get(arguments, :config, %{})
    trace_id = Map.get(parsed_data, :trace_id)
    
    # Simple environment enrichment
    environment_enrichment = %{
      deployment: %{
        environment: "production",
        version: "1.0.0",
        commit_sha: "abc123"
      }
    }
    
    result = %{
      environment_enrichment: environment_enrichment,
      original_data: parsed_data,
      trace_id: trace_id,
      timestamp: DateTime.utc_now()
    }
    
    {:ok, result}
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options), do: :ok
end