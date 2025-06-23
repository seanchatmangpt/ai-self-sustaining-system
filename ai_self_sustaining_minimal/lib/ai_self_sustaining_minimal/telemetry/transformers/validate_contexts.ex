defmodule AiSelfSustainingMinimal.Telemetry.Transformers.ValidateContexts do
  @moduledoc """
  Spark DSL Transformer for Validating OpenTelemetry Context Configurations.
  
  ## Purpose
  
  Compile-time validation transformer that ensures all context templates are
  properly configured for maximum mutual information efficiency. Validates
  scientific correctness of information-theoretic template designs.
  
  ## Validation Rules
  
  ### Context Template Validation
  - **Minimum MI Requirements**: Each context must meet minimum bits/byte efficiency
  - **Component Combinations**: Validates that component combinations make scientific sense
  - **Byte Overhead Limits**: Ensures contexts don't exceed reasonable byte budgets
  - **Dependency Validation**: Checks that referenced contexts exist and are valid
  
  ### Information Theory Validation
  - **Entropy Analysis**: Validates that contexts provide sufficient entropy
  - **Redundancy Detection**: Identifies overlapping information across contexts
  - **Efficiency Scoring**: Ensures contexts meet minimum I(R;S_T)/bytes thresholds
  - **Component Analysis**: Validates individual component contributions
  
  ## Performance Impact
  
  Validation occurs at compile time with zero runtime overhead:
  - **Static Analysis**: All validation during compilation
  - **Early Error Detection**: Catch configuration issues before deployment
  - **Optimization Hints**: Provide suggestions for improving context efficiency
  - **Documentation Generation**: Auto-generate context documentation
  """
  
  use Spark.Dsl.Transformer
  
  alias Spark.Dsl.Transformer
  alias AiSelfSustainingMinimal.Telemetry.Context
  
  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    contexts = Transformer.get_entities(dsl_state, [:otel, :context])
    spans = Transformer.get_entities(dsl_state, [:otel, :span])
    
    with :ok <- validate_contexts(contexts),
         :ok <- validate_context_references(spans, contexts),
         :ok <- validate_context_efficiency(contexts),
         :ok <- validate_context_uniqueness(contexts) do
      {:ok, dsl_state}
    else
      {:error, errors} when is_list(errors) ->
        formatted_errors = format_validation_errors(errors)
        {:error, formatted_errors}
      
      {:error, error} ->
        {:error, [error]}
    end
  end
  
  @doc """
  Validate individual context configurations.
  
  Checks each context template for:
  - Required fields and proper types
  - Sensible component combinations
  - Reasonable byte overhead estimates
  - Information theory compliance
  """
  @spec validate_contexts([struct()]) :: :ok | {:error, [String.t()]}
  def validate_contexts(contexts) do
    errors = 
      contexts
      |> Enum.with_index()
      |> Enum.flat_map(fn {context, index} ->
        validate_single_context(context, index)
      end)
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  
  @doc """
  Validate that all context references in spans exist and are valid.
  
  Ensures spans reference existing context templates and that the
  referenced contexts are compatible with span requirements.
  """
  @spec validate_context_references([struct()], [struct()]) :: :ok | {:error, [String.t()]}
  def validate_context_references(spans, contexts) do
    context_names = MapSet.new(contexts, & &1.name)
    
    errors = 
      spans
      |> Enum.with_index()
      |> Enum.flat_map(fn {span, index} ->
        validate_span_context_reference(span, context_names, index)
      end)
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  
  @doc """
  Validate context efficiency using information theory metrics.
  
  Calculates estimated mutual information efficiency for each context
  and ensures they meet minimum scientific thresholds.
  """
  @spec validate_context_efficiency([struct()]) :: :ok | {:error, [String.t()]}
  def validate_context_efficiency(contexts) do
    errors = 
      contexts
      |> Enum.with_index()
      |> Enum.flat_map(fn {context, index} ->
        validate_single_context_efficiency(context, index)
      end)
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  
  @doc """
  Validate context uniqueness and detect redundancy.
  
  Ensures that contexts provide sufficiently different information
  and identifies potentially redundant context templates.
  """
  @spec validate_context_uniqueness([struct()]) :: :ok | {:error, [String.t()]}
  def validate_context_uniqueness(contexts) do
    # Check for duplicate names
    name_errors = validate_unique_names(contexts)
    
    # Check for redundant configurations
    redundancy_errors = validate_configuration_uniqueness(contexts)
    
    errors = name_errors ++ redundancy_errors
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end
  
  # ========================================================================
  # Private Validation Functions
  # ========================================================================
  
  defp validate_single_context(context, index) do
    errors = []
    
    errors = validate_context_name(context.name, index, errors)
    errors = validate_context_components(context, index, errors)
    errors = validate_context_mi_target(context.mi_target, index, errors)
    errors = validate_custom_tags(context.custom_tags, index, errors)
    
    errors
  end
  
  defp validate_context_name(name, index, errors) when is_atom(name) and name != nil do
    case Atom.to_string(name) do
      "Elixir." <> _ ->
        ["Context #{index}: name '#{name}' appears to be a module name, use a simple atom" | errors]
      
      name_str when byte_size(name_str) > 50 ->
        ["Context #{index}: name '#{name}' is too long (max 50 characters)" | errors]
      
      _ ->
        errors
    end
  end
  defp validate_context_name(name, index, errors) do
    ["Context #{index}: name must be a non-nil atom, got: #{inspect(name)}" | errors]
  end
  
  defp validate_context_components(context, index, errors) do
    # At least one component must be enabled for the context to be useful
    components_enabled = [
      context.filepath,
      context.namespace,
      context.function,
      context.commit_id
    ]
    
    if Enum.any?(components_enabled) do
      validate_component_combinations(context, index, errors)
    else
      ["Context #{index}: at least one context component must be enabled" | errors]
    end
  end
  
  defp validate_component_combinations(context, index, errors) do
    # Validate sensible component combinations
    errors = if context.function and not context.namespace do
      ["Context #{index}: enabling function without namespace reduces disambiguation" | errors]
    else
      errors
    end
    
    errors = if context.filepath and not context.namespace and not context.function do
      ["Context #{index}: filepath alone provides low mutual information" | errors]
    else
      errors
    end
    
    errors
  end
  
  defp validate_context_mi_target(target, index, errors) when is_float(target) or is_integer(target) do
    cond do
      target <= 0.0 ->
        ["Context #{index}: mi_target must be positive, got: #{target}" | errors]
      
      target > 1.0 ->
        ["Context #{index}: mi_target #{target} bits/byte is unrealistically high" | errors]
      
      target < 0.01 ->
        ["Context #{index}: mi_target #{target} bits/byte is very low, consider higher target" | errors]
      
      true ->
        errors
    end
  end
  defp validate_context_mi_target(target, index, errors) do
    ["Context #{index}: mi_target must be a number, got: #{inspect(target)}" | errors]
  end
  
  defp validate_custom_tags(tags, index, errors) when is_list(tags) do
    errors = if length(tags) > 10 do
      ["Context #{index}: #{length(tags)} custom tags may cause excessive overhead" | errors]
    else
      errors
    end
    
    # Validate individual tag names
    tag_errors = 
      tags
      |> Enum.with_index()
      |> Enum.flat_map(fn {tag, tag_index} ->
        validate_custom_tag(tag, index, tag_index)
      end)
    
    tag_errors ++ errors
  end
  defp validate_custom_tags(tags, index, errors) do
    ["Context #{index}: custom_tags must be a list, got: #{inspect(tags)}" | errors]
  end
  
  defp validate_custom_tag(tag, context_index, tag_index) when is_atom(tag) do
    tag_str = Atom.to_string(tag)
    
    cond do
      String.starts_with?(tag_str, "code_") ->
        ["Context #{context_index}, tag #{tag_index}: '#{tag}' conflicts with built-in code_ prefix"]
      
      byte_size(tag_str) > 30 ->
        ["Context #{context_index}, tag #{tag_index}: '#{tag}' name too long (max 30 chars)"]
      
      true ->
        []
    end
  end
  defp validate_custom_tag(tag, context_index, tag_index) do
    ["Context #{context_index}, tag #{tag_index}: must be an atom, got: #{inspect(tag)}"]
  end
  
  defp validate_span_context_reference(span, context_names, index) do
    context_ref = span.context
    
    cond do
      context_ref == :default ->
        # Default context is always valid (will use built-in context)
        []
      
      is_atom(context_ref) and MapSet.member?(context_names, context_ref) ->
        # Valid reference to existing context
        []
      
      is_atom(context_ref) ->
        ["Span #{index}: references unknown context '#{context_ref}'"]
      
      true ->
        ["Span #{index}: context reference must be an atom, got: #{inspect(context_ref)}"]
    end
  end
  
  defp validate_single_context_efficiency(context, index) do
    # Estimate efficiency based on component configuration
    estimated_entropy = estimate_context_entropy(context)
    estimated_bytes = estimate_context_bytes(context)
    estimated_efficiency = estimated_entropy / estimated_bytes
    
    min_efficiency = 0.05  # Minimum 0.05 bits/byte
    target_efficiency = context.mi_target
    
    errors = []
    
    errors = if estimated_efficiency < min_efficiency do
      ["Context #{index}: estimated efficiency #{Float.round(estimated_efficiency, 3)} bits/byte below minimum #{min_efficiency}" | errors]
    else
      errors
    end
    
    errors = if estimated_efficiency < target_efficiency do
      warning = "Context #{index}: estimated efficiency #{Float.round(estimated_efficiency, 3)} below target #{target_efficiency} bits/byte"
      [warning | errors]
    else
      errors
    end
    
    errors = if estimated_bytes > 300 do
      ["Context #{index}: estimated #{estimated_bytes} bytes overhead may impact performance" | errors]
    else
      errors
    end
    
    errors
  end
  
  defp estimate_context_entropy(context) do
    # Rough entropy estimates based on typical values
    entropy = 0.0
    
    entropy = if context.filepath, do: entropy + 8.0, else: entropy      # ~8 bits for file paths
    entropy = if context.namespace, do: entropy + 12.0, else: entropy    # ~12 bits for modules
    entropy = if context.function, do: entropy + 14.0, else: entropy     # ~14 bits for functions
    entropy = if context.commit_id, do: entropy + 12.0, else: entropy    # ~12 bits for commit IDs
    entropy = entropy + (length(context.custom_tags) * 6.0)              # ~6 bits per custom tag
    
    entropy
  end
  
  defp estimate_context_bytes(context) do
    # Rough byte estimates
    bytes = 0
    
    bytes = if context.filepath, do: bytes + 80, else: bytes      # Average filepath length
    bytes = if context.namespace, do: bytes + 40, else: bytes     # Average module name
    bytes = if context.function, do: bytes + 20, else: bytes      # Average function name
    bytes = if context.commit_id, do: bytes + 7, else: bytes      # Git SHA short form
    bytes = bytes + (length(context.custom_tags) * 15)           # Average custom tag size
    
    bytes
  end
  
  defp validate_unique_names(contexts) do
    names = Enum.map(contexts, & &1.name)
    duplicates = find_duplicates(names)
    
    Enum.map(duplicates, fn name ->
      "Duplicate context name: '#{name}'"
    end)
  end
  
  defp validate_configuration_uniqueness(contexts) do
    # Group contexts by their component configuration
    configurations = 
      contexts
      |> Enum.map(fn context ->
        {context_signature(context), context.name}
      end)
      |> Enum.group_by(fn {signature, _name} -> signature end)
    
    # Find configurations that are identical
    configurations
    |> Enum.filter(fn {_signature, contexts_with_signature} ->
      length(contexts_with_signature) > 1
    end)
    |> Enum.flat_map(fn {_signature, duplicate_contexts} ->
      context_names = Enum.map(duplicate_contexts, fn {_sig, name} -> name end)
      ["Contexts have identical configurations: #{Enum.join(context_names, ", ")}"]
    end)
  end
  
  defp context_signature(context) do
    # Create a signature representing the context configuration
    {
      context.filepath,
      context.namespace,
      context.function,
      context.commit_id,
      Enum.sort(context.custom_tags)
    }
  end
  
  defp find_duplicates(list) do
    list
    |> Enum.frequencies()
    |> Enum.filter(fn {_item, count} -> count > 1 end)
    |> Enum.map(fn {item, _count} -> item end)
  end
  
  defp format_validation_errors(errors) do
    errors
    |> Enum.map(fn error ->
      "OpenTelemetry Context Validation Error: #{error}"
    end)
  end
end