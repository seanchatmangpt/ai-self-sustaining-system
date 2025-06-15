#!/bin/bash

# Test SPR CLI system using Claude Code as Unix utility
# Demonstrates compression/decompression workflows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/spr_test_data"

# Create test directory and sample files
setup_test_data() {
    mkdir -p "$TEST_DIR"
    
    # Technical documentation sample
    cat > "$TEST_DIR/technical_doc.txt" << 'EOF'
The Reactor framework provides a comprehensive solution for building complex data processing pipelines in Elixir. It uses a step-based architecture that enables modular, testable, and maintainable workflows. Each step in a Reactor can perform data transformation, validation, or integration tasks. The framework supports both synchronous and asynchronous execution patterns, allowing for optimal performance in various scenarios.

Error handling is built into the core of Reactor through compensation mechanisms. When a step fails, the framework can automatically execute compensation logic to roll back changes or perform cleanup operations. This ensures data consistency and system reliability even in the face of failures.

Telemetry integration provides comprehensive observability throughout the pipeline execution. Each step is instrumented with timing metrics, success/failure tracking, and custom metadata collection. This enables detailed performance analysis and debugging capabilities for complex workflow scenarios.
EOF

    # Business process sample
    cat > "$TEST_DIR/business_doc.txt" << 'EOF'
Customer onboarding represents a critical touchpoint in the user journey that directly impacts retention and lifetime value. The current process involves multiple manual steps that create friction and delay time-to-value for new customers. Research indicates that customers who complete onboarding within the first 24 hours are 3x more likely to become long-term active users.

Our analysis reveals three primary pain points: account verification takes an average of 6 hours due to manual review processes, feature discovery is poor because of inadequate guided tutorials, and initial configuration requires technical knowledge that many users lack. These issues combine to create a suboptimal first impression that reduces conversion rates by approximately 25%.
EOF

    # Scientific content sample  
    cat > "$TEST_DIR/scientific_doc.txt" << 'EOF'
Machine learning models exhibit various forms of bias that can significantly impact their performance and fairness. Algorithmic bias typically emerges from three primary sources: biased training data that doesn't represent the target population adequately, biased feature selection that amplifies existing societal prejudices, and biased evaluation metrics that favor certain demographic groups.

Training data bias occurs when historical data contains systematic discrimination or underrepresentation. For example, hiring algorithms trained on historical HR data may perpetuate gender or racial bias present in past hiring decisions. Feature selection bias happens when relevant demographic information is used directly or indirectly through proxy variables, leading to discriminatory outcomes.
EOF
}

# Test individual compression
test_compression() {
    echo "=== Testing SPR Compression ==="
    echo
    
    for format in minimal standard extended; do
        echo "Testing $format compression on technical_doc.txt:"
        "$SCRIPT_DIR/spr_pipeline.sh" compress "$TEST_DIR/technical_doc.txt" "$format" 0.1 > "$TEST_DIR/technical_${format}.spr"
        
        # Show first few lines
        echo "Generated SPR ($format):"
        head -10 "$TEST_DIR/technical_${format}.spr"
        echo
    done
}

# Test decompression
test_decompression() {
    echo "=== Testing SPR Decompression ==="
    echo
    
    for expansion in brief detailed comprehensive; do
        echo "Testing $expansion expansion on technical_standard.spr:"
        "$SCRIPT_DIR/spr_pipeline.sh" decompress "$TEST_DIR/technical_standard.spr" "$expansion" auto > "$TEST_DIR/reconstructed_${expansion}.txt"
        
        # Show metrics
        local original_words spr_words reconstructed_words
        original_words=$(wc -w < "$TEST_DIR/technical_doc.txt")
        spr_words=$(grep -v "^#" "$TEST_DIR/technical_standard.spr" | wc -w)
        reconstructed_words=$(grep -v "^#" "$TEST_DIR/reconstructed_${expansion}.txt" | wc -w)
        
        echo "Expansion metrics ($expansion):"
        echo "  Original: $original_words words"
        echo "  SPR: $spr_words words"  
        echo "  Reconstructed: $reconstructed_words words"
        echo "  Expansion ratio: $(echo "scale=1; $reconstructed_words / $spr_words" | bc -l)x"
        echo
    done
}

# Test roundtrip quality
test_roundtrip() {
    echo "=== Testing Roundtrip Quality ==="
    echo
    
    echo "Roundtrip test: technical_doc.txt -> minimal SPR -> detailed expansion"
    "$SCRIPT_DIR/spr_pipeline.sh" roundtrip "$TEST_DIR/technical_doc.txt" minimal detailed > "$TEST_DIR/roundtrip_result.txt"
    echo
}

