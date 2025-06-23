defmodule SelfSustaining.Repo.Migrations.CreateSystemMetrics do
  use Ecto.Migration

  def change do
    create table(:system_metrics) do
      add :name, :string, null: false
      add :value, :float, null: false
      add :unit, :string, null: false
      add :timestamp, :naive_datetime, null: false
      add :trace_id, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:system_metrics, [:name])
    create index(:system_metrics, [:timestamp])
    create index(:system_metrics, [:trace_id])
  end
end
