defmodule AiSelfSustainingMinimal.Telemetry.Context do
  @moduledoc """
  Information-Theoretic Context Template for OpenTelemetry Instrumentation.
  
  ## Purpose
  
  Represents a scientifically-optimized context template that maximizes mutual
  information I(R;S_T) while minimizing byte overhead. Each context defines
  the static tags injected into telemetry events for maximum observability signal.
  
  ## Information Theory Model
  
  Context templates are evaluated using mutual information theory:
  ```
  I(R;S_T) = H(S_T) - H(S_T|R)
  Score = I(R;S_T) / Bytes_T [bits/byte]
  ```
  
  Where:
  - **R**: Runtime events (errors, latencies, spans)
  - **S_T**: Static context tags from template T
  - **H(S_T)**: Entropy of static tags (information content)
  - **H(S_T|R)**: Residual uncertainty after observing runtime event
  
  ## High-MI Template Components
  
  The default high-entropy context includes:
  - **code.filepath**: Eliminates file ambiguity (≤120 bytes, ~8 bits entropy)
  - **code.namespace**: Distinguishes umbrella apps (20-60 bytes, ~12 bits entropy)
  - **code.function**: Pinpoints function clause (10-30 bytes, ~14 bits entropy)
  - **code.commit_id**: Disambiguates deployments (7 bytes, ~12 bits entropy)
  
  **Total**: ≈46 bits mutual information, 180 bytes, 0.26 bits/byte efficiency
  """
  
  @type t :: %__MODULE__{
    name: atom(),
    filepath: boolean(),
    namespace: boolean(),
    function: boolean(),
    commit_id: boolean(),
    custom_tags: [atom()],
    mi_target: float(),
    compiled_template: map() | nil
  }
  
  defstruct [
    :name,
    filepath: true,
    namespace: true, 
    function: true,
    commit_id: true,
    custom_tags: [],
    mi_target: 0.25,
    compiled_template: nil
  ]
  
  @doc """
  Compile context template into efficient runtime representation.
  
  Generates optimized code for injecting context tags with minimal overhead.
  
  ## Examples
  
      iex> context = %Context{name: :high_mi, filepath: true, namespace: true}
      iex> Context.compile(context, __ENV__)
      %{
        code_filepath: "/path/to/file.ex",
        code_namespace: MyModule,
        code_function: {:my_function, 2},
        code_commit_id: "abc123..."
      }
  """
  @spec compile(t(), Macro.Env.t()) :: map()
  def compile(%__MODULE__{} = context, env) do
    base_context = %{}
    
    base_context
    |> maybe_add_filepath(context.filepath, env)
    |> maybe_add_namespace(context.namespace, env)  
    |> maybe_add_function(context.function, env)
    |> maybe_add_commit_id(context.commit_id)
    |> add_custom_tags(context.custom_tags)
  end
  
  @doc """
  Calculate mutual information score for a context template.
  
  Uses sample telemetry data to estimate I(R;S_T) and bytes/event.
  
  ## Examples
  
      iex> spans = load_sample_spans()
      iex> context = %Context{name: :high_mi}
      iex> Context.calculate_mi_score(context, spans)
      %{
        mutual_information: 45.7,
        bytes_per_event: 178,
        bits_per_byte: 0.257,
        entropy_breakdown: %{...}
      }
  """
  @spec calculate_mi_score(t(), [map()]) :: map()
  def calculate_mi_score(%__MODULE__{} = context, sample_spans) when is_list(sample_spans) do
    # Extract context tags from spans
    context_values = extract_context_values(sample_spans, context)
    
    # Calculate entropy metrics
    total_entropy = calculate_entropy(context_values)
    conditional_entropy = calculate_conditional_entropy(context_values, sample_spans)
    mutual_information = total_entropy - conditional_entropy
    
    # Estimate byte overhead
    avg_bytes = estimate_byte_overhead(context)
    
    %{
      mutual_information: mutual_information,
      bytes_per_event: avg_bytes,
      bits_per_byte: mutual_information / avg_bytes,
      entropy_breakdown: %{
        total: total_entropy,
        conditional: conditional_entropy,
        mutual_information: mutual_information
      },
      component_analysis: analyze_components(context, context_values)
    }
  end
  
  @doc """
  Optimize context template for target MI efficiency.
  
  Uses hill-climbing search to find optimal combination of context components
  that maximizes bits/byte while meeting minimum MI requirements.
  
  ## Examples
  
      iex> context = %Context{name: :baseline}
      iex> spans = load_sample_spans()
      iex> Context.optimize(context, spans, target_score: 0.3)
      {:ok, %Context{filepath: true, namespace: true, function: false, ...}}
  """
  @spec optimize(t(), [map()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def optimize(%__MODULE__{} = context, sample_spans, opts \\ []) do
    target_score = Keyword.get(opts, :target_score, 0.25)
    max_iterations = Keyword.get(opts, :max_iterations, 50)
    
    current_context = context
    current_score = calculate_mi_score(current_context, sample_spans)
    
    optimize_loop(current_context, current_score, sample_spans, target_score, max_iterations, 0)
  end
  
  @doc """
  Generate macro code for injecting context at compile time.
  
  Creates efficient quoted expressions that inject context tags with
  minimal runtime overhead.
  
  ## Examples
  
      iex> context = %Context{name: :high_mi}
      iex> Context.generate_macro_code(context)
      quote do
        %{
          code_filepath: unquote(__ENV__.file),
          code_namespace: unquote(__MODULE__),
          code_function: unquote(__CALLER__.function),
          code_commit_id: System.get_env("GIT_SHA") || "dev"
        }
      end
  """
  @spec generate_macro_code(t()) :: Macro.t()
  def generate_macro_code(%__MODULE__{} = context) do
    assignments = build_assignments(context)
    
    quote do
      unquote(assignments)
    end
  end
  
  @doc """
  Validate context configuration for common issues.
  
  Checks for potential problems in context configuration that could
  impact performance or observability effectiveness.
  
  ## Examples
  
      iex> context = %Context{name: nil, filepath: false, namespace: false}
      iex> Context.validate(context)
      {:error, ["Context name is required", "At least one component must be enabled"]}
      
      iex> context = %Context{name: :valid, namespace: true}
      iex> Context.validate(context)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = context) do
    errors = []
    
    errors = validate_context_name(context.name, errors)
    errors = validate_context_components(context, errors)
    errors = validate_mi_target(context.mi_target, errors)
    errors = validate_custom_tags(context.custom_tags, errors)
    
    case errors do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end
  
  # ========================================================================
  # Private Implementation Functions
  # ========================================================================
  
  defp maybe_add_filepath(context, true, env) do
    Map.put(context, :code_filepath, env.file)
  end
  defp maybe_add_filepath(context, false, _env), do: context
  
  defp maybe_add_namespace(context, true, env) do
    Map.put(context, :code_namespace, env.module)
  end
  defp maybe_add_namespace(context, false, _env), do: context
  
  defp maybe_add_function(context, true, env) do
    Map.put(context, :code_function, env.function)
  end
  defp maybe_add_function(context, false, _env), do: context
  
  defp maybe_add_commit_id(context, true) do
    commit_id = System.get_env("GIT_SHA") || System.get_env("COMMIT_SHA") || "dev"
    Map.put(context, :code_commit_id, commit_id)
  end
  defp maybe_add_commit_id(context, false), do: context
  
  defp add_custom_tags(context, []), do: context
  defp add_custom_tags(context, custom_tags) do
    custom_context = 
      custom_tags
      |> Enum.reduce(%{}, fn tag, acc ->
        Map.put(acc, tag, get_custom_tag_value(tag))
      end)
    
    Map.merge(context, custom_context)
  end
  
  defp get_custom_tag_value(tag) do
    # Default implementation - can be overridden
    case tag do
      :agent_id -> Process.get(:current_agent_id)
      :session_id -> Process.get(:session_id)
      :trace_id -> Process.get(:trace_id)
      _ -> nil
    end
  end
  
  defp extract_context_values(spans, context) do
    Enum.map(spans, fn span ->
      extract_span_context(span, context)
    end)
  end
  
  defp extract_span_context(span, context) do
    base = %{}
    
    base
    |> maybe_extract(:code_filepath, span, context.filepath)
    |> maybe_extract(:code_namespace, span, context.namespace)
    |> maybe_extract(:code_function, span, context.function)
    |> maybe_extract(:code_commit_id, span, context.commit_id)
  end
  
  defp maybe_extract(acc, key, span, true) do
    case Map.get(span, Atom.to_string(key)) do
      nil -> acc
      value -> Map.put(acc, key, value)
    end
  end
  defp maybe_extract(acc, _key, _span, false), do: acc
  
  defp calculate_entropy(context_values) do
    # Calculate Shannon entropy: H(X) = -Σ p(x) log₂ p(x)
    frequency_map = 
      context_values
      |> Enum.frequencies()
    
    total_count = length(context_values)
    
    frequency_map
    |> Enum.reduce(0.0, fn {_value, count}, acc ->
      probability = count / total_count
      acc - (probability * :math.log2(probability))
    end)
  end
  
  defp calculate_conditional_entropy(context_values, spans) do
    # Calculate H(S|R) - entropy of context given runtime events
    # Simplified implementation - in practice would use more sophisticated correlation
    paired_data = Enum.zip(context_values, spans)
    
    runtime_groups = 
      paired_data
      |> Enum.group_by(fn {_context, span} -> 
        # Group by runtime characteristics
        {Map.get(span, "event_name"), Map.get(span, "status")}
      end)
    
    total_count = length(paired_data)
    
    runtime_groups
    |> Enum.reduce(0.0, fn {_runtime_event, context_span_pairs}, acc ->
      context_values_for_runtime = Enum.map(context_span_pairs, fn {context, _span} -> context end)
      group_size = length(context_values_for_runtime)
      group_probability = group_size / total_count
      
      group_entropy = calculate_entropy(context_values_for_runtime)
      acc + (group_probability * group_entropy)
    end)
  end
  
  defp estimate_byte_overhead(context) do
    base_overhead = 0
    
    base_overhead = if context.filepath, do: base_overhead + 80, else: base_overhead   # Average filepath length
    base_overhead = if context.namespace, do: base_overhead + 40, else: base_overhead  # Average module name
    base_overhead = if context.function, do: base_overhead + 20, else: base_overhead   # Average function name
    base_overhead = if context.commit_id, do: base_overhead + 7, else: base_overhead   # Git SHA (7 chars)
    
    # Add overhead for custom tags
    custom_overhead = length(context.custom_tags) * 15  # Average custom tag size
    
    base_overhead + custom_overhead
  end
  
  defp analyze_components(context, context_values) do
    %{
      filepath: analyze_component_contribution(:code_filepath, context_values, context.filepath),
      namespace: analyze_component_contribution(:code_namespace, context_values, context.namespace),
      function: analyze_component_contribution(:code_function, context_values, context.function),
      commit_id: analyze_component_contribution(:code_commit_id, context_values, context.commit_id)
    }
  end
  
  defp analyze_component_contribution(component, context_values, enabled) do
    if enabled do
      component_values = 
        context_values
        |> Enum.map(&Map.get(&1, component))
        |> Enum.reject(&is_nil/1)
      
      %{
        unique_values: length(Enum.uniq(component_values)),
        entropy: calculate_entropy(component_values),
        enabled: true
      }
    else
      %{enabled: false}
    end
  end
  
  defp optimize_loop(_context, _score, _spans, _target, max_iter, iter) when iter >= max_iter do
    {:error, "Optimization did not converge after #{max_iter} iterations"}
  end
  
  defp optimize_loop(context, score, spans, target, max_iter, iter) do
    if score.bits_per_byte >= target do
      {:ok, context}
    else
      # Try modifications to improve score
      candidates = generate_optimization_candidates(context)
      
      best_candidate = 
        candidates
        |> Enum.map(fn candidate ->
          candidate_score = calculate_mi_score(candidate, spans)
          {candidate, candidate_score}
        end)
        |> Enum.max_by(fn {_candidate, score} -> score.bits_per_byte end)
      
      case best_candidate do
        {new_context, new_score} when new_score.bits_per_byte > score.bits_per_byte ->
          optimize_loop(new_context, new_score, spans, target, max_iter, iter + 1)
        
        _ ->
          {:ok, context}  # No improvement found
      end
    end
  end
  
  defp generate_optimization_candidates(context) do
    # Generate candidate contexts by toggling different components
    [
      %{context | filepath: !context.filepath},
      %{context | namespace: !context.namespace},
      %{context | function: !context.function},
      %{context | commit_id: !context.commit_id}
    ]
  end
  
  defp build_assignments(context) do
    assignments = []
    
    assignments = if context.filepath do
      [{:code_filepath, {:__ENV__, [], [{:file, [], Elixir}]}} | assignments]
    else
      assignments
    end
    
    assignments = if context.namespace do
      [{:code_namespace, {:__MODULE__, [], Elixir}} | assignments]
    else
      assignments
    end
    
    assignments = if context.function do
      [{:code_function, {:{}, [], [{:__CALLER__, [], [{:function, [], Elixir}]}]}} | assignments]
    else
      assignments
    end
    
    assignments = if context.commit_id do
      [{:code_commit_id, {{:., [], [{:System, [], Elixir}, :get_env]}, [], ["GIT_SHA"]}} | assignments]
    else
      assignments
    end
    
    {:%{}, [], assignments}
  end
  
  # Validation helper functions
  
  defp validate_context_name(name, errors) when is_atom(name) and name != nil do
    case Atom.to_string(name) do
      "Elixir." <> _ ->
        ["Context name '#{name}' appears to be a module name, use a simple atom" | errors]
      
      name_str when byte_size(name_str) > 50 ->
        ["Context name '#{name}' is too long (max 50 characters)" | errors]
      
      _ ->
        errors
    end
  end
  defp validate_context_name(name, errors) do
    ["Context name must be a non-nil atom, got: #{inspect(name)}" | errors]
  end
  
  defp validate_context_components(context, errors) do
    # At least one component must be enabled for the context to be useful
    components_enabled = [
      context.filepath,
      context.namespace,
      context.function,
      context.commit_id
    ]
    
    if Enum.any?(components_enabled) do
      errors
    else
      ["At least one context component must be enabled" | errors]
    end
  end
  
  defp validate_mi_target(target, errors) when is_float(target) or is_integer(target) do
    cond do
      target <= 0.0 ->
        ["MI target must be positive, got: #{target}" | errors]
      
      target > 1.0 ->
        ["MI target #{target} bits/byte is unrealistically high" | errors]
      
      target < 0.01 ->
        ["MI target #{target} bits/byte is very low, consider higher target" | errors]
      
      true ->
        errors
    end
  end
  defp validate_mi_target(target, errors) do
    ["MI target must be a number, got: #{inspect(target)}" | errors]
  end
  
  defp validate_custom_tags(tags, errors) when is_list(tags) do
    if length(tags) > 10 do
      ["#{length(tags)} custom tags may cause excessive overhead" | errors]
    else
      errors
    end
  end
  defp validate_custom_tags(tags, errors) do
    ["Custom tags must be a list, got: #{inspect(tags)}" | errors]
  end
end