defmodule SelfSustaining.Workflows do
  @moduledoc """
  Ash domain for Reactor workflow management and orchestration.

  Provides a domain-driven approach to managing autonomous workflows, combining
  Ash's powerful resource modeling with Reactor's workflow orchestration capabilities.

  ## Workflow Domain Responsibilities

  - **Workflow Definition**: Model workflow templates and configurations
  - **Execution Management**: Track workflow instances and state transitions  
  - **Agent Coordination**: Integrate workflows with agent coordination system
  - **Performance Tracking**: Monitor workflow performance and optimization
  - **Error Handling**: Manage workflow failures and compensation logic

  ## Integration with Reactor

  This domain bridges Ash resources with Reactor workflows, enabling:

  - Persistent workflow state management through Ash resources
  - Database-backed workflow execution tracking
  - Authorization and security for workflow operations
  - Query interface for workflow analytics and reporting

  ## Workflow Resource Types

  Planned workflow resources include:

      resources do
        resource SelfSustaining.WorkflowTemplate  # Reusable workflow definitions
        resource SelfSustaining.WorkflowInstance  # Execution instances
        resource SelfSustaining.WorkflowStep      # Individual step tracking
        resource SelfSustaining.CompensationLog   # Error recovery tracking
      end

  ## Security and Authorization

  All workflow operations require proper authorization to ensure system security:

  - Workflow execution permissions based on agent roles
  - Resource-level access control for sensitive operations
  - Audit logging for compliance and debugging

  ## Usage Examples

      alias SelfSustaining.Workflows
      
      # Query active workflow instances
      Workflows.read!(SelfSustaining.WorkflowInstance, 
        actor: current_agent,
        filter: [status: :running]
      )
      
      # Create new workflow from template
      Workflows.create!(SelfSustaining.WorkflowInstance, %{
        template_id: template_id,
        agent_id: agent_id,
        input_data: input_params
      }, actor: current_agent)
  """

  use Ash.Domain

  authorization do
    authorize(:by_default)
  end

  resources do
    # Add workflow resources as they are created
  end
end
