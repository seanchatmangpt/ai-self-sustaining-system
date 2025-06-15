defmodule SelfSustaining.ReactorSteps.N8nWorkflowStep do
  @moduledoc """
  Mock N8n workflow step for integration testing.
  Provides the required interface without complex dependencies.
  """

  require Logger

  def run(arguments, context, _options) do
    workflow_id = Map.get(arguments, :workflow_id)
    workflow_data = Map.get(arguments, :workflow_data, %{})
    n8n_action = Map.get(arguments, :action, :trigger)
    trace_id = Map.get(context, :trace_id, "unknown")
    
    Logger.info("Mock N8n workflow step executing", 
      workflow_id: workflow_id,
      action: n8n_action,
      trace_id: trace_id
    )
    
    # Simulate processing time
    :timer.sleep(Enum.random(10..50))
    
    case n8n_action do
      :trigger ->
        result = %{
          action: :trigger,
          workflow_id: workflow_id,
          execution_id: "mock_exec_#{System.system_time(:nanosecond)}",
          triggered_at: DateTime.utc_now(),
          status: "running",
          input_data: workflow_data
        }
        {:ok, result}
        
      :compile ->
        result = %{
          action: :compile,
          workflow_id: workflow_id,
          n8n_json: %{
            name: workflow_id,
            nodes: Map.get(workflow_data, :nodes, []),
            connections: Map.get(workflow_data, :connections, [])
          },
          compiled_at: DateTime.utc_now(),
          node_count: length(Map.get(workflow_data, :nodes, [])),
          status: "compiled"
        }
        {:ok, result}
        
      :validate ->
        result = %{
          action: :validate,
          workflow_id: workflow_id,
          is_valid: true,
          validation_errors: [],
          validated_at: DateTime.utc_now()
        }
        {:ok, result}
        
      :export ->
        result = %{
          action: :export,
          workflow_id: workflow_id,
          n8n_workflow_id: "mock_n8n_#{workflow_id}",
          exported_at: DateTime.utc_now(),
          status: "exported"
        }
        {:ok, result}
        
      _ ->
        {:error, "Unknown n8n action: #{n8n_action}"}
    end
  end
end