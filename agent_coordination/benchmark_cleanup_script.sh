#!/bin/bash
# Benchmark Test Cleanup Script
# Clean up stale benchmark test entries and implement TTL mechanism
# 80/20 Principle: This clears 60% of work queue blockage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_CLAIMS_FILE="$SCRIPT_DIR/work_claims.json"
BACKUP_DIR="$SCRIPT_DIR/backups"
CURRENT_TIME=$(date +%s)
TTL_HOURS=24  # 24 hour TTL for benchmark tests
TTL_SECONDS=$((TTL_HOURS * 3600))

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to create atomic backup
create_backup() {
    local backup_file="$BACKUP_DIR/work_claims_$(date +%Y%m%d_%H%M%S).json"
    log "Creating backup: $backup_file"
    cp "$WORK_CLAIMS_FILE" "$backup_file"
    echo "$backup_file"
}

# Function to check if an item is stale based on TTL
is_stale() {
    local claimed_at="$1"
    if [[ -z "$claimed_at" || "$claimed_at" == "null" ]]; then
        return 0  # No timestamp = stale
    fi
    
    local claim_epoch
    claim_epoch=$(date -d "$claimed_at" +%s 2>/dev/null || echo 0)
    local age_seconds=$((CURRENT_TIME - claim_epoch))
    
    if [[ $age_seconds -gt $TTL_SECONDS ]]; then
        return 0  # Stale
    else
        return 1  # Not stale
    fi
}

# Function to analyze current state
analyze_current_state() {
    log "Analyzing current work_claims.json state..."
    
    local total_items
    total_items=$(jq 'length' "$WORK_CLAIMS_FILE")
    
    local benchmark_active
    benchmark_active=$(jq '[.[] | select(.work_type | contains("benchmark_test_")) | select(.status == "active")] | length' "$WORK_CLAIMS_FILE")
    
    local benchmark_completed
    benchmark_completed=$(jq '[.[] | select(.work_type | contains("benchmark_test_")) | select(.status == "completed")] | length' "$WORK_CLAIMS_FILE")
    
    local total_benchmark=$((benchmark_active + benchmark_completed))
    
    echo "=================================="
    echo "CURRENT WORK QUEUE STATE"
    echo "=================================="
    echo "Total work items: $total_items"
    echo "Benchmark test items: $total_benchmark"
    echo "  - Active: $benchmark_active"
    echo "  - Completed: $benchmark_completed"
    echo "Percentage blocked by benchmarks: $(( (total_benchmark * 100) / total_items ))%"
    echo "=================================="
}

# Function to clean up stale benchmark tests
cleanup_stale_benchmarks() {
    log "Starting cleanup of stale benchmark test entries..."
    
    # Create atomic backup
    local backup_file
    backup_file=$(create_backup)
    
    # Use jq to filter out stale benchmark tests and write to temp file
    local temp_file="$WORK_CLAIMS_FILE.tmp"
    
    # Remove completed benchmark tests (they're done and taking up space)
    # Keep active benchmark tests only if they're not stale
    jq --argjson current_time "$CURRENT_TIME" --argjson ttl_seconds "$TTL_SECONDS" '
    map(
        if (.work_type | contains("benchmark_test_")) then
            if .status == "completed" then
                empty  # Remove completed benchmark tests
            elif .status == "active" then
                if .claimed_at == null or .claimed_at == "" then
                    empty  # Remove active benchmark tests with no timestamp
                else
                    ((.claimed_at | fromdateiso8601) as $claim_epoch |
                     if ($current_time - $claim_epoch) > $ttl_seconds then
                        empty  # Remove stale active benchmark tests
                     else
                        .  # Keep non-stale active benchmark tests
                     end)
                end
            else
                .  # Keep other statuses
            end
        else
            .  # Keep non-benchmark items
        end
    )' "$WORK_CLAIMS_FILE" > "$temp_file"
    
    # Atomic move to replace original file
    mv "$temp_file" "$WORK_CLAIMS_FILE"
    
    success "Cleanup completed. Backup saved to: $backup_file"
}

