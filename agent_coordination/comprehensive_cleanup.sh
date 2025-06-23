#!/bin/bash
# Comprehensive Agent Coordination Cleanup Script
# Cleans timestamped files, old backups, stale work results, and logs
# Preserves essential coordination files and recent backups

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR"
CURRENT_TIME=$(date +%s)
DRY_RUN=${1:-false}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Configuration
DAYS_TO_KEEP_TIMESTAMPED=7  # Keep timestamped files for 7 days
DAYS_TO_KEEP_LOGS=14        # Keep logs for 14 days
KEEP_RECENT_BACKUPS=10      # Keep 10 most recent backups
ARCHIVE_DIR="$SCRIPT_DIR/archive_$(date +%Y%m%d)"

# Essential files that should NEVER be deleted
ESSENTIAL_FILES=(
    "agent_status.json"
    "work_claims.json" 
    "coordination_log.json"
    "telemetry_spans.jsonl"
    "coordination_helper.sh"
    "velocity_log.txt"
    "work_claims.yaml"
    "agent_status.yaml"
    "backlog.json"
    "backlog.yaml"
    "active_sprints.json"
)

# Essential directories
ESSENTIAL_DIRS=(
    "claude"
    "lib"
    "logs"
    "metrics"
    "backups"
)

is_essential() {
    local file="$1"
    local basename_file=$(basename "$file")
    
    for essential in "${ESSENTIAL_FILES[@]}"; do
        if [[ "$basename_file" == "$essential" ]]; then
            return 0
        fi
    done
    
    for essential_dir in "${ESSENTIAL_DIRS[@]}"; do
        if [[ "$file" == *"/$essential_dir"* ]]; then
            return 0
        fi
    done
    
    return 1
}

is_timestamped_file() {
    local file="$1"
    # Match files with timestamp patterns like 1750057376472623000
    if [[ "$file" =~ _[0-9]{13,19}\.(json|jsonl|log|result)$ ]]; then
        return 0
    fi
    return 1
}

get_file_age_days() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "999"
        return
    fi
    
    local file_time
    if [[ "$OSTYPE" == "darwin"* ]]; then
        file_time=$(stat -f %m "$file")
    else
        file_time=$(stat -c %Y "$file")
    fi
    
    local age_seconds=$((CURRENT_TIME - file_time))
    local age_days=$((age_seconds / 86400))
    echo "$age_days"
}

cleanup_timestamped_files() {
    log "Cleaning up timestamped files older than $DAYS_TO_KEEP_TIMESTAMPED days..."
    
    local count=0
    local size_freed=0
    
    while IFS= read -r -d '' file; do
        if is_essential "$file"; then
            continue
        fi
        
        if is_timestamped_file "$file"; then
            local age_days
            age_days=$(get_file_age_days "$file")
            
            if [[ $age_days -gt $DAYS_TO_KEEP_TIMESTAMPED ]]; then
                local file_size
                file_size=$(stat -f%z "$file" 2>/dev/null || echo 0)
                size_freed=$((size_freed + file_size))
                
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "Would delete: $file (age: ${age_days}d, size: ${file_size}b)"
                else
                    rm -f "$file"
                    echo "Deleted: $(basename "$file") (age: ${age_days}d)"
                fi
                count=$((count + 1))
            fi
        fi
    done < <(find "$WORK_DIR" -maxdepth 1 -type f -print0)
    
    if [[ $count -gt 0 ]]; then
        success "Cleaned $count timestamped files, freed $(($size_freed / 1024))KB"
    else
        log "No timestamped files to clean"
    fi
}