# Test batch processing
test_batch() {
    echo "=== Testing Batch Processing ==="
    echo
    
    "$SCRIPT_DIR/spr_pipeline.sh" batch "$TEST_DIR" standard 0.12
    echo
    
    echo "Batch results:"
    ls -la "$TEST_DIR/spr_output/"
    echo
}

# Test validation and metrics
test_validation() {
    echo "=== Testing Validation and Metrics ==="
    echo
    
    for spr_file in "$TEST_DIR"/spr_output/*.spr; do
        if [[ -f "$spr_file" ]]; then
            echo "Validating: $(basename "$spr_file")"
            "$SCRIPT_DIR/spr_pipeline.sh" validate "$spr_file"
            echo
            
            echo "Metrics for: $(basename "$spr_file")"
            "$SCRIPT_DIR/spr_pipeline.sh" metrics "$spr_file"
            echo "---"
            echo
        fi
    done
}

# Test Unix-style piping
test_unix_piping() {
    echo "=== Testing Unix-style Piping ==="
    echo
    
    echo "Piping content through SPR compression:"
    echo "The quick brown fox jumps over the lazy dog. This is a test of SPR compression using Unix pipes." | \
    "$SCRIPT_DIR/spr_compress.sh" /dev/stdin minimal 0.2 | \
    tee "$TEST_DIR/piped.spr"
    echo
    
    echo "Piping SPR through decompression:"
    cat "$TEST_DIR/piped.spr" | "$SCRIPT_DIR/spr_decompress.sh" /dev/stdin brief short
    echo
}

# Performance benchmark
benchmark_performance() {
    echo "=== Performance Benchmark ==="
    echo
    
    echo "Benchmarking compression performance:"
    for format in minimal standard extended; do
        echo -n "  $format: "
        time (
            "$SCRIPT_DIR/spr_pipeline.sh" compress "$TEST_DIR/technical_doc.txt" "$format" 0.1 > /dev/null
        ) 2>&1 | grep real | awk '{print $2}'
    done
    echo
    
    echo "Benchmarking decompression performance:"
    for expansion in brief detailed comprehensive; do
        echo -n "  $expansion: "
        time (
            "$SCRIPT_DIR/spr_pipeline.sh" decompress "$TEST_DIR/technical_standard.spr" "$expansion" auto > /dev/null
        ) 2>&1 | grep real | awk '{print $2}'
    done
    echo
}

# Show usage examples
show_examples() {
    echo "=== SPR CLI Usage Examples ==="
    echo
    cat << 'EOF'
# Basic compression
./spr_pipeline.sh compress document.txt standard 0.1

# Decompression with specific expansion
./spr_pipeline.sh decompress document.spr detailed medium

# Quality test (compress then decompress)
./spr_pipeline.sh roundtrip document.txt minimal comprehensive

# Batch process directory
./spr_pipeline.sh batch ./documents/ extended 0.15

# Validate SPR format
./spr_pipeline.sh validate document.spr

# Show compression statistics
./spr_pipeline.sh metrics document.spr

# Unix-style piping
echo "Text to compress" | ./spr_compress.sh /dev/stdin minimal 0.3

# Chain with other tools
find . -name "*.txt" -exec ./spr_pipeline.sh compress {} standard 0.1 \; | tee results.log
EOF
    echo
}

# Main test execution
main() {
    echo "SPR CLI Test Suite using Claude Code as Unix Utility"
    echo "===================================================="
    echo
    
    # Check Claude Code availability
    if ! command -v claude &> /dev/null; then
        echo "Warning: 'claude' command not found in PATH"
        echo "Set CLAUDE_CMD environment variable if using different executable"
        echo
    fi
    
    # Setup test environment
    echo "Setting up test data..."
    setup_test_data
    echo "Test data created in: $TEST_DIR"
    echo
    
    # Run all tests
    test_compression
    test_decompression  
    test_roundtrip
    test_batch
    test_validation
    test_unix_piping
    benchmark_performance
    show_examples
    
    echo "=== Test Suite Complete ==="
    echo "All SPR CLI functionality tested successfully!"
    echo
    echo "Test files available in: $TEST_DIR"
    echo "Try the examples above to explore SPR compression/decompression"
}

# Execute main function
main "$@"