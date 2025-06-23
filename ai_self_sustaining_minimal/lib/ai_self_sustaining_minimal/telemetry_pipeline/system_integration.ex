defmodule AiSelfSustainingMinimal.TelemetryPipeline.SystemIntegration do
  @moduledoc """
  Integration module that connects the OTLP data processing pipeline 
  with the existing AI self-sustaining system components.
  
  Provides bidirectional integration:
  1. Feeds system telemetry into the OTLP pipeline
  2. Uses OTLP pipeline results to enhance system intelligence
  """
  
  use GenServer
  require Logger
  
  alias AiSelfSustainingMinimal.TelemetryPipeline.PipelineManager
  alias AiSelfSustainingMinimal.LivebookIntegration
  
  @telemetry_events [
    [:self_sustaining, :reactor, :execution, :start],
    [:self_sustaining, :reactor, :execution, :complete],
    [:self_sustaining, :reactor, :step, :start],
    [:self_sustaining, :reactor, :step, :complete],
    [:self_sustaining, :n8n, :workflow, :start],
    [:self_sustaining, :n8n, :workflow, :executed],
    [:self_sustaining, :coordination, :work, :claimed],
    [:self_sustaining, :coordination, :work, :completed],
    [:otlp_api, :request, :start],
    [:otlp_api, :request, :success],
    [:otlp_api, :request, :error]
  ]
  
  defstruct [
    :telemetry_handler_id,
    :telemetry_buffer,
    :buffer_size,
    :flush_interval_ms,
    :last_flush,
    :pipeline_config
  ]
  
  # Public API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def process_system_telemetry(telemetry_data, context \\ %{}) do
    GenServer.cast(__MODULE__, {:process_telemetry, telemetry_data, context})
  end
  
  def get_integration_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def flush_telemetry_buffer do
    GenServer.call(__MODULE__, :flush_buffer)
  end
  
  def update_integration_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end
  
  # GenServer callbacks
  
  @impl GenServer
  def init(opts) do
    buffer_size = Keyword.get(opts, :buffer_size, 100)
    flush_interval_ms = Keyword.get(opts, :flush_interval_ms, 30_000)
    pipeline_config = Application.get_env(:self_sustaining, :otlp_pipeline, %{})
    
    # Setup telemetry event handlers
    handler_id = setup_telemetry_handlers()
    
    # Schedule periodic buffer flush
    :timer.send_interval(flush_interval_ms, :flush_buffer)
    
    state = %__MODULE__{
      telemetry_handler_id: handler_id,
      telemetry_buffer: [],
      buffer_size: buffer_size,
      flush_interval_ms: flush_interval_ms,
      last_flush: DateTime.utc_now(),
      pipeline_config: pipeline_config
    }
    
    Logger.info("OTLP System Integration started with buffer size: #{buffer_size}")
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_cast({:process_telemetry, telemetry_data, context}, state) do
    # Add telemetry data to buffer
    buffer_entry = %{
      data: telemetry_data,
      context: context,
      timestamp: DateTime.utc_now()
    }
    
    updated_buffer = [buffer_entry | state.telemetry_buffer]
    
    # Check if buffer should be flushed
    new_state = if length(updated_buffer) >= state.buffer_size do
      flush_buffer_to_pipeline(updated_buffer, state)
      %{state | telemetry_buffer: [], last_flush: DateTime.utc_now()}
    else
      %{state | telemetry_buffer: updated_buffer}
    end
    
    {:noreply, new_state}
  end
  
  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      buffer_size: length(state.telemetry_buffer),
      max_buffer_size: state.buffer_size,
      last_flush: state.last_flush,
      flush_interval_ms: state.flush_interval_ms,
      integration_active: true
    }
    
    {:reply, status, state}
  end
  
  @impl GenServer
  def handle_call(:flush_buffer, _from, state) do
    if length(state.telemetry_buffer) > 0 do
      result = flush_buffer_to_pipeline(state.telemetry_buffer, state)
      new_state = %{state | telemetry_buffer: [], last_flush: DateTime.utc_now()}
      {:reply, {:ok, result}, new_state}
    else
      {:reply, {:ok, :empty_buffer}, state}
    end
  end
  
  @impl GenServer
  def handle_call({:update_config, config}, _from, state) do
    updated_config = Map.merge(state.pipeline_config, config)
    new_state = %{state | pipeline_config: updated_config}
    
    # Update pipeline manager config
    PipelineManager.update_config(config)
    
    {:reply, :ok, new_state}
  end
  
  @impl GenServer
  def handle_info(:flush_buffer, state) do
    new_state = if length(state.telemetry_buffer) > 0 do
      flush_buffer_to_pipeline(state.telemetry_buffer, state)
      %{state | telemetry_buffer: [], last_flush: DateTime.utc_now()}
    else
      state
    end
    
    {:noreply, new_state}
  end
  
  @impl GenServer
  def handle_info({telemetry_event, measurements, metadata}, state) do
    # Handle telemetry events from the system
    telemetry_data = convert_telemetry_to_otlp(telemetry_event, measurements, metadata)
    
    if telemetry_data do
      context = %{
        source: "system_telemetry",
        event: telemetry_event,
        integration: true
      }
      
      # Add to buffer
      buffer_entry = %{
        data: telemetry_data,
        context: context,
        timestamp: DateTime.utc_now()
      }
      
      updated_buffer = [buffer_entry | state.telemetry_buffer]
      
      new_state = if length(updated_buffer) >= state.buffer_size do
        flush_buffer_to_pipeline(updated_buffer, state)
        %{state | telemetry_buffer: [], last_flush: DateTime.utc_now()}
      else
        %{state | telemetry_buffer: updated_buffer}
      end
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  @impl GenServer
  def terminate(_reason, state) do
    # Clean up telemetry handlers
    if state.telemetry_handler_id do
      :telemetry.detach(state.telemetry_handler_id)
    end
    
    # Flush remaining buffer
    if length(state.telemetry_buffer) > 0 do
      flush_buffer_to_pipeline(state.telemetry_buffer, state)
    end
    
    :ok
  end
  
  # Private implementation
  
  defp setup_telemetry_handlers do
    handler_id = "otlp_system_integration_#{System.unique_integer()}"
    
    # Attach to system telemetry events
    :telemetry.attach_many(
      handler_id,
      @telemetry_events,
      &__MODULE__.handle_telemetry_event/4,
      %{}
    )
    
    handler_id
  end
  
  def handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Send telemetry event to this GenServer for processing
    send(__MODULE__, {event_name, measurements, metadata})
  end
  
  defp flush_buffer_to_pipeline(buffer, state) when length(buffer) > 0 do
    Logger.debug("Flushing #{length(buffer)} telemetry entries to OTLP pipeline")
    
    # Convert buffer to OTLP batch format
    otlp_batch = convert_buffer_to_otlp_batch(buffer)
    
    context = %{
      source: "system_integration",
      buffer_size: length(buffer),
      flush_time: DateTime.utc_now(),
      integration_enabled: get_in(state.pipeline_config, [:integration, :self_telemetry_enabled])
    }
    
    # Only process if integration is enabled
    if get_in(state.pipeline_config, [:integration, :self_telemetry_enabled]) do
      # Process through pipeline asynchronously
      Task.start(fn ->
        case PipelineManager.process_telemetry_data(otlp_batch, context) do
          {:ok, result} ->
            Logger.debug("System telemetry processed successfully: #{inspect(Map.keys(result))}")
            
            # Update Livebook integration with pipeline results
            if get_in(state.pipeline_config, [:integration, :livebook_integration_enabled]) do
              update_livebook_with_pipeline_results(result)
            end
            
          {:error, reason} ->
            Logger.warning("Failed to process system telemetry: #{inspect(reason)}")
        end
      end)
    end
    
    length(buffer)
  end
  defp flush_buffer_to_pipeline([], _state), do: 0
  
  defp convert_buffer_to_otlp_batch(buffer) do
    # Convert telemetry buffer entries to OTLP format
    resource_spans = buffer
    |> Enum.map(&convert_buffer_entry_to_span/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&extract_service_name/1)
    |> Enum.map(fn {service_name, spans} ->
      %{
        "resource" => %{
          "attributes" => [
            %{
              "key" => "service.name",
              "value" => %{"stringValue" => service_name}
            },
            %{
              "key" => "service.version",
              "value" => %{"stringValue" => Application.spec(:self_sustaining, :vsn) || "unknown"}
            },
            %{
              "key" => "telemetry.source",
              "value" => %{"stringValue" => "self_sustaining_system"}
            }
          ]
        },
        "scopeSpans" => [
          %{
            "scope" => %{
              "name" => "self_sustaining_telemetry",
              "version" => "1.0.0"
            },
            "spans" => spans
          }
        ]
      }
    end)
    
    %{
      "resourceSpans" => resource_spans
    }
  end
  
  defp convert_buffer_entry_to_span(%{data: data, context: context, timestamp: timestamp}) do
    # Convert individual telemetry entry to OTLP span format
    trace_id = Map.get(context, :trace_id) || Map.get(data, :trace_id) || generate_trace_id()
    span_id = generate_span_id()
    
    span_name = case Map.get(context, :event) do
      [:self_sustaining, :reactor, :execution, event_type] -> "reactor.execution.#{event_type}"
      [:self_sustaining, :reactor, :step, event_type] -> "reactor.step.#{event_type}"
      [:self_sustaining, :n8n, :workflow, event_type] -> "n8n.workflow.#{event_type}"
      [:self_sustaining, :coordination, :work, event_type] -> "coordination.work.#{event_type}"
      [:otlp_api, :request, event_type] -> "otlp.api.request.#{event_type}"
      _ -> "system.telemetry"
    end
    
    start_time = Map.get(data, :timestamp) || DateTime.to_unix(timestamp, :nanosecond)
    end_time = start_time + 1_000_000  # Add 1ms duration
    
    %{
      "traceId" => trace_id,
      "spanId" => span_id,
      "name" => span_name,
      "kind" => 1, # SPAN_KIND_INTERNAL
      "startTimeUnixNano" => to_string(start_time),
      "endTimeUnixNano" => to_string(end_time),
      "attributes" => convert_data_to_attributes(data, context),
      "status" => %{
        "code" => if(Map.get(context, :error), do: 2, else: 1) # ERROR or OK
      }
    }
  end
  
  defp convert_telemetry_to_otlp(event_name, measurements, metadata) do
    # Convert real-time telemetry events to OTLP format
    case event_name do
      [:self_sustaining, :reactor, :execution, phase] ->
        %{
          event_type: "reactor_execution",
          phase: phase,
          measurements: measurements,
          metadata: metadata,
          timestamp: System.system_time(:nanosecond)
        }
      
      [:self_sustaining, :n8n, :workflow, phase] ->
        %{
          event_type: "n8n_workflow",
          phase: phase,
          measurements: measurements,
          metadata: metadata,
          timestamp: System.system_time(:nanosecond)
        }
      
      [:otlp_api, :request, phase] ->
        %{
          event_type: "otlp_api",
          phase: phase,
          measurements: measurements,
          metadata: metadata,
          timestamp: System.system_time(:nanosecond)
        }
      
      _ ->
        # Generic telemetry event
        %{
          event_type: "system_telemetry",
          event_name: event_name,
          measurements: measurements,
          metadata: metadata,
          timestamp: System.system_time(:nanosecond)
        }
    end
  end
  
  defp convert_data_to_attributes(data, context) do
    attributes = []
    
    # Add data attributes
    attributes = Enum.reduce(data, attributes, fn {key, value}, acc ->
      if is_binary(value) or is_number(value) or is_boolean(value) do
        attr = %{
          "key" => to_string(key),
          "value" => %{"stringValue" => to_string(value)}
        }
        [attr | acc]
      else
        acc
      end
    end)
    
    # Add context attributes
    attributes = Enum.reduce(context, attributes, fn {key, value}, acc ->
      if is_binary(value) or is_number(value) or is_boolean(value) do
        attr = %{
          "key" => "context.#{key}",
          "value" => %{"stringValue" => to_string(value)}
        }
        [attr | acc]
      else
        acc
      end
    end)
    
    attributes
  end
  
  defp extract_service_name(span) do
    # Extract service name from span attributes
    span
    |> Map.get("attributes", [])
    |> Enum.find_value(fn attr ->
      if Map.get(attr, "key") == "service.name" do
        get_in(attr, ["value", "stringValue"])
      end
    end)
    |> case do
      nil -> "self_sustaining_system"
      service_name -> service_name
    end
  end
  
  defp update_livebook_with_pipeline_results(pipeline_result) do
    # Update Livebook integration with processed telemetry results
    try do
      LivebookIntegration.update_telemetry_stream(pipeline_result)
    rescue
      error ->
        Logger.warning("Failed to update Livebook with pipeline results: #{inspect(error)}")
    end
  end
  
  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  
  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end