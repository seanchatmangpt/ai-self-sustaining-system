defmodule SelfSustaining.SystemMetric do
  use Ecto.Schema
  import Ecto.Changeset

  schema "system_metrics" do
    field :name, :string
    field :value, :float
    field :unit, :string
    field :timestamp, :naive_datetime
    field :trace_id, :string

    timestamps(type: :naive_datetime_usec)
  end

  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:name, :value, :unit, :timestamp, :trace_id])
    |> validate_required([:name, :value, :unit, :timestamp])
    |> validate_number(:value, greater_than_or_equal_to: 0)
  end

  def create_metric(name, value, unit, trace_id \\ nil) do
    %__MODULE__{}
    |> changeset(%{
      name: name,
      value: value,
      unit: unit,
      timestamp: NaiveDateTime.utc_now(),
      trace_id: trace_id
    })
    |> SelfSustaining.Repo.insert()
  end

  def get_recent_metrics(limit \\ 10) do
    import Ecto.Query
    
    from(m in __MODULE__, 
      order_by: [desc: m.timestamp],
      limit: ^limit)
    |> SelfSustaining.Repo.all()
  end
end