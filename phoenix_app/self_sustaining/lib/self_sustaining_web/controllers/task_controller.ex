defmodule SelfSustainingWeb.TaskController do
  use SelfSustainingWeb, :controller
  require Logger
  alias SelfSustaining.Task

  # GET /api/tasks - List all tasks with optional filtering
  def index(conn, params) do
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    Logger.info("Task list request", trace_id: trace_id, params: params)
    
    # Real filtering options from query params
    opts = [
      status: params["status"],
      priority: params["priority"],
      limit: parse_limit(params["limit"])
    ]
    
    # Real database query
    tasks = Task.list_tasks(opts)
    response_time = System.monotonic_time(:millisecond) - start_time
    
    # Record real performance metric
    SelfSustaining.SystemMetric.create_metric(
      "task_list_response_time",
      response_time / 1.0,
      "milliseconds",
      trace_id
    )
    
    # Convert opts to JSON-safe format
    filters = %{
      status: opts[:status],
      priority: opts[:priority],
      limit: opts[:limit]
    }
    
    json(conn, %{
      tasks: render_tasks(tasks),
      count: length(tasks),
      filters: filters,
      trace_id: trace_id,
      response_time_ms: response_time
    })
  end

  # POST /api/tasks - Create new task
  def create(conn, %{"task" => task_params}) do
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    Logger.info("Task creation request", trace_id: trace_id, title: task_params["title"])
    
    # Add trace ID to task for tracking
    task_params_with_trace = Map.put(task_params, "trace_id", trace_id)
    
    case Task.create_task(task_params_with_trace) do
      {:ok, task} ->
        response_time = System.monotonic_time(:millisecond) - start_time
        
        # Record successful creation metric
        SelfSustaining.SystemMetric.create_metric(
          "task_creation_success_time",
          response_time / 1.0,
          "milliseconds",
          trace_id
        )
        
        conn
        |> put_status(:created)
        |> json(%{
          task: render_task(task),
          trace_id: trace_id,
          response_time_ms: response_time,
          success: true
        })
        
      {:error, changeset} ->
        response_time = System.monotonic_time(:millisecond) - start_time
        
        # Record validation error metric
        SelfSustaining.SystemMetric.create_metric(
          "task_creation_error_time",
          response_time / 1.0,
          "milliseconds",
          trace_id
        )
        
        Logger.warning("Task creation failed", trace_id: trace_id, errors: changeset.errors)
        
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: format_changeset_errors(changeset),
          trace_id: trace_id,
          response_time_ms: response_time,
          success: false
        })
    end
  end

  # Handle POST without nested task params
  def create(conn, task_params) when is_map(task_params) do
    create(conn, %{"task" => task_params})
  end

  # GET /api/tasks/:id - Get specific task
  def show(conn, %{"id" => id}) do
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    case Task.get_task(id) do
      nil ->
        response_time = System.monotonic_time(:millisecond) - start_time
        
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Task not found",
          trace_id: trace_id,
          response_time_ms: response_time
        })
        
      task ->
        response_time = System.monotonic_time(:millisecond) - start_time
        
        # Record successful retrieval metric
        SelfSustaining.SystemMetric.create_metric(
          "task_retrieval_time",
          response_time / 1.0,
          "milliseconds",
          trace_id
        )
        
        json(conn, %{
          task: render_task(task),
          trace_id: trace_id,
          response_time_ms: response_time
        })
    end
  end

  # PUT /api/tasks/:id - Update task
  def update(conn, %{"id" => id, "task" => task_params}) do
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    case Task.get_task(id) do
      nil ->
        response_time = System.monotonic_time(:millisecond) - start_time
        
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Task not found",
          trace_id: trace_id,
          response_time_ms: response_time
        })
        
      task ->
        case Task.update_task(task, task_params) do
          {:ok, updated_task} ->
            response_time = System.monotonic_time(:millisecond) - start_time
            
            # Record successful update metric
            SelfSustaining.SystemMetric.create_metric(
              "task_update_success_time",
              response_time / 1.0,
              "milliseconds",
              trace_id
            )
            
            json(conn, %{
              task: render_task(updated_task),
              trace_id: trace_id,
              response_time_ms: response_time,
              success: true
            })
            
          {:error, changeset} ->
            response_time = System.monotonic_time(:millisecond) - start_time
            
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              errors: format_changeset_errors(changeset),
              trace_id: trace_id,
              response_time_ms: response_time,
              success: false
            })
        end
    end
  end

  # Handle PUT without nested task params
  def update(conn, %{"id" => id} = params) do
    task_params = Map.delete(params, "id")
    update(conn, %{"id" => id, "task" => task_params})
  end

  # DELETE /api/tasks/:id - Delete task
  def delete(conn, %{"id" => id}) do
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    case Task.get_task(id) do
      nil ->
        response_time = System.monotonic_time(:millisecond) - start_time
        
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Task not found",
          trace_id: trace_id,
          response_time_ms: response_time
        })
        
      task ->
        case Task.delete_task(task) do
          {:ok, _deleted_task} ->
            response_time = System.monotonic_time(:millisecond) - start_time
            
            # Record successful deletion metric
            SelfSustaining.SystemMetric.create_metric(
              "task_deletion_time",
              response_time / 1.0,
              "milliseconds",
              trace_id
            )
            
            conn
            |> put_status(:no_content)
            |> json(%{
              message: "Task deleted successfully",
              trace_id: trace_id,
              response_time_ms: response_time,
              success: true
            })
            
          {:error, changeset} ->
            response_time = System.monotonic_time(:millisecond) - start_time
            
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              errors: format_changeset_errors(changeset),
              trace_id: trace_id,
              response_time_ms: response_time,
              success: false
            })
        end
    end
  end

  # GET /api/tasks/stats - Get real task statistics
  def stats(conn, _params) do
    trace_id = get_trace_id(conn)
    start_time = System.monotonic_time(:millisecond)
    
    task_stats = Task.get_task_statistics()
    performance_metrics = Task.get_performance_metrics()
    response_time = System.monotonic_time(:millisecond) - start_time
    
    # Record stats query metric
    SelfSustaining.SystemMetric.create_metric(
      "task_stats_query_time",
      response_time / 1.0,
      "milliseconds",
      trace_id
    )
    
    json(conn, %{
      statistics: task_stats,
      performance: performance_metrics,
      trace_id: trace_id,
      response_time_ms: response_time,
      timestamp: DateTime.utc_now()
    })
  end

  # Private helper functions

  defp get_trace_id(conn) do
    case get_req_header(conn, "traceparent") do
      [traceparent] ->
        case String.split(traceparent, "-") do
          [_version, trace_id, _parent_id, _flags] -> trace_id
          _ -> generate_trace_id()
        end
      _ -> 
        generate_trace_id()
    end
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp parse_limit(nil), do: nil
  defp parse_limit(limit_str) when is_binary(limit_str) do
    case Integer.parse(limit_str) do
      {limit, ""} when limit > 0 and limit <= 100 -> limit
      _ -> nil
    end
  end
  defp parse_limit(_), do: nil

  defp render_tasks(tasks) do
    Enum.map(tasks, &render_task/1)
  end

  defp render_task(task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      assigned_to: task.assigned_to,
      due_date: task.due_date,
      completed_at: task.completed_at,
      trace_id: task.trace_id,
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end