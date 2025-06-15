defmodule AiSelfSustainingMinimal.Repo.Migrations.InitialAshSetup do
  @moduledoc """
  Initial database setup for Ash resources.
  Creates tables for agents, work items, and telemetry events.
  """
  
  use Ecto.Migration
  
  def up do
    # Enable required extensions
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\""
    
    # Create agents table
    create table(:agents, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :agent_id, :string, null: false
      add :status, :string, null: false, default: "active"
      add :capabilities, {:array, :string}, default: []
      add :last_heartbeat, :utc_datetime_usec
      add :metadata, :map, default: %{}
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create unique_index(:agents, [:agent_id])
    create index(:agents, [:status])
    create index(:agents, [:last_heartbeat])
    
    # Create work_items table
    create table(:work_items, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :work_item_id, :string, null: false
      add :work_type, :string, null: false
      add :description, :text
      add :priority, :string, null: false, default: "medium"
      add :status, :string, null: false, default: "pending"
      add :claimed_by, references(:agents, type: :uuid, on_delete: :nilify_all)
      add :claimed_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :payload, :map, default: %{}
      add :result, :map, default: %{}
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create unique_index(:work_items, [:work_item_id])
    create index(:work_items, [:status])
    create index(:work_items, [:work_type])
    create index(:work_items, [:priority])
    create index(:work_items, [:claimed_by])
    create index(:work_items, [:inserted_at])
    
    # Create telemetry_events table
    create table(:telemetry_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :event_name, {:array, :string}, null: false
      add :measurements, :map, default: %{}
      add :metadata, :map, default: %{}
      add :trace_id, :string
      add :span_id, :string
      add :source, :string
      add :processed_at, :utc_datetime_usec
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:telemetry_events, [:trace_id])
    create index(:telemetry_events, [:source])
    create index(:telemetry_events, [:processed_at])
    create index(:telemetry_events, [:event_name], using: :gin)
  end
  
  def down do
    drop table(:telemetry_events)
    drop table(:work_items)
    drop table(:agents)
    
    execute "DROP EXTENSION IF EXISTS \"citext\""
    execute "DROP EXTENSION IF EXISTS \"uuid-ossp\""
  end
end