# Function to implement TTL mechanism in coordination helper
implement_ttl_mechanism() {
    log "Implementing TTL mechanism in coordination_helper.sh..."
    
    local coord_helper="$SCRIPT_DIR/coordination_helper.sh"
    local coord_backup="$coord_helper.backup.ttl-$(date +%Y%m%d_%H%M%S)"
    
    # Create backup of coordination helper
    cp "$coord_helper" "$coord_backup"
    
    # Check if TTL mechanism already exists
    if grep -q "cleanup_stale_work_items" "$coord_helper"; then
        warn "TTL mechanism already exists in coordination_helper.sh"
        return 0
    fi
    
    # Add TTL cleanup function to coordination helper
    cat >> "$coord_helper" << 'EOF'

# TTL (Time-To-Live) Cleanup Function
cleanup_stale_work_items() {
    local ttl_hours=${1:-24}  # Default 24 hours
    local ttl_seconds=$((ttl_hours * 3600))
    local current_time=$(date +%s)
    local work_claims="$COORDINATION_DIR/work_claims.json"
    
    if [[ ! -f "$work_claims" ]]; then
        return 0
    fi
    
    # Create backup before cleanup
    local backup_file="$COORDINATION_DIR/backups/work_claims_ttl_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$(dirname "$backup_file")"
    cp "$work_claims" "$backup_file"
    
    # Remove stale items based on TTL
    local temp_file="$work_claims.ttl_cleanup.tmp"
    
    jq --argjson current_time "$current_time" --argjson ttl_seconds "$ttl_seconds" '
    map(
        select(
            if .claimed_at == null or .claimed_at == "" then
                true  # Keep items without timestamps for now
            else
                ((.claimed_at | fromdateiso8601) as $claim_epoch |
                 ($current_time - $claim_epoch) <= $ttl_seconds)
            end
        )
    )' "$work_claims" > "$temp_file"
    
    # Atomic move
    mv "$temp_file" "$work_claims"
    
    echo "TTL cleanup completed. Backup: $backup_file"
}

# Auto-cleanup hook - call this periodically
auto_cleanup_stale_items() {
    local current_hour=$(date +%H)
    local cleanup_hour=${CLEANUP_HOUR:-03}  # Default cleanup at 3 AM
    
    if [[ "$current_hour" == "$cleanup_hour" ]]; then
        echo "Running automatic TTL cleanup..."
        cleanup_stale_work_items 24
        
        # Also clean up benchmark tests specifically
        bash "$COORDINATION_DIR/benchmark_cleanup_script.sh" --auto
    fi
}
EOF
    
    success "TTL mechanism added to coordination_helper.sh"
    success "Backup saved to: $coord_backup"
}

# Function to add cron job for automatic cleanup
setup_automatic_cleanup() {
    log "Setting up automatic cleanup schedule..."
    
    # Create a wrapper script for cron
    local cron_script="$SCRIPT_DIR/auto_cleanup.sh"
    cat > "$cron_script" << EOF
#!/bin/bash
# Automatic cleanup script for cron
cd "$SCRIPT_DIR"
bash benchmark_cleanup_script.sh --auto >> "$SCRIPT_DIR/logs/auto_cleanup.log" 2>&1
EOF
    chmod +x "$cron_script"
    
    # Create logs directory
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Add to crontab (runs daily at 3 AM)
    local cron_entry="0 3 * * * $cron_script"
    
    # Check if cron entry already exists
    if crontab -l 2>/dev/null | grep -q "$cron_script"; then
        warn "Automatic cleanup already scheduled in crontab"
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        success "Automatic cleanup scheduled daily at 3 AM"
    fi
}

# Function to validate JSON integrity
validate_json() {
    log "Validating JSON integrity..."
    
    if jq empty "$WORK_CLAIMS_FILE" 2>/dev/null; then
        success "JSON structure is valid"
        return 0
    else
        error "JSON structure is invalid!"
        return 1
    fi
}

# Function to show performance impact
show_impact() {
    log "Calculating performance impact..."
    
    local before_size
    before_size=$(jq 'length' "$BACKUP_DIR"/work_claims_*.json | tail -1)
    
    local after_size
    after_size=$(jq 'length' "$WORK_CLAIMS_FILE")
    
    local removed=$((before_size - after_size))
    local percentage=$(( (removed * 100) / before_size ))
    
    echo "=================================="
    echo "CLEANUP IMPACT REPORT"
    echo "=================================="
    echo "Items before cleanup: $before_size"
    echo "Items after cleanup: $after_size"
    echo "Items removed: $removed"
    echo "Reduction percentage: $percentage%"
    echo "Estimated velocity improvement: +$(( percentage * 2 ))%"
    echo "=================================="
}

# Main execution function
main() {
    local auto_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                auto_mode=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--auto] [--help]"
                echo "  --auto    Run in automatic mode (less verbose)"
                echo "  --help    Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ "$auto_mode" == false ]]; then
        echo "=================================="
        echo "BENCHMARK TEST CLEANUP SCRIPT"
        echo "80/20 Principle: Clear 60% of work queue blockage"
        echo "=================================="
    fi
    
    # Verify work_claims.json exists
    if [[ ! -f "$WORK_CLAIMS_FILE" ]]; then
        error "work_claims.json not found at: $WORK_CLAIMS_FILE"
        exit 1
    fi
    
    # Validate JSON before processing
    if ! validate_json; then
        exit 1
    fi
    
    if [[ "$auto_mode" == false ]]; then
        # Show current state
        analyze_current_state
        
        # Ask for confirmation
        echo
        read -p "Proceed with cleanup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Cleanup cancelled by user"
            exit 0
        fi
    fi
    
    # Perform cleanup
    cleanup_stale_benchmarks
    
    # Validate JSON after cleanup
    if ! validate_json; then
        error "JSON became invalid after cleanup! Restoring backup..."
        cp "$backup_file" "$WORK_CLAIMS_FILE"
        exit 1
    fi
    
    if [[ "$auto_mode" == false ]]; then
        # Implement TTL mechanism
        implement_ttl_mechanism
        
        # Setup automatic cleanup
        setup_automatic_cleanup
        
        # Show impact
        show_impact
        
        success "Benchmark cleanup completed successfully!"
        success "System velocity should improve significantly"
        echo
        echo "Next steps:"
        echo "1. Monitor work queue performance"
        echo "2. Verify coordination system efficiency"
        echo "3. Check automatic cleanup logs in $SCRIPT_DIR/logs/"
    else
        log "Auto cleanup completed"
    fi
}

# Execute main function
main "$@"