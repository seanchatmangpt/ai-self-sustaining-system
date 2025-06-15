#!/bin/bash

# Comprehensive OpenTelemetry and System Monitoring Summary
# Usage: ./telemetry_summary.sh [time_window] [output_formats] [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHOENIX_APP_DIR="$SCRIPT_DIR/phoenix_app"

# Default configuration
DEFAULT_TIME_WINDOW=300  # 5 minutes
DEFAULT_OUTPUTS="console,json"
CONTINUOUS_MODE=false
ALERTS_ONLY=false
MIN_HEALTH_THRESHOLD=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_usage() {
    cat << EOF
📊 Telemetry Summary - Comprehensive OpenTelemetry and System Monitoring

USAGE:
    $0 [time_window] [output_formats] [options]

PARAMETERS:
    time_window     Time window in seconds for analysis (default: 300)
    output_formats  Comma-separated formats: console,json,dashboard,markdown,file,all (default: console,json)

OPTIONS:
    --continuous, -c       Run continuously every time_window seconds
    --alerts-only, -a      Only show output when alerts are present
    --min-health N, -h N   Only show output when health score below N
    --quiet, -q           Suppress startup messages
    --help                Show this help message

OUTPUT FORMATS:
    console     Rich console output with colors and formatting
    json        Structured JSON report for integration
    dashboard   Dashboard-compatible data format
    markdown    Markdown report for documentation
    file        Save all formats to files
    all         Generate all available formats

EXAMPLES:
    $0                           # Basic 5-minute summary
    $0 600 console,json          # 10-minute summary, console + JSON
    $0 300 all                   # 5-minute summary, all formats
    $0 --continuous              # Continuous monitoring every 5 minutes
    $0 180 dashboard -c          # Continuous 3-minute dashboard updates
    $0 300 console --alerts-only # Only show when alerts present
    $0 600 all -h 80             # Only show when health below 80

INTEGRATION:
    - Uses actual Reactor workflows with full telemetry integration
    - Nanosecond-precision agent coordination tracking
    - OpenTelemetry distributed tracing analysis
    - SPR operation performance monitoring
    - System resource and health assessment
    - Historical trend analysis and predictive insights

REACTOR PIPELINE:
    1. 📡 Collect OpenTelemetry spans and system metrics
    2. 🔗 Analyze agent coordination performance
    3. 🗜️  Process SPR operation statistics
    4. 🏥 Generate comprehensive health summary
    5. 📈 Analyze performance trends and patterns
    6. 💡 Generate actionable insights and recommendations
    7. 📊 Create formatted reports for multiple outputs
    8. 💾 Store historical data for trend analysis
    9. 📤 Distribute summary to configured endpoints

MONITORING DATA:
    - OpenTelemetry span analysis
    - Agent coordination metrics (conflicts, efficiency, throughput)
    - SPR compression/decompression performance
    - System resources (memory, CPU, processes)
    - Error rates and success patterns
    - Historical trends and projections
EOF
}

# Parse command line arguments
parse_arguments() {
    local time_window=""
    local output_formats=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --continuous|-c)
                CONTINUOUS_MODE=true
                shift
                ;;
            --alerts-only|-a)
                ALERTS_ONLY=true
                shift
                ;;
            --min-health|-h)
                MIN_HEALTH_THRESHOLD="$2"
                shift 2
                ;;
            --quiet|-q)
                QUIET_MODE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                show_usage >&2
                exit 1
                ;;
            *)
                if [[ -z "$time_window" ]]; then
                    time_window="$1"
                elif [[ -z "$output_formats" ]]; then
                    output_formats="$1"
                else
                    echo "Too many arguments: $1" >&2
                    show_usage >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Set defaults
    TIME_WINDOW="${time_window:-$DEFAULT_TIME_WINDOW}"
    OUTPUT_FORMATS="${output_formats:-$DEFAULT_OUTPUTS}"
}

