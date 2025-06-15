defmodule SelfSustaining.TestReactors.SimpleValidationReactor do
  @moduledoc """
  Simple test reactor for validating Enhanced Reactor Runner functionality
  """
  use Reactor
  
  input :test_message
  
  step :process_message do
    argument :msg, input(:test_message)
    
    run fn args, context ->
      # Extract enhanced context provided by the Enhanced Reactor Runner
      agent_id = Map.get(context, :agent_id, "unknown")
      execution_id = Map.get(context, :execution_id, "unknown")
      
      result = %{
        message: "Enhanced Reactor Runner validation successful",
        input_received: args.msg,
        agent_id: agent_id,
        execution_id: execution_id,
        timestamp: System.system_time(:millisecond),
        enhanced_features: true
      }
      
      {:ok, result}
    end
  end
  
  return :process_message
end