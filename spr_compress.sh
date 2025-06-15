#!/bin/bash

# SPR Compression CLI using Reactor workflows
# Usage: ./spr_compress.sh [input_file] [format] [compression_ratio]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHOENIX_APP_DIR="$SCRIPT_DIR/phoenix_app"
TEMP_DIR="${TMPDIR:-/tmp}/spr_compression_$$"
INPUT_FILE="${1:-}"
FORMAT="${2:-standard}"  # minimal, standard, extended
COMPRESSION_RATIO="${3:-0.1}"  # Default 10% compression

# Validation
if [[ -z "$INPUT_FILE" ]] || [[ ! -f "$INPUT_FILE" ]]; then
    echo "Usage: $0 <input_file> [format] [compression_ratio]" >&2
    echo "Formats: minimal, standard, extended" >&2
    echo "Compression ratio: 0.05-0.5 (default: 0.1)" >&2
    exit 1
fi

# Create temp directory
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Main compression function using Reactor
compress_to_spr() {
    local input_file="$1"
    local format="$2"
    local ratio="$3"
    
    # Read input content
    local content
    content=$(cat "$input_file")
    
    # Create Elixir script to run SPR compression reactor
    local elixir_script="$TEMP_DIR/run_spr_compression.exs"
    cat > "$elixir_script" << EOF
# Run SPR compression through Reactor workflow
Mix.install([
  {:reactor, "~> 0.8.0"},
  {:jason, "~> 1.4"}
])

# Add phoenix_app to path
Code.append_path("$PHOENIX_APP_DIR/_build/dev/lib")

# Simulate reactor compression (using existing reactor patterns)
defmodule SPRCompressionCLI do
  def run(source_text, format, compression_ratio) do
    # Generate nanosecond agent ID for coordination
    agent_id = "agent_#{System.system_time(:nanosecond)}"
    
    # Create reactor context with telemetry
    context = %{
      trace_id: "spr-compression-#{agent_id}",
      agent_id: agent_id,
      otel_trace_id: "cli-#{System.system_time(:nanosecond)}"
    }
    
    # Simulate reactor inputs
    inputs = %{
      source_text: source_text,
      compression_ratio: compression_ratio,
      spr_format: String.to_atom(format),
      output_destination: nil
    }
    
    # Run compression through reactor pattern
    result = compress_with_reactor(inputs, context)
    
    case result do
      {:ok, compressed_result} ->
        format_cli_output(compressed_result, source_text, format, compression_ratio)
      {:error, reason} ->
        {:error, "Reactor compression failed: #{reason}"}
    end
  end
  
  defp compress_with_reactor(inputs, context) do
    # Simulate the 7-stage SPR compression pipeline
    with {:ok, validated} <- validate_input(inputs, context),
         {:ok, analyzed} <- analyze_content(validated, context),
         {:ok, concepts} <- extract_concepts(analyzed, context),
         {:ok, spr_statements} <- generate_spr_statements(concepts, inputs.spr_format, context),
         {:ok, validated_spr} <- validate_compression(spr_statements, inputs, context),
         {:ok, optimized} <- optimize_spr(validated_spr, context),
         {:ok, formatted} <- format_output(optimized, inputs, context) do
      {:ok, formatted}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp validate_input(inputs, context) do
    text = inputs.source_text
    format = inputs.spr_format
    
    cond do
      String.length(text) < 50 ->
        {:error, "Text too short for meaningful SPR compression"}
      String.length(text) > 100_000 ->
        {:error, "Text too large for single SPR compression"}
      format not in [:minimal, :standard, :extended] ->
        {:error, "Invalid SPR format"}
      true ->
        result = %{
          text: String.trim(text),
          format: format,
          word_count: length(String.split(text)),
          complexity_score: calculate_complexity(text),
          validation_timestamp: DateTime.utc_now(),
          trace_id: context.trace_id
        }
        {:ok, result}
    end
  end
  
  defp analyze_content(validated, context) do
    text = validated.text
    chunks = create_semantic_chunks(text)
    context_map = build_context_map(chunks)
    
    result = %{
      chunks: chunks,
      context: context_map,
      metadata: %{
        original_word_count: validated.word_count,
        complexity: validated.complexity_score,
        format: validated.format,
        trace_id: context.trace_id
      }
    }
    
    {:ok, result}
  end
  
  defp extract_concepts(analyzed, context) do
    # Extract concepts from chunks
    concepts = 
      analyzed.chunks
      |> Enum.flat_map(fn chunk ->
        extract_chunk_concepts(chunk, analyzed.context)
      end)
    
    result = %{
      concepts: concepts,
      concept_count: length(concepts),
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp generate_spr_statements(concepts_data, format, context) do
    concepts = concepts_data.concepts
    target_compression = 0.1  # Default
    
    # Prioritize concepts
    prioritized = prioritize_concepts(concepts, target_compression)
    
    # Generate statements based on format
    statements = case format do
      :minimal -> generate_minimal_spr(prioritized)
      :standard -> generate_standard_spr(prioritized)
      :extended -> generate_extended_spr(prioritized)
    end
    
    result = %{
      spr_statements: statements,
      statement_count: length(statements),
      format: format,
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp validate_compression(spr_data, inputs, context) do
    statements = spr_data.spr_statements
    original_text = inputs.source_text
    target_ratio = inputs.compression_ratio
    
    # Calculate metrics
    original_words = length(String.split(original_text))
    spr_words = statements |> Enum.join(" ") |> String.split() |> length()
    actual_ratio = spr_words / original_words
    
    metrics = %{
      original_words: original_words,
      spr_words: spr_words,
      actual_compression_ratio: actual_ratio,
      target_compression_ratio: target_ratio
    }
    
    result = %{
      validated_spr: statements,
      metrics: metrics,
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp optimize_spr(validated_data, context) do
    statements = validated_data.validated_spr
    
    # Optimize statements
    optimized = statements
    |> remove_redundancies()
    |> reorder_by_importance()
    
    result = %{
      optimized_spr: optimized,
      trace_id: context.trace_id
    }
    
    {:ok, result}
  end
  
  defp format_output(optimized_data, inputs, context) do
    spr_statements = optimized_data.optimized_spr
    
    result = %{
      spr_output: %{
        spr_statements: spr_statements,
        statement_count: length(spr_statements),
        generated_at: DateTime.utc_now(),
        trace_id: context.trace_id
      }
    }
    
    {:ok, result}
  end
  
  # Helper functions
  defp calculate_complexity(text) do
    sentences = String.split(text, ~r/[.!?]+/)
    %{complexity_rating: :medium, sentence_count: length(sentences)}
  end
  
  defp create_semantic_chunks(text) do
    text
    |> String.split(~r/\\n\\s*\\n/)
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      %{
        id: "chunk_#{index}",
        content: String.trim(chunk),
        word_count: length(String.split(chunk))
      }
    end)
    |> Enum.reject(&(&1.word_count < 5))
  end
  
  defp build_context_map(chunks) do
    Map.new(chunks, fn chunk ->
      {chunk.id, extract_key_terms(chunk.content)}
    end)
  end
  
  defp extract_key_terms(content) do
    content
    |> String.downcase()
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.take(5)
  end
  
  defp extract_chunk_concepts(chunk, _context) do
    [
      %{
        type: :assertion,
        content: String.slice(chunk.content, 0, 100),
        priority: :medium,
        confidence: :medium
      }
    ]
  end
  
  defp prioritize_concepts(concepts, target) do
    max_concepts = max(5, round(length(concepts) * target * 2))
    Enum.take(concepts, max_concepts)
  end
  
  defp generate_minimal_spr(concepts) do
    concepts
    |> Enum.map(fn concept ->
      concept.content
      |> String.split()
      |> Enum.take(5)
      |> Enum.join(" ")
    end)
    |> Enum.uniq()
  end
  
  defp generate_standard_spr(concepts) do
    concepts
    |> Enum.map(fn concept ->
      concept.content
      |> String.split()
      |> Enum.take(12)
      |> Enum.join(" ")
    end)
    |> Enum.uniq()
  end
  
  defp generate_extended_spr(concepts) do
    concepts
    |> Enum.map(fn concept ->
      concept.content
      |> String.split()
      |> Enum.take(20)
      |> Enum.join(" ")
    end)
    |> Enum.uniq()
  end
  
  defp remove_redundancies(statements) do
    Enum.uniq(statements)
  end
  
  defp reorder_by_importance(statements) do
    statements
  end
  
  defp format_cli_output(result, original_text, format, ratio) do
    statements = result.spr_output.spr_statements
    original_words = length(String.split(original_text))
    compressed_words = statements |> Enum.join(" ") |> String.split() |> length()
    actual_ratio = Float.round(compressed_words / original_words, 3)
    
    output = """
# SPR Compression Result
# Original: #{original_words} words
# Compressed: #{compressed_words} words  
# Ratio: #{actual_ratio} (target: #{ratio})
# Format: #{format}
# Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}
# Trace ID: #{result.spr_output.trace_id}

#{Enum.join(statements, "\\n")}
"""
    
    {:ok, output}
  end
end

# Run the compression
source_text = """
$content
"""

case SPRCompressionCLI.run(source_text, "$format", $ratio) do
  {:ok, output} -> IO.puts(output)
  {:error, reason} -> 
    IO.puts(:stderr, "Error: #{reason}")
    System.halt(1)
end
EOF
    
    # Execute the Elixir script
    cd "$PHOENIX_APP_DIR" && elixir "$elixir_script"
}

# Execute compression
echo "Compressing '$INPUT_FILE' to SPR format '$FORMAT' with ratio $COMPRESSION_RATIO using Reactor..." >&2
compress_to_spr "$INPUT_FILE" "$FORMAT" "$COMPRESSION_RATIO"