# Validate configuration
validate_configuration() {
    # Validate time window
    if ! [[ "$TIME_WINDOW" =~ ^[0-9]+$ ]] || [[ "$TIME_WINDOW" -lt 60 ]]; then
        echo -e "${RED}Error: Time window must be a number >= 60 seconds${NC}" >&2
        exit 1
    fi
    
    # Validate output formats
    local valid_formats="console json dashboard markdown file webhook all"
    IFS=',' read -ra FORMATS <<< "$OUTPUT_FORMATS"
    for format in "${FORMATS[@]}"; do
        format=$(echo "$format" | xargs)  # trim whitespace
        if [[ ! " $valid_formats " =~ " $format " ]]; then
            echo -e "${RED}Error: Invalid output format '$format'${NC}" >&2
            echo "Valid formats: $valid_formats" >&2
            exit 1
        fi
    done
    
    # Validate min health threshold
    if [[ -n "$MIN_HEALTH_THRESHOLD" ]]; then
        if ! [[ "$MIN_HEALTH_THRESHOLD" =~ ^[0-9]+$ ]] || [[ "$MIN_HEALTH_THRESHOLD" -lt 0 ]] || [[ "$MIN_HEALTH_THRESHOLD" -gt 100 ]]; then
            echo -e "${RED}Error: Min health threshold must be a number between 0-100${NC}" >&2
            exit 1
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    # Check if Phoenix app directory exists
    if [[ ! -d "$PHOENIX_APP_DIR" ]]; then
        echo -e "${RED}Error: Phoenix app directory not found: $PHOENIX_APP_DIR${NC}" >&2
        exit 1
    fi
    
    # Check if Elixir is available
    if ! command -v elixir &> /dev/null; then
        echo -e "${RED}Error: Elixir not found. Please install Elixir to run telemetry summary.${NC}" >&2
        exit 1
    fi
    
    # Check if Mix is available
    if ! command -v mix &> /dev/null; then
        echo -e "${RED}Error: Mix not found. Please ensure Elixir/Mix is properly installed.${NC}" >&2
        exit 1
    fi
}

# Show startup information
show_startup_info() {
    if [[ "${QUIET_MODE:-false}" == "false" ]]; then
        echo -e "${CYAN}📊 Telemetry Summary - OpenTelemetry and System Monitoring${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "🕐 Time window: ${BLUE}${TIME_WINDOW} seconds${NC}"
        echo -e "📤 Output formats: ${BLUE}${OUTPUT_FORMATS}${NC}"
        
        if [[ "$CONTINUOUS_MODE" == "true" ]]; then
            echo -e "🔄 Mode: ${GREEN}Continuous monitoring${NC}"
        else
            echo -e "🔄 Mode: ${GREEN}Single execution${NC}"
        fi
        
        if [[ "$ALERTS_ONLY" == "true" ]]; then
            echo -e "🚨 Filter: ${YELLOW}Alerts only${NC}"
        fi
        
        if [[ -n "$MIN_HEALTH_THRESHOLD" ]]; then
            echo -e "🏥 Filter: ${YELLOW}Health below ${MIN_HEALTH_THRESHOLD}${NC}"
        fi
        
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo
    fi
}

# Execute telemetry summary
execute_summary() {
    local mix_args=("telemetry.summary" "$TIME_WINDOW" "$OUTPUT_FORMATS")
    
    # Add options
    if [[ "$CONTINUOUS_MODE" == "true" ]]; then
        mix_args+=("--continuous")
    fi
    
    if [[ "$ALERTS_ONLY" == "true" ]]; then
        mix_args+=("--alerts-only")
    fi
    
    if [[ -n "$MIN_HEALTH_THRESHOLD" ]]; then
        mix_args+=("--min-health" "$MIN_HEALTH_THRESHOLD")
    fi
    
    # Change to Phoenix app directory
    cd "$PHOENIX_APP_DIR"
    
    # Execute Mix task
    exec mix "${mix_args[@]}"
}

# Handle interrupt signal for continuous mode
handle_interrupt() {
    if [[ "$CONTINUOUS_MODE" == "true" ]]; then
        echo -e "\n${YELLOW}🛑 Stopping continuous telemetry monitoring...${NC}"
        echo -e "${GREEN}✅ Telemetry summary stopped${NC}"
    fi
    exit 0
}

# Set up signal handling
trap handle_interrupt SIGINT SIGTERM

# Main execution
main() {
    parse_arguments "$@"
    validate_configuration
    check_prerequisites
    show_startup_info
    execute_summary
}

# Execute main function
main "$@"