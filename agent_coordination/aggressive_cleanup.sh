#!/bin/bash
# Aggressive cleanup for obviously stale coordination files
# Targets specific patterns that indicate accumulated analysis artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=${1:-false}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Files/patterns that are safe to remove (analysis artifacts)
REMOVABLE_PATTERNS=(
    "*_verification_verification_*.json"
    "completion_analysis_completion_*.json" 
    "system_state_analysis_decision_*.json"
    "honest_claims_*.json"
    "honest_metrics_*.json"
    "reality_corrections_*.json"
    "reality_comparison_*.json"
    "claude_work_recommendation_agent_*.json"
    "comprehensive_verification_report_verification_*.json"
    "health_verification_verification_*.json"
    "infrastructure_verification_verification_*.json"
    "performance_verification_verification_*.json"
    "actual_*_reality_*.json"
    "improved_claims_*.json"
    "baseline_iteration_*.json"
    "rebalancing_report_*.json"
    "real_work_creation_report_*.json"
    "honest_performance_report_*.json"
    "autonomous_verification_*.json"
)

# Backup files with timestamp patterns (keep only recent 5)
BACKUP_PATTERNS=(
    "coordination_helper.sh.backup.*"
    "agent_status_backup_*.json"
)

# Essential files that should NEVER be deleted
ESSENTIAL_FILES=(
    "agent_status.json"
    "work_claims.json"
    "coordination_log.json" 
    "telemetry_spans.jsonl"
    "coordination_helper.sh"
    "velocity_log.txt"
    "real_work_claims.json"
    "real_work_queue.json"
    "system_baseline_metrics.json"
    "corrected_metrics.json"
    "real_metrics.json"
    "optimization_metrics.json"
    "continuous_feedback_config.json"
)

is_essential() {
    local file="$1"
    local basename_file=$(basename "$file")
    
    for essential in "${ESSENTIAL_FILES[@]}"; do
        if [[ "$basename_file" == "$essential" ]]; then
            return 0
        fi
    done
    
    # Protect essential directories
    if [[ "$file" == *"/claude/"* ]] || [[ "$file" == *"/lib/"* ]]; then
        return 0
    fi
    
    return 1
}

cleanup_pattern_files() {
    log "Cleaning up analysis artifact files..."
    
    local total_removed=0
    local total_size=0
    
    for pattern in "${REMOVABLE_PATTERNS[@]}"; do
        local count=0
        local pattern_size=0
        
        while IFS= read -r file; do
            if [[ -f "$file" ]] && ! is_essential "$file"; then
                local file_size
                file_size=$(stat -f%z "$file" 2>/dev/null || echo 0)
                pattern_size=$((pattern_size + file_size))
                
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "Would delete: $(basename "$file")"
                else
                    rm -f "$file"
                    echo "Deleted: $(basename "$file")"
                fi
                count=$((count + 1))
            fi
        done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "$pattern" -type f)
        
        if [[ $count -gt 0 ]]; then
            log "Pattern '$pattern': removed $count files ($(($pattern_size / 1024))KB)"
            total_removed=$((total_removed + count))
            total_size=$((total_size + pattern_size))
        fi
    done
    
    if [[ $total_removed -gt 0 ]]; then
        success "Removed $total_removed analysis files, freed $(($total_size / 1024))KB"
    else
        log "No analysis artifact files found to remove"
    fi
}

