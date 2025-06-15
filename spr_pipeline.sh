#!/bin/bash

# SPR Pipeline CLI - Complete compression/decompression workflow
# Usage: ./spr_pipeline.sh [command] [options...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"

# Pipeline commands
show_usage() {
    cat << EOF
SPR Pipeline - Sparse Priming Representation compression/decompression using Claude Code

USAGE:
    $0 compress <input_file> [format] [ratio]
    $0 decompress <spr_file> [expansion] [length] 
    $0 roundtrip <input_file> [format] [expansion]
    $0 batch <directory> [format] [ratio]
    $0 validate <spr_file>
    $0 metrics <spr_file>

REACTOR INTEGRATION:
    All operations run through Elixir Reactor workflows with:
    - Nanosecond-precision agent coordination
    - OpenTelemetry distributed tracing
    - Full telemetry integration and monitoring
    - Atomic state transitions and error handling

COMMANDS:
    compress     Compress text to SPR format
    decompress   Expand SPR back to full text
    roundtrip    Compress then decompress (quality test)
    batch        Process all .txt files in directory
    validate     Check SPR format and quality
    metrics      Show compression statistics

FORMATS:
    minimal      Ultra-compressed (3-7 words/statement)
    standard     Balanced compression (8-15 words/statement)  
    extended     Context-preserved (10-25 words/statement)

EXPANSION TYPES:
    brief        Concise with essentials
    detailed     Full explanation with context
    comprehensive Extensive with background

EXAMPLES:
    $0 compress document.txt standard 0.1
    $0 decompress document.spr detailed medium
    $0 roundtrip document.txt minimal brief
    $0 batch ./documents/ standard 0.15
    $0 validate document.spr
    $0 metrics document.spr
EOF
}

# Compression wrapper
compress_file() {
    local input_file="$1"
    local format="${2:-standard}"
    local ratio="${3:-0.1}"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' not found" >&2
        return 1
    fi
    
    "$SCRIPT_DIR/spr_compress.sh" "$input_file" "$format" "$ratio"
}

# Decompression wrapper  
decompress_file() {
    local spr_file="$1"
    local expansion="${2:-detailed}"
    local length="${3:-auto}"
    
    if [[ ! -f "$spr_file" ]]; then
        echo "Error: SPR file '$spr_file' not found" >&2
        return 1
    fi
    
    "$SCRIPT_DIR/spr_decompress.sh" "$spr_file" "$expansion" "$length"
}

# Roundtrip test (compress then decompress)
roundtrip_test() {
    local input_file="$1"
    local format="${2:-standard}"
    local expansion="${3:-detailed}"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file '$input_file' not found" >&2
        return 1
    fi
    
    local temp_dir="${TMPDIR:-/tmp}/spr_roundtrip_$$"
    mkdir -p "$temp_dir"
    trap "rm -rf $temp_dir" EXIT
    
    local spr_file="$temp_dir/compressed.spr"
    local decompressed_file="$temp_dir/decompressed.txt"
    
    echo "=== ROUNDTRIP TEST ===" >&2
    echo "Input: $input_file" >&2
    echo "Format: $format" >&2
    echo "Expansion: $expansion" >&2
    echo >&2
    
    # Compress
    echo "Compressing..." >&2
    compress_file "$input_file" "$format" > "$spr_file"
    
    # Decompress
    echo "Decompressing..." >&2
    decompress_file "$spr_file" "$expansion" > "$decompressed_file"
    
    # Show results
    local original_words spr_words final_words
    original_words=$(wc -w < "$input_file")
    spr_words=$(grep -v "^#" "$spr_file" | wc -w)
    final_words=$(grep -v "^#" "$decompressed_file" | wc -w)
    
    echo "=== ROUNDTRIP RESULTS ===" >&2
    echo "Original: $original_words words" >&2
    echo "SPR: $spr_words words" >&2
    echo "Final: $final_words words" >&2
    echo "Compression: $(echo "scale=2; $spr_words / $original_words * 100" | bc -l)%" >&2
    echo "Expansion: $(echo "scale=1; $final_words / $spr_words" | bc -l)x" >&2
    echo >&2
    
    # Output final result
    cat "$decompressed_file"
}

