defmodule SelfSustaining.AIDomain do
  @moduledoc """
  Ash domain for AI coordination and autonomous system management.

  Defines the domain model for the self-sustaining AI system, providing a unified
  interface for managing AI agents, coordination workflows, and system optimization.

  ## Domain Responsibilities

  - **Agent Management**: Define and coordinate autonomous AI agents
  - **Work Coordination**: Model work claiming, progress tracking, and completion
  - **Performance Monitoring**: Track system metrics and optimization opportunities
  - **Authorization**: Secure access control for AI operations

  ## Security Model

  Uses Ash's built-in authorization system with `authorize :by_default` to ensure
  all operations are properly authenticated and authorized. This prevents
  unauthorized access to AI coordination functionality.

  ## Resource Integration

  Resources are added as they are created to maintain clean domain organization:

      resources do
        resource SelfSustaining.Agent
        resource SelfSustaining.WorkItem
        resource SelfSustaining.PerformanceMetric
      end

  ## Usage

      alias SelfSustaining.AIDomain
      
      # Query agents through domain
      AIDomain.read!(SelfSustaining.Agent)
      
      # Create work items with authorization
      AIDomain.create!(SelfSustaining.WorkItem, params)
  """

  use Ash.Domain

  authorization do
    authorize(:by_default)
  end

  resources do
    # Add resources as they are created
  end
end
