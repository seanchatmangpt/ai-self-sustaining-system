defmodule AiSelfSustainingMinimal.Coordination.WorkItem do
  @moduledoc """
  Work item resource for managing tasks and work distribution in the AI system.
  """
  
  use Ash.Resource,
    domain: AiSelfSustainingMinimal.Coordination,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]
  
  postgres do
    table "work_items"
    repo AiSelfSustainingMinimal.Repo
  end
  
  attributes do
    uuid_primary_key :id
    
    attribute :work_item_id, :string do
      allow_nil? false
      public? true
    end
    
    attribute :work_type, :string do
      allow_nil? false
      public? true
    end
    
    attribute :description, :string do
      public? true
    end
    
    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
      public? true
    end
    
    attribute :status, :atom do
      constraints one_of: [:pending, :claimed, :in_progress, :completed, :failed]
      default :pending
      public? true
    end
    
    attribute :claimed_by, :uuid do
      public? true
    end
    
    attribute :claimed_at, :utc_datetime_usec do
      public? true
    end
    
    attribute :completed_at, :utc_datetime_usec do
      public? true
    end
    
    attribute :payload, :map do
      default %{}
      public? true
    end
    
    attribute :result, :map do
      default %{}
      public? true
    end
    
    timestamps()
  end
  
  # Phoenix PubSub configuration for real-time updates
  pub_sub do
    module AiSelfSustainingMinimalWeb.Endpoint
    prefix "work_item"
    
    publish_all :create, ["created"]
    publish_all :update, ["updated"]
  end
  
  relationships do
    belongs_to :agent, AiSelfSustainingMinimal.Coordination.Agent do
      source_attribute :claimed_by
      public? true
    end
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :submit_work do
      primary? true
      accept [:work_type, :description, :priority, :payload]
      
      change fn changeset, _context ->
        work_id = "work_#{System.system_time(:nanosecond)}"
        Ash.Changeset.change_attribute(changeset, :work_item_id, work_id)
      end
    end
    
    update :claim_work do
      accept [:claimed_by]
      
      validate attribute_equals(:status, :pending) do
        message "Work item must be pending to be claimed"
      end
      
      change set_attribute(:status, :claimed)
      change set_attribute(:claimed_at, &DateTime.utc_now/0)
    end
    
    update :start_work do
      accept []
      
      validate attribute_equals(:status, :claimed) do
        message "Work item must be claimed to start"
      end
      
      change set_attribute(:status, :in_progress)
    end
    
    update :complete_work do
      accept [:result]
      
      validate attribute_equals(:status, :in_progress) do
        message "Work item must be in progress to complete"
      end
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    update :fail_work do
      accept [:result]
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
    
    read :pending do
      filter expr(status == :pending)
    end
    
    read :by_status do
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
    end
    
    read :by_work_type do
      argument :work_type, :string, allow_nil?: false
      filter expr(work_type == ^arg(:work_type))
    end
    
    read :by_agent do
      argument :agent_id, :uuid, allow_nil?: false
      filter expr(claimed_by == ^arg(:agent_id))
    end
    
    read :by_priority do
      argument :priority, :atom, allow_nil?: false
      filter expr(priority == ^arg(:priority))
    end
  end
  
  # Policies can be configured here
  # For simplicity, using default authorization
  
  identities do
    identity :unique_work_item_id, [:work_item_id]
  end
end