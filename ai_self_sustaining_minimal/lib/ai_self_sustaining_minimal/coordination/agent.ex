defmodule AiSelfSustainingMinimal.Coordination.Agent do
  @moduledoc """
  Agent resource for managing AI agents in the self-sustaining system.
  """
  
  use Ash.Resource,
    domain: AiSelfSustainingMinimal.Coordination,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "agents"
    repo AiSelfSustainingMinimal.Repo
  end
  
  attributes do
    uuid_primary_key :id
    
    attribute :agent_id, :string do
      allow_nil? false
      public? true
    end
    
    attribute :status, :atom do
      constraints one_of: [:active, :idle, :error, :offline]
      default :active
      public? true
    end
    
    attribute :capabilities, {:array, :string} do
      default []
      public? true
    end
    
    attribute :last_heartbeat, :utc_datetime_usec do
      public? true
    end
    
    attribute :metadata, :map do
      default %{}
      public? true
    end
    
    timestamps()
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :register do
      primary? true
      accept [:agent_id, :capabilities, :metadata]
      
      change set_attribute(:status, :active)
      change set_attribute(:last_heartbeat, &DateTime.utc_now/0)
      
      # Custom validation for unique agent_id will be handled by identity constraint
    end
    
    update :heartbeat do
      accept []
      change set_attribute(:last_heartbeat, &DateTime.utc_now/0)
      change set_attribute(:status, :active)
    end
    
    update :update_status do
      accept [:status, :metadata]
    end
    
    read :active do
      filter expr(status == :active)
    end
    
    read :by_agent_id do
      argument :agent_id, :string, allow_nil?: false
      filter expr(agent_id == ^arg(:agent_id))
    end
  end
  
  # Policies can be configured here
  # For simplicity, using default authorization
  
  identities do
    identity :unique_agent_id, [:agent_id]
  end
end