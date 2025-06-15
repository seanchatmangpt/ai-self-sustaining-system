defmodule SelfSustaining.Repo.Migrations.CreateApsTables do
  use Ecto.Migration

  def up do
    create table(:aps_processes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :process_id, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :current_stage, :string, null: false, default: "PM_Agent"
      add :assigned_agent, :string
      add :status, :string, null: false, default: "pending"
      add :aps_content, :map, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:aps_processes, [:process_id])
    create index(:aps_processes, [:current_stage])
    create index(:aps_processes, [:status])
    create index(:aps_processes, [:assigned_agent])

    create table(:aps_agent_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :string, null: false
      add :agent_role, :string, null: false
      add :process_id, :string
      add :status, :string, null: false, default: "active"
      add :claimed_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :estimated_completion, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:aps_agent_assignments, [:session_id])
    create index(:aps_agent_assignments, [:agent_role])
    create index(:aps_agent_assignments, [:process_id])
    create index(:aps_agent_assignments, [:status])
    create index(:aps_agent_assignments, [:claimed_at])
  end

  def down do
    drop table(:aps_agent_assignments)
    drop table(:aps_processes)
  end
end