# Batch processing
batch_process() {
    local directory="$1"
    local format="${2:-standard}"
    local ratio="${3:-0.1}"
    
    if [[ ! -d "$directory" ]]; then
        echo "Error: Directory '$directory' not found" >&2
        return 1
    fi
    
    local output_dir="$directory/spr_output"
    mkdir -p "$output_dir"
    
    echo "Processing .txt files in '$directory'..." >&2
    echo "Format: $format, Ratio: $ratio" >&2
    echo "Output directory: $output_dir" >&2
    echo >&2
    
    local count=0
    for input_file in "$directory"/*.txt; do
        if [[ -f "$input_file" ]]; then
            local basename=$(basename "$input_file" .txt)
            local output_file="$output_dir/${basename}.spr"
            
            echo "Processing: $basename" >&2
            compress_file "$input_file" "$format" "$ratio" > "$output_file"
            ((count++))
        fi
    done
    
    echo >&2
    echo "Processed $count files" >&2
    echo "SPR files saved to: $output_dir" >&2
}

# Validate SPR format
validate_spr() {
    local spr_file="$1"
    
    if [[ ! -f "$spr_file" ]]; then
        echo "Error: SPR file '$spr_file' not found" >&2
        return 1
    fi
    
    echo "Validating SPR file: $spr_file" >&2
    echo >&2
    
    # Check file structure
    local has_metadata has_statements
    has_metadata=$(grep -c "^#" "$spr_file" || true)
    has_statements=$(grep -cv "^#\|^$" "$spr_file" || true)
    
    echo "Structure validation:" >&2
    echo "  Metadata lines: $has_metadata" >&2
    echo "  SPR statements: $has_statements" >&2
    
    if [[ $has_statements -eq 0 ]]; then
        echo "  Status: ❌ INVALID - No SPR statements found" >&2
        return 1
    fi
    
    # Check statement quality
    local avg_words_per_statement
    avg_words_per_statement=$(grep -v "^#\|^$" "$spr_file" | \
        awk '{sum += NF; count++} END {if(count > 0) print sum/count; else print 0}')
    
    echo "Quality metrics:" >&2
    echo "  Average words per statement: $avg_words_per_statement" >&2
    
    # Determine quality rating
    local quality_rating
    if (( $(echo "$avg_words_per_statement >= 3 && $avg_words_per_statement <= 25" | bc -l) )); then
        quality_rating="✅ GOOD"
    else
        quality_rating="⚠️  QUESTIONABLE"
    fi
    
    echo "  Quality rating: $quality_rating" >&2
    echo >&2
    echo "Validation complete." >&2
}

# Show compression metrics
show_metrics() {
    local spr_file="$1"
    
    if [[ ! -f "$spr_file" ]]; then
        echo "Error: SPR file '$spr_file' not found" >&2
        return 1
    fi
    
    echo "SPR Metrics for: $spr_file"
    echo "================================"
    
    # Extract metadata
    local original_words compressed_words ratio format
    original_words=$(grep "^# Original:" "$spr_file" | sed 's/^# Original: \([0-9]*\) words/\1/')
    compressed_words=$(grep "^# Compressed:" "$spr_file" | sed 's/^# Compressed: \([0-9]*\) words/\1/')
    ratio=$(grep "^# Ratio:" "$spr_file" | sed 's/^# Ratio: \([0-9.]*\).*/\1/')
    format=$(grep "^# Format:" "$spr_file" | sed 's/^# Format: //')
    
    echo "File size: $(wc -c < "$spr_file") bytes"
    echo "Original words: ${original_words:-unknown}"
    echo "Compressed words: ${compressed_words:-unknown}"
    echo "Compression ratio: ${ratio:-unknown}"
    echo "Format: ${format:-unknown}"
    
    # Statement analysis
    local statement_count
    statement_count=$(grep -cv "^#\|^$" "$spr_file")
    echo "Statement count: $statement_count"
    
    if [[ $statement_count -gt 0 ]]; then
        local avg_words min_words max_words
        avg_words=$(grep -v "^#\|^$" "$spr_file" | awk '{sum += NF; count++} END {print sum/count}')
        min_words=$(grep -v "^#\|^$" "$spr_file" | awk '{print NF}' | sort -n | head -1)
        max_words=$(grep -v "^#\|^$" "$spr_file" | awk '{print NF}' | sort -n | tail -1)
        
        echo "Average words per statement: $(printf "%.1f" "$avg_words")"
        echo "Words per statement range: $min_words - $max_words"
    fi
    
    echo "Generated: $(grep "^# Generated:" "$spr_file" | sed 's/^# Generated: //')"
}

# Main command dispatcher
main() {
    local command="${1:-}"
    
    case "$command" in
        compress|c)
            shift
            compress_file "$@"
            ;;
        decompress|d)
            shift  
            decompress_file "$@"
            ;;
        roundtrip|rt)
            shift
            roundtrip_test "$@"
            ;;
        batch|b)
            shift
            batch_process "$@"
            ;;
        validate|v)
            shift
            validate_spr "$@"
            ;;
        metrics|m)
            shift
            show_metrics "$@"
            ;;
        help|h|--help|-h)
            show_usage
            ;;
        *)
            echo "Error: Unknown command '$command'" >&2
            echo >&2
            show_usage >&2
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"