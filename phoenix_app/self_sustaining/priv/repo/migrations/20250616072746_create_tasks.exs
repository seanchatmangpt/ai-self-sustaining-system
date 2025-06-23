defmodule SelfSustaining.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending", null: false
      add :priority, :string, default: "medium", null: false
      add :assigned_to, :string
      add :due_date, :naive_datetime
      add :completed_at, :naive_datetime
      add :trace_id, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:tasks, [:status])
    create index(:tasks, [:priority])
    create index(:tasks, [:assigned_to])
    create index(:tasks, [:trace_id])
    create index(:tasks, [:due_date])
  end
end