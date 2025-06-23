defmodule AiSelfSustainingMinimal.TelemetryPipeline.PipelineManager do
  @moduledoc """
  Manages and orchestrates the OpenTelemetry data processing pipeline.
  Provides high-level interface for pipeline execution, monitoring, and management.
  """
  
  use GenServer
  require Logger
  
  alias AiSelfSustainingMinimal.TelemetryPipeline.OtlpDataPipelineReactor
  
  @default_config %{
    # Pipeline configuration
    max_concurrent_pipelines: 5,
    pipeline_timeout_ms: 60_000,
    
    # Sampling configuration
    trace_sampling_strategy: :probabilistic,
    trace_sampling_rate: 0.1,
    metric_sampling_strategy: :time_based,
    log_sampling_strategy: :severity_based,
    
    # Backend configuration
    jaeger_endpoint: "http://localhost:14268/api/traces",
    prometheus_endpoint: "http://localhost:9090/api/v1/write",
    elasticsearch_endpoint: "http://localhost:9200/_bulk",
    
    # Batch configuration
    jaeger_batch_size: 100,
    prometheus_batch_size: 1000,
    elasticsearch_batch_size: 500,
    
    # Retry configuration
    jaeger_retry_attempts: 3,
    prometheus_retry_attempts: 2,
    elasticsearch_retry_attempts: 3
  }
  
  defstruct [
    :config,
    :active_pipelines,
    :pipeline_stats,
    :telemetry_handler_id
  ]
  
  # Public API
  
  def start_link(opts \\ []) do
    config = Keyword.get(opts, :config, @default_config)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end
  
  def process_telemetry_data(data, context \\ %{}, opts \\ []) do
    GenServer.call(__MODULE__, {:process_telemetry, data, context, opts}, 30_000)
  end
  
  def get_pipeline_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def get_pipeline_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end
  
  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end
  
  def list_active_pipelines do
    GenServer.call(__MODULE__, :list_active_pipelines)
  end
  
  def cancel_pipeline(pipeline_id) do
    GenServer.call(__MODULE__, {:cancel_pipeline, pipeline_id})
  end
  
  # GenServer callbacks
  
  @impl GenServer
  def init(config) do
    # Setup telemetry event handlers
    handler_id = setup_telemetry_handlers()
    
    state = %__MODULE__{
      config: Map.merge(@default_config, config),
      active_pipelines: %{},
      pipeline_stats: initialize_stats(),
      telemetry_handler_id: handler_id
    }
    
    Logger.info("OpenTelemetry Pipeline Manager started with config: #{inspect(Map.take(config, [:max_concurrent_pipelines, :pipeline_timeout_ms]))}")
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call({:process_telemetry, data, context, opts}, from, state) do
    case can_start_new_pipeline?(state) do
      true ->
        pipeline_id = generate_pipeline_id()
        
        # Start pipeline execution asynchronously
        task = Task.async(fn ->
          execute_pipeline(pipeline_id, data, context, opts, state.config)
        end)
        
        # Update state with new active pipeline
        updated_pipelines = Map.put(state.active_pipelines, pipeline_id, %{
          task: task,
          started_at: DateTime.utc_now(),
          from: from,
          data_size: estimate_data_size(data),
          context: context
        })
        
        new_state = %{state | active_pipelines: updated_pipelines}
        
        # Reply will be sent when pipeline completes
        {:noreply, new_state}
      
      false ->
        # Return error if too many concurrent pipelines
        {:reply, {:error, :pipeline_capacity_exceeded}, state}
    end
  end
  
  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      active_pipelines: map_size(state.active_pipelines),
      max_concurrent_pipelines: state.config.max_concurrent_pipelines,
      total_pipelines_executed: state.pipeline_stats.total_executions,
      success_rate: calculate_success_rate(state.pipeline_stats),
      avg_execution_time_ms: state.pipeline_stats.avg_execution_time_ms
    }
    
    {:reply, status, state}
  end
  
  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    {:reply, state.pipeline_stats, state}
  end
  
  @impl GenServer
  def handle_call({:update_config, new_config}, _from, state) do
    updated_config = Map.merge(state.config, new_config)
    new_state = %{state | config: updated_config}
    
    Logger.info("Pipeline configuration updated: #{inspect(new_config)}")
    
    {:reply, :ok, new_state}
  end
  
  @impl GenServer
  def handle_call(:list_active_pipelines, _from, state) do
    pipeline_list = 
      state.active_pipelines
      |> Enum.map(fn {pipeline_id, pipeline_info} ->
        %{
          pipeline_id: pipeline_id,
          started_at: pipeline_info.started_at,
          data_size: pipeline_info.data_size,
          running_time_ms: DateTime.diff(DateTime.utc_now(), pipeline_info.started_at, :millisecond)
        }
      end)
    
    {:reply, pipeline_list, state}
  end
  
  @impl GenServer
  def handle_call({:cancel_pipeline, pipeline_id}, _from, state) do
    case Map.get(state.active_pipelines, pipeline_id) do
      nil ->
        {:reply, {:error, :pipeline_not_found}, state}
      
      pipeline_info ->
        # Cancel the task
        Task.shutdown(pipeline_info.task, :brutal_kill)
        
        # Remove from active pipelines
        updated_pipelines = Map.delete(state.active_pipelines, pipeline_id)
        new_state = %{state | active_pipelines: updated_pipelines}
        
        # Reply to original caller with cancellation
        GenServer.reply(pipeline_info.from, {:error, :pipeline_cancelled})
        
        Logger.info("Pipeline cancelled: #{pipeline_id}")
        
        {:reply, :ok, new_state}
    end
  end
  
  @impl GenServer
  def handle_info({task_ref, result}, state) when is_reference(task_ref) do
    # Find completed pipeline
    case find_pipeline_by_task_ref(state.active_pipelines, task_ref) do
      {pipeline_id, pipeline_info} ->
        # Reply to original caller
        GenServer.reply(pipeline_info.from, result)
        
        # Update statistics
        execution_time = DateTime.diff(DateTime.utc_now(), pipeline_info.started_at, :millisecond)
        updated_stats = update_pipeline_stats(state.pipeline_stats, result, execution_time)
        
        # Remove from active pipelines
        updated_pipelines = Map.delete(state.active_pipelines, pipeline_id)
        
        new_state = %{state | 
          active_pipelines: updated_pipelines,
          pipeline_stats: updated_stats
        }
        
        Logger.debug("Pipeline completed: #{pipeline_id} (#{execution_time}ms)")
        
        {:noreply, new_state}
      
      nil ->
        # Task not found, ignore
        {:noreply, state}
    end
  end
  
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task crashed, clean up if needed
    {:noreply, state}
  end
  
  @impl GenServer
  def terminate(_reason, state) do
    # Clean up telemetry handlers
    if state.telemetry_handler_id do
      :telemetry.detach(state.telemetry_handler_id)
    end
    
    # Cancel all active pipelines
    Enum.each(state.active_pipelines, fn {_id, pipeline_info} ->
      Task.shutdown(pipeline_info.task, :brutal_kill)
    end)
    
    :ok
  end
  
  # Private functions
  
  defp execute_pipeline(pipeline_id, data, context, opts, config) do
    Logger.info("Starting pipeline execution: #{pipeline_id}")
    
    # Add pipeline ID to context
    enriched_context = Map.merge(context, %{
      pipeline_id: pipeline_id,
      started_at: DateTime.utc_now()
    })
    
    # Prepare pipeline inputs
    pipeline_inputs = %{
      telemetry_data: data,
      pipeline_config: config,
      processing_context: enriched_context
    }
    
    # Execute the pipeline
    case Reactor.run(OtlpDataPipelineReactor, pipeline_inputs, opts) do
      {:ok, result} ->
        Logger.info("Pipeline execution successful: #{pipeline_id}")
        {:ok, enrich_pipeline_result(result, pipeline_id, enriched_context)}
      
      {:error, reason} ->
        Logger.error("Pipeline execution failed: #{pipeline_id} - #{inspect(reason)}")
        {:error, %{
          pipeline_id: pipeline_id,
          error: reason,
          context: enriched_context
        }}
    end
  end
  
  defp can_start_new_pipeline?(state) do
    map_size(state.active_pipelines) < state.config.max_concurrent_pipelines
  end
  
  defp generate_pipeline_id do
    "pipeline-#{System.unique_integer()}-#{System.system_time(:nanosecond)}"
  end
  
  defp estimate_data_size(data) when is_binary(data), do: byte_size(data)
  defp estimate_data_size(data) when is_map(data) or is_list(data) do
    data
    |> Jason.encode!()
    |> byte_size()
  rescue
    _ -> 0
  end
  defp estimate_data_size(_), do: 0
  
  defp find_pipeline_by_task_ref(active_pipelines, task_ref) do
    Enum.find(active_pipelines, fn {_id, pipeline_info} ->
      pipeline_info.task.ref == task_ref
    end)
  end
  
  defp initialize_stats do
    %{
      total_executions: 0,
      successful_executions: 0,
      failed_executions: 0,
      total_execution_time_ms: 0,
      avg_execution_time_ms: 0,
      total_data_processed_bytes: 0,
      peak_concurrent_pipelines: 0,
      last_execution_at: nil
    }
  end
  
  defp update_pipeline_stats(stats, result, execution_time_ms) do
    new_total = stats.total_executions + 1
    new_total_time = stats.total_execution_time_ms + execution_time_ms
    
    case result do
      {:ok, pipeline_result} ->
        data_size = Map.get(pipeline_result, :data_size_processed, 0)
        
        %{stats |
          total_executions: new_total,
          successful_executions: stats.successful_executions + 1,
          total_execution_time_ms: new_total_time,
          avg_execution_time_ms: div(new_total_time, new_total),
          total_data_processed_bytes: stats.total_data_processed_bytes + data_size,
          last_execution_at: DateTime.utc_now()
        }
      
      {:error, _} ->
        %{stats |
          total_executions: new_total,
          failed_executions: stats.failed_executions + 1,
          total_execution_time_ms: new_total_time,
          avg_execution_time_ms: div(new_total_time, new_total),
          last_execution_at: DateTime.utc_now()
        }
    end
  end
  
  defp calculate_success_rate(stats) do
    if stats.total_executions > 0 do
      stats.successful_executions / stats.total_executions * 100
    else
      0.0
    end
  end
  
  defp enrich_pipeline_result(result, pipeline_id, context) do
    Map.merge(result, %{
      pipeline_id: pipeline_id,
      execution_context: context,
      data_size_processed: estimate_processed_data_size(result)
    })
  end
  
  defp estimate_processed_data_size(result) do
    # Estimate data size from pipeline summary
    get_in(result, [:pipeline_summary, :total_records_processed]) || 0
  end
  
  defp setup_telemetry_handlers do
    handler_id = "otlp_pipeline_manager_#{System.unique_integer()}"
    
    # Attach telemetry handler for pipeline events
    :telemetry.attach_many(
      handler_id,
      [
        [:otlp_pipeline, :ingestion, :start],
        [:otlp_pipeline, :ingestion, :success],
        [:otlp_pipeline, :ingestion, :error],
        [:otlp_pipeline, :parsing, :start],
        [:otlp_pipeline, :parsing, :success],
        [:otlp_pipeline, :parsing, :error],
        [:otlp_pipeline, :service_enrichment, :start],
        [:otlp_pipeline, :service_enrichment, :success],
        [:otlp_pipeline, :service_enrichment, :error],
        [:otlp_pipeline, :sampling, :start],
        [:otlp_pipeline, :sampling, :success],
        [:otlp_pipeline, :sampling, :error],
        [:otlp_pipeline, :jaeger_transform, :start],
        [:otlp_pipeline, :jaeger_transform, :success],
        [:otlp_pipeline, :jaeger_transform, :error],
        [:otlp_pipeline, :batching, :start],
        [:otlp_pipeline, :batching, :success],
        [:otlp_pipeline, :batching, :error],
        [:otlp_pipeline, :result_collection, :start],
        [:otlp_pipeline, :result_collection, :success],
        [:otlp_pipeline, :result_collection, :error]
      ],
      &handle_telemetry_event/4,
      %{}
    )
    
    handler_id
  end
  
  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Log important pipeline events
    case event_name do
      [:otlp_pipeline, stage, :error] ->
        Logger.error("Pipeline stage error: #{stage} - #{inspect(Map.get(metadata, :error))}")
      
      [:otlp_pipeline, :result_collection, :success] ->
        Logger.info("Pipeline completed successfully: #{inspect(Map.get(metadata, :trace_id))}")
      
      _ ->
        # Debug logging for other events
        Logger.debug("Pipeline telemetry: #{inspect(event_name)} - #{inspect(measurements)}")
    end
  end
  
  # Public utility functions
  
  def create_default_config(overrides \\ %{}) do
    Map.merge(@default_config, overrides)
  end
  
  def validate_config(config) do
    required_keys = [:max_concurrent_pipelines, :pipeline_timeout_ms]
    
    missing_keys = required_keys -- Map.keys(config)
    
    case missing_keys do
      [] -> {:ok, config}
      keys -> {:error, {:missing_config_keys, keys}}
    end
  end
end