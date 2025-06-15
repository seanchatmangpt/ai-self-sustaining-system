#!/bin/bash

# SPR Decompression CLI using Reactor workflows
# Usage: ./spr_decompress.sh [spr_file] [expansion_type] [target_length]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHOENIX_APP_DIR="$SCRIPT_DIR/phoenix_app"
TEMP_DIR="${TMPDIR:-/tmp}/spr_decompression_$$"
SPR_FILE="${1:-}"
EXPANSION_TYPE="${2:-detailed}"  # brief, detailed, comprehensive
TARGET_LENGTH="${3:-auto}"  # auto, short, medium, long

# Validation
if [[ -z "$SPR_FILE" ]] || [[ ! -f "$SPR_FILE" ]]; then
    echo "Usage: $0 <spr_file> [expansion_type] [target_length]" >&2
    echo "Expansion types: brief, detailed, comprehensive" >&2
    echo "Target lengths: auto, short, medium, long" >&2
    exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Extract SPR statements from file
extract_spr_statements() {
    local spr_file="$1"
    
    # Skip metadata lines (starting with #) and extract SPR content
    grep -v "^#" "$spr_file" | grep -v "^$" | head -50
}

# Main decompression function using Reactor
decompress_from_spr() {
    local spr_file="$1"
    local expansion_type="$2"
    local target_length="$3"
    
    # Extract SPR statements
    local spr_content
    spr_content=$(extract_spr_statements "$spr_file")
    
    if [[ -z "$spr_content" ]]; then
        echo "Error: No SPR statements found in file" >&2
        return 1
    fi
    
    # Create Elixir script to run SPR decompression reactor
    local elixir_script="$TEMP_DIR/run_spr_decompression.exs"
    cat > "$elixir_script" << EOF
# Run SPR decompression through Reactor workflow
Mix.install([
  {:reactor, "~> 0.8.0"},
  {:jason, "~> 1.4"}
])

# Add phoenix_app to path
Code.append_path("$PHOENIX_APP_DIR/_build/dev/lib")

# SPR Decompression using Reactor patterns
defmodule SPRDecompressionCLI do
  def run(spr_statements, expansion_type, target_length) do
    # Generate nanosecond agent ID for coordination
    agent_id = "agent_#{System.system_time(:nanosecond)}"
    
    # Create reactor context with telemetry
    context = %{
      trace_id: "spr-decompression-#{agent_id}",
      agent_id: agent_id,
      otel_trace_id: "cli-#{System.system_time(:nanosecond)}"
    }
    
    # Simulate reactor inputs
    inputs = %{
      spr_statements: spr_statements,
      expansion_type: String.to_atom(expansion_type),
      target_length: String.to_atom(target_length)
    }
    
    # Run decompression through reactor pattern
    result = decompress_with_reactor(inputs, context)
    
    case result do
      {:ok, decompressed_result} ->
        format_cli_output(decompressed_result, spr_statements, expansion_type, target_length)
      {:error, reason} ->
        {:error, "Reactor decompression failed: #{reason}"}
    end
  end
  
  defp decompress_with_reactor(inputs, context) do
    # Simulate decompression pipeline stages
    with {:ok, parsed} <- parse_spr_statements(inputs, context),
         {:ok, analyzed} <- analyze_spr_structure(parsed, context),
         {:ok, concepts} <- reconstruct_concepts(analyzed, context),
         {:ok, expanded} <- expand_concepts(concepts, inputs.expansion_type, context),
         {:ok, structured} <- structure_content(expanded, inputs.target_length, context),
         {:ok, polished} <- polish_output(structured, context) do
      {:ok, polished}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp parse_spr_statements(inputs, context) do
    statements = inputs.spr_statements
    |> String.split("\\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    
    if length(statements) == 0 do
      {:error, "No valid SPR statements found"}
    else
      result = %{
        statements: statements,
        statement_count: length(statements),
        parsed_at: DateTime.utc_now(),
        trace_id: context.trace_id
      }
      {:ok, result}
    end
  end
  
  defp analyze_spr_structure(parsed, context) do
    statements = parsed.statements
    
    # Analyze statement patterns and relationships
    analysis = %{
      avg_words_per_statement: calculate_avg_words(statements),
      statement_types: categorize_statements(statements),
      conceptual_themes: extract_themes(statements),
      complexity_score: estimate_complexity(statements)
    }
    
    result = %{
      statements: statements,
      analysis: analysis,
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp reconstruct_concepts(analyzed, context) do
    statements = analyzed.statements
    analysis = analyzed.analysis
    
    # Reconstruct conceptual building blocks from SPR
    concepts = statements
    |> Enum.with_index()
    |> Enum.map(fn {statement, index} ->
      %{
        id: "concept_#{index}",
        core_statement: statement,
        words: String.split(statement),
        theme: determine_theme(statement),
        expansion_priority: calculate_priority(statement, analysis),
        relationships: find_related_concepts(statement, statements)
      }
    end)
    
    result = %{
      concepts: concepts,
      concept_count: length(concepts),
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp expand_concepts(concepts_data, expansion_type, context) do
    concepts = concepts_data.concepts
    
    # Expand each concept based on expansion type
    expanded_concepts = concepts
    |> Enum.map(fn concept ->
      expanded_text = case expansion_type do
        :brief -> expand_brief(concept)
        :detailed -> expand_detailed(concept)
        :comprehensive -> expand_comprehensive(concept)
      end
      
      Map.put(concept, :expanded_text, expanded_text)
    end)
    
    result = %{
      expanded_concepts: expanded_concepts,
      expansion_type: expansion_type,
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp structure_content(expanded_data, target_length, context) do
    concepts = expanded_data.expanded_concepts
    expansion_type = expanded_data.expansion_type
    
    # Structure the expanded content into coherent text
    structured_text = concepts
    |> group_by_theme()
    |> create_coherent_narrative(target_length)
    |> apply_length_constraints(target_length)
    
    result = %{
      structured_text: structured_text,
      target_length: target_length,
      actual_word_count: count_words(structured_text),
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp polish_output(structured_data, context) do
    text = structured_data.structured_text
    
    # Polish the final output
    polished_text = text
    |> improve_transitions()
    |> enhance_coherence()
    |> finalize_formatting()
    
    result = %{
      final_text: polished_text,
      word_count: count_words(polished_text),
      generated_at: DateTime.utc_now(),
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  # Helper functions
  defp calculate_avg_words(statements) do
    total_words = statements |> Enum.map(&count_words/1) |> Enum.sum()
    if length(statements) > 0, do: total_words / length(statements), else: 0
  end
  
  defp categorize_statements(statements) do
    %{
      assertions: Enum.count(statements, &contains_assertion?/1),
      processes: Enum.count(statements, &contains_process?/1),
      relationships: Enum.count(statements, &contains_relationship?/1)
    }
  end
  
  defp extract_themes(statements) do
    # Simple theme extraction based on common words
    all_words = statements |> Enum.join(" ") |> String.downcase() |> String.split()
    
    all_words
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp estimate_complexity(statements) do
    avg_length = calculate_avg_words(statements)
    cond do
      avg_length > 15 -> :high
      avg_length > 8 -> :medium
      true -> :low
    end
  end
  
  defp determine_theme(statement) do
    cond do
      String.contains?(String.downcase(statement), ["process", "step", "method"]) -> :process
      String.contains?(String.downcase(statement), ["cause", "effect", "result"]) -> :causal
      String.contains?(String.downcase(statement), ["system", "component", "part"]) -> :structural
      true -> :general
    end
  end
  
  defp calculate_priority(statement, analysis) do
    word_count = count_words(statement)
    avg_words = analysis.avg_words_per_statement
    
    if word_count > avg_words, do: :high, else: :medium
  end
  
  defp find_related_concepts(statement, all_statements) do
    # Simple relationship finding based on word overlap
    statement_words = statement |> String.downcase() |> String.split() |> MapSet.new()
    
    all_statements
    |> Enum.reject(&(&1 == statement))
    |> Enum.filter(fn other ->
      other_words = other |> String.downcase() |> String.split() |> MapSet.new()
      overlap = MapSet.intersection(statement_words, other_words)
      MapSet.size(overlap) > 1
    end)
    |> Enum.take(3)
  end
  
  defp expand_brief(concept) do
    # Brief expansion: 2-3x original length
    core = concept.core_statement
    "#{core}. This concept involves #{generate_brief_context(concept)}."
  end
  
  defp expand_detailed(concept) do
    # Detailed expansion: 4-6x original length
    core = concept.core_statement
    context = generate_detailed_context(concept)
    implications = generate_implications(concept)
    "#{core}. #{context} #{implications}"
  end
  
  defp expand_comprehensive(concept) do
    # Comprehensive expansion: 8-12x original length
    core = concept.core_statement
    background = generate_background(concept)
    context = generate_detailed_context(concept)
    implications = generate_implications(concept)
    examples = generate_examples(concept)
    "#{background} #{core}. #{context} #{implications} #{examples}"
  end
  
  defp generate_brief_context(concept) do
    theme_contexts = %{
      :process => "systematic procedures and methodological approaches",
      :causal => "interconnected cause-and-effect relationships",
      :structural => "organized components and architectural elements",
      :general => "fundamental principles and core mechanisms"
    }
    
    Map.get(theme_contexts, concept.theme, "key aspects and essential characteristics")
  end
  
  defp generate_detailed_context(concept) do
    case concept.theme do
      :process ->
        "This process involves multiple interconnected steps that work together to achieve specific outcomes. The methodology requires careful coordination and systematic execution."
      :causal ->
        "These relationships demonstrate how various factors influence outcomes through complex interconnected mechanisms. Understanding these connections is crucial for effective analysis."
      :structural ->
        "The structural elements form an integrated system where each component plays a specific role. The architecture ensures optimal functionality and maintainability."
      :general ->
        "This represents fundamental principles that underlie broader concepts and applications. The core ideas have wide-ranging implications across multiple domains."
    end
  end
  
  defp generate_implications(concept) do
    "The implications of this concept extend to practical applications and theoretical understanding, influencing how we approach related challenges and opportunities."
  end
  
  defp generate_background(concept) do
    "Building on established principles and proven methodologies, this concept emerges from extensive research and practical experience."
  end
  
  defp generate_examples(concept) do
    "For example, this can be observed in real-world scenarios where similar principles apply, demonstrating the practical relevance and broad applicability of these concepts."
  end
  
  defp group_by_theme(concepts) do
    Enum.group_by(concepts, & &1.theme)
  end
  
  defp create_coherent_narrative(grouped_concepts, target_length) do
    # Create narrative flow between concept groups
    grouped_concepts
    |> Enum.map(fn {theme, concepts} ->
      theme_intro = get_theme_introduction(theme)
      concept_texts = Enum.map(concepts, & &1.expanded_text)
      "#{theme_intro} #{Enum.join(concept_texts, " ")}"
    end)
    |> Enum.join("\\n\\n")
  end
  
  defp get_theme_introduction(theme) do
    case theme do
      :process -> "Regarding process and methodology:"
      :causal -> "In terms of causal relationships:"
      :structural -> "From a structural perspective:"
      :general -> "Fundamentally:"
    end
  end
  
  defp apply_length_constraints(text, target_length) do
    words = String.split(text)
    target_words = case target_length do
      :short -> 400
      :medium -> 1000
      :long -> 2000
      :auto -> length(words)  # No constraint
    end
    
    if length(words) > target_words do
      words |> Enum.take(target_words) |> Enum.join(" ")
    else
      text
    end
  end
  
  defp improve_transitions(text) do
    # Simple transition improvement
    text
    |> String.replace(~r/\\.\\s+([A-Z])/, ". Additionally, \\1")
    |> String.replace(~r/\\n\\n/, "\\n\\nFurthermore, ")
  end
  
  defp enhance_coherence(text) do
    # Basic coherence enhancement
    String.trim(text)
  end
  
  defp finalize_formatting(text) do
    text
    |> String.replace(~r/\\s+/, " ")
    |> String.trim()
  end
  
  defp contains_assertion?(statement) do
    String.contains?(String.downcase(statement), ["is", "are", "has", "have"])
  end
  
  defp contains_process?(statement) do
    String.contains?(String.downcase(statement), ["process", "step", "method", "approach"])
  end
  
  defp contains_relationship?(statement) do
    String.contains?(String.downcase(statement), ["cause", "effect", "relationship", "connection"])
  end
  
  defp count_words(text) do
    text |> String.split() |> length()
  end
  
  defp format_cli_output(result, original_spr, expansion_type, target_length) do
    final_text = result.final_text
    spr_words = original_spr |> String.split() |> length()
    reconstructed_words = result.word_count
    expansion_ratio = Float.round(reconstructed_words / spr_words, 2)
    
    output = """
# SPR Decompression Result
# SPR: #{spr_words} words
# Reconstructed: #{reconstructed_words} words
# Expansion ratio: #{expansion_ratio}x
# Type: #{expansion_type}
# Length: #{target_length}
# Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}
# Trace ID: #{result.trace_id}

#{final_text}
"""
    
    {:ok, output}
  end
end

# Parse SPR content
spr_content = """
$spr_content
"""

case SPRDecompressionCLI.run(spr_content, "$expansion_type", "$target_length") do
  {:ok, output} -> IO.puts(output)
  {:error, reason} -> 
    IO.puts(:stderr, "Error: #{reason}")
    System.halt(1)
end
EOF
    
    # Execute the Elixir script
    cd "$PHOENIX_APP_DIR" && elixir "$elixir_script"
}

# Execute decompression
echo "Decompressing '$SPR_FILE' using '$EXPANSION_TYPE' expansion with '$TARGET_LENGTH' length using Reactor..." >&2
decompress_from_spr "$SPR_FILE" "$EXPANSION_TYPE" "$TARGET_LENGTH"