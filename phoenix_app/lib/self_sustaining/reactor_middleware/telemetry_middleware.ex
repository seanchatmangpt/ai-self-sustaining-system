defmodule SelfSustaining.ReactorMiddleware.TelemetryMiddleware do
  @moduledoc """
  Comprehensive telemetry and observability middleware for Reactor workflows.
  Integrates with OpenTelemetry for distributed tracing and metrics collection.
  
  Based on the REACTOR-USAGE-MAXIMIZATION.md specifications for Phase 2 implementation.
  """
  
  use Reactor.Middleware
  require OpenTelemetry.Tracer
  require Logger

  @impl true
  def init(context) do
    # Start OpenTelemetry span for entire reactor execution
    reactor_id = context[:__reactor__][:id] || "unknown_reactor"
    span_name = "reactor.#{reactor_id}.execution"
    
    OpenTelemetry.Tracer.with_span span_name do
      OpenTelemetry.Tracer.set_attributes([
        {"reactor.id", reactor_id},
        {"reactor.steps_count", get_steps_count(context)},
        {"agent.coordination.enabled", Map.has_key?(context, :work_claim)},
        {"system.version", Application.spec(:self_sustaining, :vsn) || "unknown"},
        {"execution.mode", "autonomous"},
        {"reactor.middleware.telemetry", true}
      ])
      
      # Emit reactor start telemetry
      :telemetry.execute([:self_sustaining, :reactor, :execution, :start], %{
        timestamp: System.system_time(:microsecond),
        reactor_id: reactor_id,
        steps_count: get_steps_count(context)
      }, context)
      
      enhanced_context = context
        |> Map.put(:execution_start_time, System.monotonic_time())
        |> Map.put(:telemetry_span_ctx, OpenTelemetry.Tracer.current_span_ctx())
        |> Map.put(__MODULE__, %{
          reactor_id: reactor_id,
          start_time: System.monotonic_time(),
          step_timings: %{},
          metadata: extract_telemetry_metadata(context)
        })
      
      Logger.info("Reactor telemetry initialized", 
        reactor_id: reactor_id,
        span_context: inspect(OpenTelemetry.Tracer.current_span_ctx()),
        coordination_enabled: Map.has_key?(context, :work_claim)
      )
      
      {:ok, enhanced_context}
    end
  end

  @impl true
  def complete(result, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    execution_duration = System.monotonic_time() - telemetry_state[:start_time]
    
    # Update final span attributes
    OpenTelemetry.Tracer.set_attributes([
      {"reactor.result.type", result_type_string(result)},
      {"reactor.duration_ms", System.convert_time_unit(execution_duration, :native, :millisecond)},
      {"reactor.success", match?({:ok, _}, result)},
      {"reactor.steps_executed", map_size(telemetry_state[:step_timings] || %{})}
    ])
    
    # Calculate performance metrics
    performance_metrics = calculate_performance_metrics(telemetry_state, execution_duration)
    
    # Emit reactor completion telemetry
    :telemetry.execute([:self_sustaining, :reactor, :execution, :complete], 
      Map.merge(%{
        reactor_id: telemetry_state[:reactor_id],
        duration: execution_duration,
        success: match?({:ok, _}, result)
      }, performance_metrics),
      Map.merge(context, %{result: result})
    )
    
    # Emit detailed performance telemetry
    :telemetry.execute([:self_sustaining, :reactor, :performance, :summary], 
      performance_metrics,
      Map.merge(context, telemetry_state[:metadata] || %{})
    )
    
    Logger.info("Reactor execution completed with comprehensive telemetry", 
      reactor_id: telemetry_state[:reactor_id] || "unknown",
      duration_ms: System.convert_time_unit(execution_duration, :native, :millisecond),
      success: match?({:ok, _}, result),
      performance_metrics: performance_metrics
    )
    
    {:ok, result}
  end

  @impl true
  def error(error_or_errors, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    
    # Record error in telemetry with detailed context
    error_details = extract_error_details(error_or_errors)
    
    OpenTelemetry.Tracer.set_status(:error, error_details.message)
    OpenTelemetry.Tracer.set_attributes([
      {"error.type", error_details.type},
      {"error.message", error_details.message},
      {"error.stacktrace", error_details.stacktrace}
    ])
    
    # Emit comprehensive error telemetry
    :telemetry.execute([:self_sustaining, :reactor, :error], %{
      error_type: error_details.type,
      error_count: error_details.count,
      reactor_id: telemetry_state[:reactor_id] || "unknown"
    }, Map.merge(context, %{
      error_details: error_details,
      telemetry_metadata: telemetry_state[:metadata] || %{}
    }))
    
    # Emit error pattern analysis telemetry
    :telemetry.execute([:self_sustaining, :reactor, :error, :pattern_analysis], %{
      error_signature: generate_error_signature(error_or_errors),
      occurrence_count: 1
    }, context)
    
    Logger.error("Reactor execution failed with comprehensive error telemetry", 
      reactor_id: telemetry_state[:reactor_id] || "unknown",
      error_details: error_details,
      context_keys: Map.keys(context)
    )
    
    :ok
  end

  @impl true
  def halt(context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    execution_duration = System.monotonic_time() - telemetry_state[:start_time]
    
    # Update span for halt
    OpenTelemetry.Tracer.set_attributes([
      {"reactor.halt", true},
      {"reactor.duration_ms", System.convert_time_unit(execution_duration, :native, :millisecond)}
    ])
    
    # Emit halt telemetry
    :telemetry.execute([:self_sustaining, :reactor, :execution, :halt], %{
      reactor_id: telemetry_state[:reactor_id],
      duration: execution_duration,
      reason: :halt
    }, context)
    
    Logger.info("Reactor execution halted with telemetry cleanup", 
      reactor_id: telemetry_state[:reactor_id] || "unknown",
      duration_ms: System.convert_time_unit(execution_duration, :native, :millisecond)
    )
    
    {:ok, context}
  end

  @impl true
  def event({:run_start, arguments}, step, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    step_span_name = "reactor.step.#{step.name}"
    
    OpenTelemetry.Tracer.with_span step_span_name do
      OpenTelemetry.Tracer.set_attributes([
        {"step.name", step.name},
        {"step.async", step.async? || false},
        {"step.retry_count", Map.get(context, :retry_count, 0)},
        {"step.argument_count", map_size(arguments)}
      ])
      
      # Record step start time
      step_start_time = System.monotonic_time()
      
      # Update telemetry state with step timing
      updated_step_timings = Map.put(telemetry_state[:step_timings] || %{}, step.name, %{
        start_time: step_start_time,
        arguments_size: calculate_arguments_size(arguments)
      })
      
      updated_telemetry_state = Map.put(telemetry_state, :step_timings, updated_step_timings)
      updated_context = Map.put(context, __MODULE__, updated_telemetry_state)
      
      # Emit step start telemetry
      :telemetry.execute([:self_sustaining, :reactor, :step, :start], %{
        step_name: step.name,
        timestamp: System.system_time(:microsecond),
        reactor_id: telemetry_state[:reactor_id],
        arguments_size: calculate_arguments_size(arguments)
      }, updated_context)
      
      # Store step start time in process dictionary for async steps
      Process.put({__MODULE__, :step_start_time, step.name}, step_start_time)
      
      Logger.debug("Step execution started with telemetry", 
        step_name: step.name,
        reactor_id: telemetry_state[:reactor_id],
        async: step.async?
      )
    end
    
    :ok
  end

  def event({:run_complete, result}, step, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    
    # Get step start time
    step_start_time = Process.delete({__MODULE__, :step_start_time, step.name}) ||
                     get_in(telemetry_state, [:step_timings, step.name, :start_time])
    
    if step_start_time do
      execution_time = System.monotonic_time() - step_start_time
      
      # Update OpenTelemetry span with result
      OpenTelemetry.Tracer.set_attributes([
        {"step.result.type", result_type_string(result)},
        {"step.duration_ms", System.convert_time_unit(execution_time, :native, :millisecond)},
        {"step.success", match?({:ok, _}, result)}
      ])
      
      # Calculate step performance metrics
      step_metrics = %{
        execution_time_ms: System.convert_time_unit(execution_time, :native, :millisecond),
        result_size: calculate_result_size(result),
        memory_usage: get_memory_usage(),
        cpu_time: get_cpu_time()
      }
      
      # Emit step completion telemetry
      :telemetry.execute([:self_sustaining, :reactor, :step, :complete], 
        Map.merge(%{
          step_name: step.name,
          reactor_id: telemetry_state[:reactor_id],
          duration: execution_time,
          success: match?({:ok, _}, result)
        }, step_metrics),
        context
      )
      
      # Emit step performance analysis
      :telemetry.execute([:self_sustaining, :reactor, :step, :performance], 
        step_metrics,
        Map.merge(context, %{step_name: step.name})
      )
      
      Logger.debug("Step execution completed with performance telemetry", 
        step_name: step.name,
        reactor_id: telemetry_state[:reactor_id],
        duration_ms: step_metrics.execution_time_ms,
        success: match?({:ok, _}, result)
      )
    end
    
    :ok
  end

  def event({:run_error, errors}, step, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    error_details = extract_error_details(errors)
    
    # Update span with error information
    OpenTelemetry.Tracer.set_attributes([
      {"step.error.type", error_details.type},
      {"step.error.message", error_details.message}
    ])
    
    # Emit step error telemetry
    :telemetry.execute([:self_sustaining, :reactor, :step, :error], %{
      step_name: step.name,
      reactor_id: telemetry_state[:reactor_id],
      error_type: error_details.type,
      error_count: error_details.count
    }, Map.merge(context, %{error_details: error_details}))
    
    Logger.warning("Step execution failed with error telemetry", 
      step_name: step.name,
      reactor_id: telemetry_state[:reactor_id],
      error_details: error_details
    )
    
    :ok
  end

  def event({:run_retry, _value}, step, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    
    # Emit retry telemetry
    :telemetry.execute([:self_sustaining, :reactor, :step, :retry], %{
      step_name: step.name,
      reactor_id: telemetry_state[:reactor_id],
      retry_count: Map.get(context, :retry_count, 0) + 1
    }, context)
    
    Logger.debug("Step execution retry with telemetry", 
      step_name: step.name,
      reactor_id: telemetry_state[:reactor_id]
    )
    
    :ok
  end

  def event({:compensate_start, reason}, step, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    
    # Start compensation span
    compensation_span_name = "reactor.step.#{step.name}.compensate"
    
    OpenTelemetry.Tracer.with_span compensation_span_name do
      OpenTelemetry.Tracer.set_attributes([
        {"compensation.step", step.name},
        {"compensation.reason", inspect(reason)}
      ])
      
      # Emit compensation start telemetry
      :telemetry.execute([:self_sustaining, :reactor, :step, :compensate, :start], %{
        step_name: step.name,
        reactor_id: telemetry_state[:reactor_id],
        reason: inspect(reason)
      }, context)
      
      # Store compensation start time
      Process.put({__MODULE__, :compensate_start_time, step.name}, System.monotonic_time())
      
      Logger.debug("Step compensation started with telemetry", 
        step_name: step.name,
        reactor_id: telemetry_state[:reactor_id],
        reason: inspect(reason)
      )
    end
    
    :ok
  end

  def event(:compensate_complete, step, context) do
    telemetry_state = Map.get(context, __MODULE__, %{})
    
    # Calculate compensation duration
    compensate_start_time = Process.delete({__MODULE__, :compensate_start_time, step.name})
    duration = if compensate_start_time, do: System.monotonic_time() - compensate_start_time, else: 0
    
    # Update compensation span
    OpenTelemetry.Tracer.set_attributes([
      {"compensation.duration_ms", System.convert_time_unit(duration, :native, :millisecond)},
      {"compensation.success", true}
    ])
    
    # Emit compensation completion telemetry
    :telemetry.execute([:self_sustaining, :reactor, :step, :compensate, :complete], %{
      step_name: step.name,
      reactor_id: telemetry_state[:reactor_id],
      duration: duration,
      success: true
    }, context)
    
    Logger.debug("Step compensation completed with telemetry", 
      step_name: step.name,
      reactor_id: telemetry_state[:reactor_id],
      duration_ms: System.convert_time_unit(duration, :native, :millisecond)
    )
    
    :ok
  end

  # Handle other events with minimal telemetry
  def event(_event, _step, _context), do: :ok

  # Private helper functions

  defp extract_telemetry_metadata(context) do
    context
    |> Map.get(:telemetry_metadata, %{})
    |> Map.merge(%{
      system_pid: inspect(self()),
      node: node(),
      system_time: System.system_time(),
      elixir_version: System.version()
    })
  end

  defp get_steps_count(context) do
    case context[:__reactor__] do
      %{steps: steps} when is_list(steps) -> length(steps)
      _ -> 0
    end
  end

  defp result_type_string(result) do
    case result do
      {:ok, _} -> "success"
      {:error, _} -> "error"
      :halt -> "halt"
      :retry -> "retry"
      _ -> "unknown"
    end
  end

  defp extract_error_details(error_or_errors) when is_list(error_or_errors) do
    %{
      type: "multiple_errors",
      message: "Multiple errors: #{length(error_or_errors)} errors",
      count: length(error_or_errors),
      stacktrace: extract_stacktrace(List.first(error_or_errors))
    }
  end

  defp extract_error_details(error) do
    %{
      type: error.__struct__ |> to_string(),
      message: Exception.message(error),
      count: 1,
      stacktrace: extract_stacktrace(error)
    }
  end

  defp extract_stacktrace(%{__exception__: true} = error) do
    case error do
      %{stacktrace: stacktrace} when is_list(stacktrace) -> 
        stacktrace |> Enum.take(5) |> inspect()
      _ -> 
        "No stacktrace available"
    end
  end
  defp extract_stacktrace(_), do: "No stacktrace available"

  defp generate_error_signature(error_or_errors) do
    error_string = inspect(error_or_errors)
    :crypto.hash(:md5, error_string) |> Base.encode16(case: :lower)
  end

  defp calculate_performance_metrics(telemetry_state, total_duration) do
    step_timings = telemetry_state[:step_timings] || %{}
    
    step_durations = Enum.map(step_timings, fn {step_name, timing} ->
      case timing do
        %{start_time: start_time} ->
          # Calculate approximate duration (may not be exact for completed steps)
          {step_name, System.monotonic_time() - start_time}
        _ ->
          {step_name, 0}
      end
    end)
    
    %{
      total_duration_ms: System.convert_time_unit(total_duration, :native, :millisecond),
      step_count: length(step_durations),
      avg_step_duration_ms: calculate_average_step_duration(step_durations),
      longest_step: find_longest_step(step_durations),
      memory_peak_mb: get_memory_usage() / 1024 / 1024,
      cpu_utilization: get_cpu_utilization()
    }
  end

  defp calculate_average_step_duration(step_durations) do
    if length(step_durations) > 0 do
      total_duration = Enum.reduce(step_durations, 0, fn {_name, duration}, acc -> 
        acc + duration 
      end)
      System.convert_time_unit(total_duration / length(step_durations), :native, :millisecond)
    else
      0
    end
  end

  defp find_longest_step(step_durations) do
    case Enum.max_by(step_durations, fn {_name, duration} -> duration end, fn -> nil end) do
      {name, duration} -> 
        %{
          name: name,
          duration_ms: System.convert_time_unit(duration, :native, :millisecond)
        }
      nil -> 
        %{name: "none", duration_ms: 0}
    end
  end

  defp calculate_arguments_size(arguments) when is_map(arguments) do
    arguments |> inspect() |> byte_size()
  end
  defp calculate_arguments_size(_), do: 0

  defp calculate_result_size(result) do
    result |> inspect() |> byte_size()
  end

  defp get_memory_usage do
    case :erlang.process_info(self(), :memory) do
      {:memory, memory} -> memory
      _ -> 0
    end
  end

  defp get_cpu_time do
    case :erlang.process_info(self(), :runtime) do
      {:runtime, {total_time, _}} -> total_time
      _ -> 0
    end
  end

  defp get_cpu_utilization do
    # Simple CPU utilization approximation
    if Code.ensure_loaded?(:cpu_sup) do
      case :cpu_sup.avg1() do
        load when is_number(load) -> load / 256 * 100
        _ -> 0
      end
    else
      0
    end
  rescue
    _ -> 0
  end
end