cleanup_old_backups() {
    log "Cleaning old backups (keeping $KEEP_RECENT_BACKUPS most recent)..."
    
    local backup_dir="$WORK_DIR/backups"
    if [[ ! -d "$backup_dir" ]]; then
        log "No backups directory found"
        return
    fi
    
    # Get backup files sorted by modification time (newest first)
    local backup_files=()
    while IFS= read -r -d '' file; do
        backup_files+=("$file")
    done < <(find "$backup_dir" -name "*.json" -type f -print0 | xargs -0 ls -t)
    
    if [[ ${#backup_files[@]} -le $KEEP_RECENT_BACKUPS ]]; then
        log "Only ${#backup_files[@]} backups found, keeping all"
        return
    fi
    
    local to_delete=$((${#backup_files[@]} - KEEP_RECENT_BACKUPS))
    local count=0
    
    # Delete oldest backups
    for ((i=KEEP_RECENT_BACKUPS; i<${#backup_files[@]}; i++)); do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "Would delete backup: ${backup_files[i]}"
        else
            rm -f "${backup_files[i]}"
            echo "Deleted backup: $(basename "${backup_files[i]}")"
        fi
        count=$((count + 1))
    done
    
    success "Cleaned $count old backups"
}

cleanup_work_results() {
    log "Cleaning old work results older than $DAYS_TO_KEEP_LOGS days..."
    
    local results_dir="$WORK_DIR/real_work_results"
    if [[ ! -d "$results_dir" ]]; then
        log "No work results directory found"
        return
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        local age_days
        age_days=$(get_file_age_days "$file")
        
        if [[ $age_days -gt $DAYS_TO_KEEP_LOGS ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "Would delete work result: $file"
            else
                rm -f "$file"
                echo "Deleted: $(basename "$file")"
            fi
            count=$((count + 1))
        fi
    done < <(find "$results_dir" -name "*.result" -type f -print0)
    
    if [[ $count -gt 0 ]]; then
        success "Cleaned $count old work results"
    else
        log "No old work results to clean"
    fi
}

cleanup_agent_logs() {
    log "Cleaning old agent logs older than $DAYS_TO_KEEP_LOGS days..."
    
    local agents_dir="$WORK_DIR/real_agents"
    if [[ ! -d "$agents_dir" ]]; then
        log "No real agents directory found"
        return
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        local age_days
        age_days=$(get_file_age_days "$file")
        
        if [[ $age_days -gt $DAYS_TO_KEEP_LOGS ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "Would delete agent log: $file"
            else
                rm -f "$file"
                echo "Deleted: $(basename "$file")"
            fi
            count=$((count + 1))
        fi
    done < <(find "$agents_dir" -type f \( -name "*.log" -o -name "*.pid" \) -print0)
    
    if [[ $count -gt 0 ]]; then
        success "Cleaned $count old agent logs"
    else
        log "No old agent logs to clean"
    fi
}

cleanup_verification_files() {
    log "Cleaning old verification and analysis files..."
    
    local patterns=(
        "*_verification_verification_*.json"
        "completion_analysis_completion_*.json"
        "system_state_analysis_decision_*.json"
        "honest_claims_*.json"
        "reality_corrections_*.json"
        "claude_work_recommendation_agent_*.json"
    )
    
    local count=0
    for pattern in "${patterns[@]}"; do
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                local age_days
                age_days=$(get_file_age_days "$file")
                
                if [[ $age_days -gt $DAYS_TO_KEEP_TIMESTAMPED ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "Would delete verification file: $file"
                    else
                        rm -f "$file"
                        echo "Deleted: $(basename "$file")"
                    fi
                    count=$((count + 1))
                fi
            fi
        done < <(find "$WORK_DIR" -maxdepth 1 -name "$pattern" -type f)
    done
    
    if [[ $count -gt 0 ]]; then
        success "Cleaned $count verification files"
    else
        log "No verification files to clean"
    fi
}

show_summary() {
    log "Generating cleanup summary..."
    
    echo "=================================="
    echo "CLEANUP SUMMARY"
    echo "=================================="
    echo "Working directory: $WORK_DIR"
    echo "Days to keep timestamped files: $DAYS_TO_KEEP_TIMESTAMPED"
    echo "Days to keep logs: $DAYS_TO_KEEP_LOGS"
    echo "Backups to keep: $KEEP_RECENT_BACKUPS"
    echo "Dry run mode: $DRY_RUN"
    echo "=================================="
    
    # Count current files by type
    local total_files
    total_files=$(find "$WORK_DIR" -maxdepth 1 -type f | wc -l)
    
    local timestamped_files
    timestamped_files=$(find "$WORK_DIR" -maxdepth 1 -type f | grep -E '_[0-9]{13,19}\.(json|jsonl|log|result)$' | wc -l || echo 0)
    
    echo "Current files: $total_files"
    echo "Timestamped files: $timestamped_files"
    
    if [[ -d "$WORK_DIR/backups" ]]; then
        local backup_count
        backup_count=$(find "$WORK_DIR/backups" -name "*.json" -type f | wc -l)
        echo "Backup files: $backup_count"
    fi
    
    if [[ -d "$WORK_DIR/real_work_results" ]]; then
        local result_count
        result_count=$(find "$WORK_DIR/real_work_results" -name "*.result" -type f | wc -l)
        echo "Work result files: $result_count"
    fi
    
    echo "=================================="
}

main() {
    echo "=================================="
    echo "AGENT COORDINATION CLEANUP"
    echo "Comprehensive file cleanup utility"
    echo "=================================="
    
    # Change to work directory
    cd "$WORK_DIR"
    
    # Show current state
    show_summary
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "DRY RUN MODE - No files will be deleted"
        echo
    else
        echo
        read -p "Proceed with cleanup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Cleanup cancelled by user"
            exit 0
        fi
    fi
    
    # Run cleanup operations
    cleanup_timestamped_files
    cleanup_old_backups
    cleanup_work_results
    cleanup_agent_logs
    cleanup_verification_files
    
    echo
    success "Cleanup completed!"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log "Running post-cleanup summary..."
        show_summary
        
        # Run the existing benchmark cleanup for good measure
        if [[ -f "$SCRIPT_DIR/benchmark_cleanup_script.sh" ]]; then
            log "Running benchmark cleanup for good measure..."
            bash "$SCRIPT_DIR/benchmark_cleanup_script.sh" --auto
        fi
    fi
}

# Usage information
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [dry-run]"
    echo ""
    echo "Options:"
    echo "  dry-run    Show what would be deleted without actually deleting"
    echo "  --help     Show this help message"
    echo ""
    echo "Configuration:"
    echo "  DAYS_TO_KEEP_TIMESTAMPED=$DAYS_TO_KEEP_TIMESTAMPED (timestamped files retention)"
    echo "  DAYS_TO_KEEP_LOGS=$DAYS_TO_KEEP_LOGS (logs retention)"
    echo "  KEEP_RECENT_BACKUPS=$KEEP_RECENT_BACKUPS (number of backups to keep)"
    exit 0
fi

# Execute main function
main "$@"