cleanup_old_backups() {
    log "Cleaning old backup files (keeping 5 most recent per pattern)..."
    
    local total_removed=0
    
    for pattern in "${BACKUP_PATTERNS[@]}"; do
        # Get files matching pattern, sorted by modification time (newest first)
        local files=()
        while IFS= read -r file; do
            files+=("$file")
        done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "$pattern" -type f -exec ls -t {} +)
        
        if [[ ${#files[@]} -gt 5 ]]; then
            log "Found ${#files[@]} files matching '$pattern', keeping 5 most recent"
            
            # Remove all but the 5 most recent
            for ((i=5; i<${#files[@]}; i++)); do
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "Would delete: $(basename "${files[i]}")"
                else
                    rm -f "${files[i]}"
                    echo "Deleted: $(basename "${files[i]}")"
                fi
                total_removed=$((total_removed + 1))
            done
        fi
    done
    
    if [[ $total_removed -gt 0 ]]; then
        success "Removed $total_removed old backup files"
    else
        log "No old backup files to remove"
    fi
}

cleanup_empty_locks() {
    log "Cleaning up empty lock files..."
    
    local count=0
    while IFS= read -r -d '' file; do
        if [[ -f "$file" && ! -s "$file" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "Would delete empty lock: $(basename "$file")"
            else
                rm -f "$file"
                echo "Deleted empty lock: $(basename "$file")"
            fi
            count=$((count + 1))
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "*.lock" -type f -print0)
    
    if [[ $count -gt 0 ]]; then
        success "Removed $count empty lock files"
    else
        log "No empty lock files found"
    fi
}

cleanup_old_work_results() {
    log "Cleaning work results older than 3 days..."
    
    local results_dir="$SCRIPT_DIR/real_work_results"
    if [[ ! -d "$results_dir" ]]; then
        log "No work results directory found"
        return
    fi
    
    local count=0
    local size_freed=0
    
    # Find files older than 3 days
    while IFS= read -r -d '' file; do
        local file_size
        file_size=$(stat -f%z "$file" 2>/dev/null || echo 0)
        size_freed=$((size_freed + file_size))
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "Would delete work result: $(basename "$file")"
        else
            rm -f "$file"
            echo "Deleted: $(basename "$file")"
        fi
        count=$((count + 1))
    done < <(find "$results_dir" -name "*.result" -type f -mtime +3 -print0)
    
    if [[ $count -gt 0 ]]; then
        success "Removed $count work result files, freed $(($size_freed / 1024))KB"
    else
        log "No old work results to clean"
    fi
}

show_before_after() {
    echo "=================================="
    echo "BEFORE/AFTER COMPARISON"
    echo "=================================="
    
    local total_files
    total_files=$(find "$SCRIPT_DIR" -maxdepth 1 -type f | wc -l)
    echo "Current files in agent_coordination/: $total_files"
    
    if [[ -d "$SCRIPT_DIR/real_work_results" ]]; then
        local result_files
        result_files=$(find "$SCRIPT_DIR/real_work_results" -name "*.result" -type f | wc -l)
        echo "Work result files: $result_files"
    fi
    
    if [[ -d "$SCRIPT_DIR/backups" ]]; then
        local backup_files
        backup_files=$(find "$SCRIPT_DIR/backups" -name "*.json" -type f | wc -l)
        echo "Backup files: $backup_files"
    fi
    
    # Count files matching removable patterns
    local pattern_count=0
    for pattern in "${REMOVABLE_PATTERNS[@]}"; do
        local matches
        matches=$(find "$SCRIPT_DIR" -maxdepth 1 -name "$pattern" -type f | wc -l)
        pattern_count=$((pattern_count + matches))
    done
    echo "Analysis artifact files: $pattern_count"
    
    echo "=================================="
}

main() {
    echo "=================================="
    echo "AGGRESSIVE COORDINATION CLEANUP"
    echo "Removes analysis artifacts and old results"
    echo "=================================="
    
    cd "$SCRIPT_DIR"
    
    show_before_after
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "DRY RUN MODE - No files will be deleted"
        echo
    else
        echo
        read -p "This will aggressively clean analysis artifacts. Proceed? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Cleanup cancelled by user"
            exit 0
        fi
    fi
    
    # Run cleanup operations
    cleanup_pattern_files
    cleanup_old_backups
    cleanup_empty_locks
    cleanup_old_work_results
    
    echo
    success "Aggressive cleanup completed!"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo
        log "After cleanup:"
        show_before_after
    fi
}

# Usage
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [dry-run]"
    echo ""
    echo "Aggressively removes:"
    echo "  - Analysis artifact files (verification reports, completions, etc.)"
    echo "  - Old backup files (keeps 5 most recent per type)"
    echo "  - Empty lock files"
    echo "  - Work results older than 3 days"
    echo ""
    echo "Preserves essential coordination files and recent operational data."
    exit 0
fi

main "$@"