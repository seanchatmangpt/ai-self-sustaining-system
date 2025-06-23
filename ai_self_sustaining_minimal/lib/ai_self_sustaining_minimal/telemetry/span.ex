defmodule AiSelfSustainingMinimal.Telemetry.Span do
  @moduledoc """
  Information-Theoretic Span Definition for OpenTelemetry Instrumentation.
  
  ## Purpose
  
  Represents an optimized telemetry span configuration that balances observability
  signal with performance overhead. Each span definition specifies the exact
  telemetry data to collect and how to structure it for maximum mutual information.
  
  ## Performance Design
  
  Span definitions are compiled into efficient macros that inject telemetry
  with minimal runtime overhead:
  - **Compile-time optimization**: Template expansion at build time
  - **Zero-allocation contexts**: Pre-computed static tag maps
  - **Selective instrumentation**: Only collect high-value telemetry data
  - **Efficient serialization**: Optimized for OpenTelemetry exporters
  
  ## Information Theory Integration
  
  Each span contributes to overall system observability through:
  ```
  I(span) = H(context) + H(measurements) + H(metadata) - H(redundancy)
  ```
  
  Where span configurations are optimized to maximize unique information
  while minimizing overlapping signal across different instrumentation points.
  """
  
  alias AiSelfSustainingMinimal.Telemetry.Context
  
  @type t :: %__MODULE__{
    name: atom(),
    event_name: [atom()],
    context: atom(),
    measurements: [atom()],
    metadata: [atom()],
    sample_rate: float(),
    enabled: boolean(),
    compiled_macro: Macro.t() | nil
  }
  
  defstruct [
    :name,
    :event_name,
    context: :default,
    measurements: [],
    metadata: [],
    sample_rate: 1.0,
    enabled: true,
    compiled_macro: nil
  ]
  
  @doc """
  Compile span definition into efficient macro for runtime injection.
  
  Generates optimized quoted expressions that create telemetry spans with
  minimal performance overhead and maximum observability signal.
  
  ## Examples
  
      iex> span = %Span{
      ...>   name: :coordination_operation,
      ...>   event_name: [:coordination, :work, :claim],
      ...>   context: :high_mi,
      ...>   measurements: [:duration_ms, :memory_usage]
      ...> }
      iex> contexts = %{high_mi: %Context{...}}
      iex> Span.compile(span, contexts, __ENV__)
      quote do
        :telemetry.span(
          [:coordination, :work, :claim],
          %{
            code_filepath: "/path/to/file.ex",
            code_namespace: MyModule,
            duration_ms: var!(duration),
            memory_usage: var!(memory)
          },
          fn -> var!(body) end
        )
      end
  """
  @spec compile(t(), map(), Macro.Env.t()) :: Macro.t()
  def compile(%__MODULE__{} = span, contexts, env) do
    context_template = Map.get(contexts, span.context)
    
    if span.enabled and should_sample?(span.sample_rate) do
      generate_span_macro(span, context_template, env)
    else
      # Generate no-op macro for disabled or unsampled spans
      quote do
        var!(body)
      end
    end
  end
  
  @doc """
  Calculate mutual information contribution of a span definition.
  
  Analyzes how much unique observability signal this span provides
  relative to its byte overhead and other instrumentation points.
  
  ## Examples
  
      iex> span = %Span{name: :coordination_operation, ...}
      iex> sample_data = load_telemetry_sample()
      iex> Span.calculate_mi_contribution(span, sample_data)
      %{
        unique_information: 12.4,
        redundant_information: 2.1,
        byte_overhead: 156,
        efficiency_score: 0.067,
        recommendations: [...]
      }
  """
  @spec calculate_mi_contribution(t(), [map()]) :: map()
  def calculate_mi_contribution(%__MODULE__{} = span, sample_data) do
    # Extract span-specific events from sample data
    span_events = filter_span_events(sample_data, span.event_name)
    
    # Calculate information metrics
    event_entropy = calculate_event_entropy(span_events)
    measurement_entropy = calculate_measurement_entropy(span_events, span.measurements)
    metadata_entropy = calculate_metadata_entropy(span_events, span.metadata)
    
    # Estimate redundancy with other spans
    redundancy = estimate_redundancy(span_events, sample_data, span)
    
    # Calculate byte overhead
    overhead = estimate_span_overhead(span)
    
    total_information = event_entropy + measurement_entropy + metadata_entropy
    unique_information = total_information - redundancy
    
    %{
      unique_information: unique_information,
      redundant_information: redundancy,
      total_information: total_information,
      byte_overhead: overhead,
      efficiency_score: unique_information / overhead,
      component_breakdown: %{
        event_entropy: event_entropy,
        measurement_entropy: measurement_entropy,
        metadata_entropy: metadata_entropy
      },
      recommendations: generate_optimization_recommendations(span, unique_information, overhead)
    }
  end
  
  @doc """
  Optimize span configuration for maximum information efficiency.
  
  Uses information theory to find the optimal combination of measurements
  and metadata that maximizes observability signal per byte.
  
  ## Examples
  
      iex> span = %Span{name: :baseline_span, measurements: [:a, :b, :c, :d]}
      iex> sample_data = load_telemetry_sample()
      iex> Span.optimize(span, sample_data, target_efficiency: 0.1)
      {:ok, %Span{measurements: [:a, :c], metadata: [:important_tag]}}
  """
  @spec optimize(t(), [map()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def optimize(%__MODULE__{} = span, sample_data, opts \\ []) do
    target_efficiency = Keyword.get(opts, :target_efficiency, 0.08)
    max_iterations = Keyword.get(opts, :max_iterations, 30)
    
    current_span = span
    current_analysis = calculate_mi_contribution(current_span, sample_data)
    
    optimize_loop(current_span, current_analysis, sample_data, target_efficiency, max_iterations, 0)
  end
  
  @doc """
  Generate usage macro for the span definition.
  
  Creates a user-friendly macro that developers can use to instrument
  their code with the optimized span configuration.
  
  ## Examples
  
      iex> span = %Span{name: :work_processing, ...}
      iex> Span.generate_usage_macro(span)
      quote do
        defmacro with_work_processing_span(metadata \\\\ %{}, do: body) do
          # Generated instrumentation code
        end
      end
  """
  @spec generate_usage_macro(t()) :: Macro.t()
  def generate_usage_macro(%__MODULE__{} = span) do
    macro_name = :"with_#{span.name}_span"
    
    quote do
      defmacro unquote(macro_name)(metadata \\ %{}, do: body) do
        unquote(generate_span_implementation(span))
      end
    end
  end
  
  @doc """
  Validate span definition for common issues.
  
  Checks for potential problems in span configuration that could
  impact performance or observability effectiveness.
  
  ## Examples
  
      iex> span = %Span{name: :test, event_name: [], measurements: []}
      iex> Span.validate(span)
      {:error, ["Empty event_name", "No measurements or metadata defined"]}
      
      iex> span = %Span{name: :valid, event_name: [:test], measurements: [:duration]}
      iex> Span.validate(span)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = span) do
    errors = []
    
    errors = validate_event_name(span.event_name, errors)
    errors = validate_sample_rate(span.sample_rate, errors)
    errors = validate_measurements_metadata(span.measurements, span.metadata, errors)
    errors = validate_name(span.name, errors)
    
    case errors do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
  
  # ========================================================================
  # Private Implementation Functions
  # ========================================================================
  
  defp should_sample?(1.0), do: true
  defp should_sample?(rate) when rate <= 0.0, do: false
  defp should_sample?(rate) do
    :rand.uniform() <= rate
  end
  
  defp generate_span_macro(span, context_template, env) do
    context_map = if context_template do
      Context.compile(context_template, env)
    else
      %{}
    end
    
    quote do
      :telemetry.span(
        unquote(span.event_name),
        unquote(Macro.escape(context_map))
        |> Map.merge(var!(metadata, Span) || %{})
        |> add_measurements(unquote(span.measurements))
        |> add_span_metadata(unquote(span.metadata)),
        fn -> var!(body, Span) end
      )
    end
  end
  
  defp generate_span_implementation(span) do
    quote do
      # Inject context and create span
      context_tags = unquote(generate_context_injection(span))
      
      :telemetry.span(
        unquote(span.event_name),
        Map.merge(context_tags, metadata),
        fn -> body end
      )
    end
  end
  
  defp generate_context_injection(span) do
    quote do
      %{
        code_filepath: __ENV__.file,
        code_namespace: __MODULE__,
        code_function: __CALLER__.function,
        span_name: unquote(span.name),
        measurements: unquote(span.measurements),
        metadata_keys: unquote(span.metadata)
      }
    end
  end
  
  defp filter_span_events(sample_data, event_name) do
    Enum.filter(sample_data, fn event ->
      Map.get(event, "event_name") == event_name or
      Map.get(event, :event_name) == event_name
    end)
  end
  
  defp calculate_event_entropy(events) do
    # Calculate entropy of event occurrences
    if length(events) == 0 do
      0.0
    else
      # For now, simplified - would analyze event patterns in real implementation
      :math.log2(length(events))
    end
  end
  
  defp calculate_measurement_entropy(events, measurements) do
    if length(measurements) == 0 or length(events) == 0 do
      0.0
    else
      # Calculate entropy across measurement values
      measurements
      |> Enum.map(fn measurement ->
        values = extract_measurement_values(events, measurement)
        calculate_value_entropy(values)
      end)
      |> Enum.sum()
    end
  end
  
  defp calculate_metadata_entropy(events, metadata_keys) do
    if length(metadata_keys) == 0 or length(events) == 0 do
      0.0
    else
      # Calculate entropy across metadata values
      metadata_keys
      |> Enum.map(fn key ->
        values = extract_metadata_values(events, key)
        calculate_value_entropy(values)
      end)
      |> Enum.sum()
    end
  end
  
  defp extract_measurement_values(events, measurement) do
    Enum.map(events, fn event ->
      measurements = Map.get(event, "measurements") || Map.get(event, :measurements) || %{}
      Map.get(measurements, Atom.to_string(measurement)) || Map.get(measurements, measurement)
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  defp extract_metadata_values(events, key) do
    Enum.map(events, fn event ->
      metadata = Map.get(event, "metadata") || Map.get(event, :metadata) || %{}
      Map.get(metadata, Atom.to_string(key)) || Map.get(metadata, key)
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  defp calculate_value_entropy(values) do
    if length(values) == 0 do
      0.0
    else
      frequencies = Enum.frequencies(values)
      total = length(values)
      
      frequencies
      |> Enum.reduce(0.0, fn {_value, count}, acc ->
        p = count / total
        acc - (p * :math.log2(p))
      end)
    end
  end
  
  defp estimate_redundancy(span_events, all_events, span) do
    # Simplified redundancy estimation
    # In practice, would analyze overlap with other instrumentation
    event_overlap = estimate_event_overlap(span.event_name, all_events)
    measurement_overlap = estimate_measurement_overlap(span.measurements, all_events)
    
    event_overlap + measurement_overlap
  end
  
  defp estimate_event_overlap(event_name, all_events) do
    # Estimate how much this event_name overlaps with others
    similar_events = 
      all_events
      |> Enum.filter(fn event ->
        other_name = Map.get(event, "event_name") || Map.get(event, :event_name)
        events_overlap?(event_name, other_name)
      end)
    
    # Simple overlap metric
    length(similar_events) / length(all_events) * 5.0  # Arbitrary scaling
  end
  
  defp estimate_measurement_overlap(measurements, all_events) do
    # Estimate measurement redundancy across all events
    if length(measurements) == 0 do
      0.0
    else
      # Simplified calculation
      length(measurements) * 0.5
    end
  end
  
  defp events_overlap?(event1, event2) when is_list(event1) and is_list(event2) do
    # Check if event names share common prefixes
    common_prefix_length = count_common_prefix(event1, event2)
    common_prefix_length >= 1
  end
  defp events_overlap?(_event1, _event2), do: false
  
  defp count_common_prefix(list1, list2) do
    Enum.zip(list1, list2)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> length()
  end
  
  defp estimate_span_overhead(span) do
    base_overhead = 50  # Base span overhead
    
    event_name_overhead = length(span.event_name) * 10
    measurement_overhead = length(span.measurements) * 8
    metadata_overhead = length(span.metadata) * 12
    
    base_overhead + event_name_overhead + measurement_overhead + metadata_overhead
  end
  
  defp generate_optimization_recommendations(span, unique_info, overhead) do
    recommendations = []
    
    efficiency = unique_info / overhead
    
    recommendations = if efficiency < 0.05 do
      ["Consider reducing measurements or metadata to improve efficiency" | recommendations]
    else
      recommendations
    end
    
    recommendations = if length(span.measurements) > 5 do
      ["High number of measurements may impact performance" | recommendations]
    else
      recommendations
    end
    
    recommendations = if span.sample_rate == 1.0 and efficiency < 0.1 do
      ["Consider sampling this span to reduce overhead" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
  
  defp optimize_loop(span, analysis, sample_data, target, max_iter, iter) when iter >= max_iter do
    {:error, "Optimization did not converge after #{max_iter} iterations"}
  end
  
  defp optimize_loop(span, analysis, sample_data, target, max_iter, iter) do
    if analysis.efficiency_score >= target do
      {:ok, span}
    else
      # Generate optimization candidates
      candidates = generate_span_candidates(span)
      
      best_candidate = 
        candidates
        |> Enum.map(fn candidate ->
          candidate_analysis = calculate_mi_contribution(candidate, sample_data)
          {candidate, candidate_analysis}
        end)
        |> Enum.max_by(fn {_candidate, analysis} -> analysis.efficiency_score end)
      
      case best_candidate do
        {new_span, new_analysis} when new_analysis.efficiency_score > analysis.efficiency_score ->
          optimize_loop(new_span, new_analysis, sample_data, target, max_iter, iter + 1)
        
        _ ->
          {:ok, span}  # No improvement found
      end
    end
  end
  
  defp generate_span_candidates(span) do
    # Generate candidate spans by modifying measurements and metadata
    measurement_candidates = generate_measurement_candidates(span)
    metadata_candidates = generate_metadata_candidates(span)
    sample_rate_candidates = generate_sample_rate_candidates(span)
    
    measurement_candidates ++ metadata_candidates ++ sample_rate_candidates
  end
  
  defp generate_measurement_candidates(span) do
    # Try removing each measurement
    span.measurements
    |> Enum.map(fn measurement ->
      new_measurements = List.delete(span.measurements, measurement)
      %{span | measurements: new_measurements}
    end)
  end
  
  defp generate_metadata_candidates(span) do
    # Try removing each metadata key
    span.metadata
    |> Enum.map(fn key ->
      new_metadata = List.delete(span.metadata, key)
      %{span | metadata: new_metadata}
    end)
  end
  
  defp generate_sample_rate_candidates(span) do
    # Try different sample rates
    [0.5, 0.1, 0.01]
    |> Enum.map(fn rate ->
      %{span | sample_rate: rate}
    end)
  end
  
  # Validation functions
  
  defp validate_event_name([], errors), do: ["Empty event_name" | errors]
  defp validate_event_name(event_name, errors) when is_list(event_name) do
    if Enum.all?(event_name, &is_atom/1) do
      errors
    else
      ["event_name must be a list of atoms" | errors]
    end
  end
  defp validate_event_name(_event_name, errors), do: ["event_name must be a list" | errors]
  
  defp validate_sample_rate(rate, errors) when is_float(rate) or is_integer(rate) do
    if rate >= 0.0 and rate <= 1.0 do
      errors
    else
      ["sample_rate must be between 0.0 and 1.0" | errors]
    end
  end
  defp validate_sample_rate(_rate, errors), do: ["sample_rate must be a number" | errors]
  
  defp validate_measurements_metadata([], [], errors), do: ["No measurements or metadata defined" | errors]
  defp validate_measurements_metadata(_measurements, _metadata, errors), do: errors
  
  defp validate_name(name, errors) when is_atom(name), do: errors
  defp validate_name(_name, errors), do: ["name must be an atom" | errors]
end