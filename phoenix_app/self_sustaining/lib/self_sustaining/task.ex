defmodule SelfSustaining.Task do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :priority, :string, default: "medium"
    field :assigned_to, :string
    field :due_date, :naive_datetime
    field :completed_at, :naive_datetime
    field :trace_id, :string

    timestamps(type: :naive_datetime_usec)
  end

  @valid_statuses ["pending", "in_progress", "completed", "cancelled"]
  @valid_priorities ["low", "medium", "high", "critical"]

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :status, :priority, :assigned_to, :due_date, :completed_at, :trace_id])
    |> validate_required([:title])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:priority, @valid_priorities)
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:description, max: 5000)
    |> maybe_set_completed_at()
  end

  # Business logic: automatically set completed_at when status changes to completed
  defp maybe_set_completed_at(changeset) do
    case get_change(changeset, :status) do
      "completed" -> 
        put_change(changeset, :completed_at, NaiveDateTime.utc_now())
      _ -> 
        changeset
    end
  end

  # Real CRUD operations with database transactions

  def create_task(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> SelfSustaining.Repo.insert()
  end

  def get_task(id) do
    SelfSustaining.Repo.get(__MODULE__, id)
  end

  def get_task!(id) do
    SelfSustaining.Repo.get!(__MODULE__, id)
  end

  def list_tasks(opts \\ []) do
    query = from(t in __MODULE__, order_by: [desc: t.inserted_at])
    
    query
    |> maybe_filter_by_status(opts[:status])
    |> maybe_filter_by_priority(opts[:priority])
    |> maybe_limit(opts[:limit])
    |> SelfSustaining.Repo.all()
  end

  def update_task(task, attrs) do
    task
    |> changeset(attrs)
    |> SelfSustaining.Repo.update()
  end

  def delete_task(task) do
    SelfSustaining.Repo.delete(task)
  end

  # Real business metrics
  def get_task_statistics do
    query = from t in __MODULE__,
      group_by: t.status,
      select: {t.status, count(t.id)}
    
    stats = SelfSustaining.Repo.all(query) |> Enum.into(%{})
    
    %{
      total: Enum.sum(Map.values(stats)),
      by_status: stats,
      completion_rate: calculate_completion_rate(stats)
    }
  end

  def get_performance_metrics do
    thirty_days_ago = NaiveDateTime.utc_now() |> NaiveDateTime.add(-30, :day)
    
    # Get total created tasks
    total_query = from t in __MODULE__,
      where: t.inserted_at >= ^thirty_days_ago,
      select: count(t.id)
    
    created_count = SelfSustaining.Repo.one(total_query) || 0
    
    # Get completed tasks count  
    completed_query = from t in __MODULE__,
      where: t.inserted_at >= ^thirty_days_ago and t.status == "completed",
      select: count(t.id)
    
    completed_count = SelfSustaining.Repo.one(completed_query) || 0
    
    # Get average completion time for completed tasks
    avg_query = from t in __MODULE__,
      where: t.status == "completed" and not is_nil(t.completed_at) and t.inserted_at >= ^thirty_days_ago,
      select: avg(fragment("EXTRACT(epoch FROM (? - ?))", t.completed_at, t.inserted_at))
    
    avg_completion_time = SelfSustaining.Repo.one(avg_query)
    
    %{
      created_count: created_count,
      completed_count: completed_count,
      avg_completion_time: avg_completion_time
    }
  end

  # Query helpers
  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, [t], t.status == ^status)

  defp maybe_filter_by_priority(query, nil), do: query
  defp maybe_filter_by_priority(query, priority), do: where(query, [t], t.priority == ^priority)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp calculate_completion_rate(stats) do
    total = Enum.sum(Map.values(stats))
    completed = Map.get(stats, "completed", 0)
    
    if total > 0 do
      Float.round(completed / total * 100, 2)
    else
      0.0
    end
  end
end