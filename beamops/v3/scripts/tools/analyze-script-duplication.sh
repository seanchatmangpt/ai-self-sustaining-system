#!/bin/bash
# Analyze Script Duplication in AI Self-Sustaining System
# Identifies duplicated scripts across worktrees and provides consolidation recommendations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

echo "🔍 Analyzing Script Duplication in AI Self-Sustaining System"
echo "📁 System Root: ${SYSTEM_ROOT}"

# Function to analyze script duplication
analyze_duplication() {
    echo ""
    echo "📊 Script Duplication Analysis"
    echo "=============================="
    
    # Count total scripts
    local total_scripts=$(find "${SYSTEM_ROOT}" -name "*.sh" -type f | wc -l)
    echo "📋 Total shell scripts found: ${total_scripts}"
    
    # Find duplicated scripts by content hash
    echo ""
    echo "🔍 Finding duplicated scripts by content..."
    local temp_file="/tmp/script_analysis_$$"
    
    find "${SYSTEM_ROOT}" -name "*.sh" -type f -exec md5sum {} \; | sort > "${temp_file}"
    
    # Count unique scripts
    local unique_scripts=$(cut -d' ' -f1 "${temp_file}" | sort -u | wc -l)
    echo "📋 Unique scripts (by content): ${unique_scripts}"
    
    # Calculate duplication ratio
    local duplication_ratio=$((total_scripts - unique_scripts))
    local duplication_percent=$(( (duplication_ratio * 100) / total_scripts ))
    
    echo "📋 Duplicated scripts: ${duplication_ratio}"
    echo "📋 Duplication percentage: ${duplication_percent}%"
    
    # Show most duplicated scripts
    echo ""
    echo "🎯 Most Duplicated Scripts:"
    echo "=========================="
    
    cut -d' ' -f1 "${temp_file}" | uniq -c | sort -nr | head -10 | while read count hash; do
        if [ "$count" -gt 1 ]; then
            local example_file=$(grep "^${hash}" "${temp_file}" | head -1 | cut -d' ' -f2-)
            local script_name=$(basename "${example_file}")
            echo "   ${count}x duplicates: ${script_name}"
            
            # Show all locations
            grep "^${hash}" "${temp_file}" | cut -d' ' -f2- | sed 's|'"${SYSTEM_ROOT}"'/||' | while read location; do
                echo "      - ${location}"
            done
            echo ""
        fi
    done
    
    rm -f "${temp_file}"
}

# Function to analyze worktree script distribution
analyze_worktree_distribution() {
    echo ""
    echo "🌳 Worktree Script Distribution"
    echo "==============================="
    
    # Count scripts in main directory
    local main_scripts=$(find "${SYSTEM_ROOT}/agent_coordination" -name "*.sh" -type f 2>/dev/null | wc -l)
    echo "📋 Main coordination scripts: ${main_scripts}"
    
    # Count scripts in worktrees
    if [ -d "${SYSTEM_ROOT}/worktrees" ]; then
        local worktree_scripts=$(find "${SYSTEM_ROOT}/worktrees" -name "*.sh" -type f 2>/dev/null | wc -l)
        echo "📋 Worktree scripts: ${worktree_scripts}"
        
        # Show per-worktree breakdown
        echo ""
        echo "📂 Per-Worktree Breakdown:"
        find "${SYSTEM_ROOT}/worktrees" -maxdepth 1 -type d | grep -v "^${SYSTEM_ROOT}/worktrees$" | while read worktree; do
            local wt_name=$(basename "${worktree}")
            local wt_scripts=$(find "${worktree}" -name "*.sh" -type f 2>/dev/null | wc -l)
            echo "   ${wt_name}: ${wt_scripts} scripts"
        done
    else
        echo "📋 No worktrees directory found"
    fi
}

# Function to identify consolidation opportunities
identify_consolidation_opportunities() {
    echo ""
    echo "🎯 Consolidation Opportunities"
    echo "=============================="
    
    echo ""
    echo "💡 Recommendations:"
    echo "1. Keep original scripts in main agent_coordination/ directory"
    echo "2. Replace worktree copies with smart wrapper scripts"
    echo "3. Use symlinks for configuration files"
    echo "4. Implement central script management system"
    
    echo ""
    echo "📋 Proposed consolidation strategy:"
    echo "   - Main scripts: ${SYSTEM_ROOT}/agent_coordination/"
    echo "   - Worktree wrappers: smart scripts that call main versions"
    echo "   - Configuration: environment-specific configs only"
    echo "   - Expected reduction: ~70% fewer files to maintain"
}

# Function to generate consolidation script
generate_consolidation_script() {
    local output_script="${SCRIPT_DIR}/eliminate-duplication.sh"
    
    echo ""
    echo "📝 Generating consolidation script: ${output_script}"
    
    cat > "${output_script}" << 'EOF'
#!/bin/bash
# Auto-generated Script Duplication Elimination
# Consolidates duplicated scripts while preserving functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

echo "🔧 Eliminating Script Duplication"
echo "================================="

# Function to create smart wrapper script
create_wrapper() {
    local worktree_script="$1"
    local main_script="$2"
    local wrapper_content
    
    # Create wrapper that calls main script with proper environment
    wrapper_content=$(cat << 'WRAPPER_EOF'
#!/bin/bash
# Auto-generated wrapper script
# Calls main script with worktree-specific environment

WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$(cd "${WRAPPER_DIR}" && find ../../.. -path "*/agent_coordination/*.sh" -name "$(basename "${BASH_SOURCE[0]}")" | head -1)"

if [ -z "$MAIN_SCRIPT" ] || [ ! -f "$MAIN_SCRIPT" ]; then
    echo "ERROR: Main script not found for $(basename "${BASH_SOURCE[0]}")"
    exit 1
fi

# Set worktree-specific environment
export WORKTREE_PATH="$WRAPPER_DIR"
export COORDINATION_DIR="$(dirname "$WRAPPER_DIR")"

# Execute main script with all arguments
exec "$MAIN_SCRIPT" "$@"
WRAPPER_EOF
)
    
    echo "$wrapper_content" > "$worktree_script"
    chmod +x "$worktree_script"
}

# Main consolidation logic
main() {
    echo "🔍 Finding duplicated scripts..."
    
    # This would be populated with actual consolidation logic
    echo "⚠️  This is a template - implement actual consolidation logic based on analysis"
    echo "📋 Strategy: Keep main scripts, create wrappers for worktree copies"
    echo "📋 Manual review required before execution"
}

main "$@"
EOF
    
    chmod +x "${output_script}"
    echo "✅ Consolidation script created (requires manual implementation)"
}

# Main execution
main() {
    analyze_duplication
    analyze_worktree_distribution
    identify_consolidation_opportunities
    generate_consolidation_script
    
    echo ""
    echo "✅ Script duplication analysis complete"
    echo ""
    echo "📋 Summary:"
    echo "   - Comprehensive duplication analysis performed"
    echo "   - Worktree distribution analyzed"
    echo "   - Consolidation recommendations provided"
    echo "   - Template consolidation script generated"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Review analysis results above"
    echo "   2. Implement consolidation logic in eliminate-duplication.sh"
    echo "   3. Test consolidation in isolated environment"
    echo "   4. Execute consolidation with backup"
}

# Error handling
trap 'echo "❌ Script analysis failed"; exit 1' ERR

# Execute analysis
main "$@"