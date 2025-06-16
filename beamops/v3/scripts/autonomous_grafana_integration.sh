#!/bin/bash

# Autonomous Grafana Integration Script for AI Self-Sustaining System
# Integrates BeamOps V3 PromEx metrics with Grafana for real-time coordination monitoring
# Following Engineering Elixir Applications patterns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEAMOPS_ROOT="$(dirname "$SCRIPT_DIR")"
COORDINATION_ROOT="$BEAMOPS_ROOT/../agent_coordination"
GRAFANA_CONFIG="$BEAMOPS_ROOT/grafana"
DASHBOARDS_DIR="$BEAMOPS_ROOT/priv/grafana_dashboards"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if Grafana is running
check_grafana_status() {
    if curl -s "http://localhost:3000/api/health" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start Grafana with Docker
start_grafana() {
    log "Starting Grafana with Docker..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is required but not installed"
        exit 1
    fi
    
    # Create Grafana data directory
    mkdir -p "$GRAFANA_CONFIG/data"
    mkdir -p "$GRAFANA_CONFIG/provisioning/datasources"
    mkdir -p "$GRAFANA_CONFIG/provisioning/dashboards"
    
    # Create datasource configuration
    cat > "$GRAFANA_CONFIG/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://host.docker.internal:4369
    isDefault: true
    editable: true
EOF

    # Create dashboard provisioning configuration
    cat > "$GRAFANA_CONFIG/provisioning/dashboards/beamops.yml" << EOF
apiVersion: 1

providers:
  - name: 'BeamOps Dashboards'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    # Start Grafana container
    docker run -d \
        --name beamops-grafana \
        -p 3000:3000 \
        -v "$GRAFANA_CONFIG/data:/var/lib/grafana" \
        -v "$GRAFANA_CONFIG/provisioning:/etc/grafana/provisioning" \
        -v "$DASHBOARDS_DIR:/etc/grafana/provisioning/dashboards" \
        -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
        grafana/grafana:latest
    
    # Wait for Grafana to start
    log "Waiting for Grafana to start..."
    for i in {1..30}; do
        if check_grafana_status; then
            success "Grafana started successfully"
            return 0
        fi
        sleep 2
    done
    
    error "Grafana failed to start within 60 seconds"
    return 1
}

# Function to update coordination metrics in real-time
update_coordination_metrics() {
    log "Updating coordination metrics..."
    
    # Read current work claims
    if [[ -f "$COORDINATION_ROOT/work_claims.json" ]]; then
        local work_claims=$(cat "$COORDINATION_ROOT/work_claims.json")
        local total_items=$(echo "$work_claims" | jq length)
        local completed_items=$(echo "$work_claims" | jq '[.[] | select(.status == "completed")] | length')
        local active_items=$(echo "$work_claims" | jq '[.[] | select(.status == "active")] | length')
        local error_items=$(echo "$work_claims" | jq '[.[] | select(.status | contains("error") or contains("failed"))] | length')
        
        # Calculate metrics
        local completion_rate=0
        local efficiency_ratio=0
        local health_score=95
        
        if [[ $total_items -gt 0 ]]; then
            completion_rate=$(echo "scale=2; $completed_items * 100 / $total_items" | bc -l)
            local working_items=$((completed_items + active_items))
            if [[ $working_items -gt 0 ]]; then
                efficiency_ratio=$(echo "scale=2; $completed_items / $working_items" | bc -l)
            fi
            local error_percentage=$(echo "scale=2; $error_items * 100 / $total_items" | bc -l)
            health_score=$(echo "scale=2; 100 - $error_percentage" | bc -l)
        fi
        
        log "Coordination Metrics:"
        log "  Total Items: $total_items"
        log "  Completed: $completed_items"
        log "  Active: $active_items"
        log "  Errors: $error_items"
        log "  Completion Rate: ${completion_rate}%"
        log "  Efficiency Ratio: $efficiency_ratio"
        log "  Health Score: $health_score"
        
        # Update Prometheus metrics via BeamOps
        if command -v curl &> /dev/null; then
            # Send metrics to BeamOps endpoint (if running)
            curl -s -X POST "http://localhost:4369/metrics/coordination" \
                -H "Content-Type: application/json" \
                -d "{
                    \"total_items\": $total_items,
                    \"completed_items\": $completed_items,
                    \"active_items\": $active_items,
                    \"error_items\": $error_items,
                    \"completion_rate\": $completion_rate,
                    \"efficiency_ratio\": $efficiency_ratio,
                    \"health_score\": $health_score,
                    \"timestamp\": \"$(date -Iseconds)\"
                }" > /dev/null 2>&1 || true
        fi
    else
        warning "Work claims file not found: $COORDINATION_ROOT/work_claims.json"
    fi
}

# Function to create coordination dashboard
create_coordination_dashboard() {
    log "Creating coordination dashboard..."
    
    cat > "$DASHBOARDS_DIR/autonomous_coordination.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Autonomous AI Agent Coordination",
    "description": "Real-time monitoring of AI agent coordination system",
    "tags": ["ai", "coordination", "autonomous", "beamops"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Active Agents",
        "type": "stat",
        "targets": [
          {
            "expr": "beamops_agents_active_count",
            "legendFormat": "Active Agents"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "green", "value": 3}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Work Completion Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "beamops_work_completion_rate",
            "legendFormat": "Completion Rate %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 50},
                {"color": "green", "value": 80}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Coordination Efficiency",
        "type": "gauge",
        "targets": [
          {
            "expr": "beamops_coordination_efficiency_ratio",
            "legendFormat": "Efficiency Ratio"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 1,
            "unit": "percentunit",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 0.6},
                {"color": "green", "value": 0.8}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0}
      },
      {
        "id": 4,
        "title": "System Health Score",
        "type": "gauge",
        "targets": [
          {
            "expr": "beamops_system_health_score",
            "legendFormat": "Health Score"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "unit": "short",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 70},
                {"color": "green", "value": 90}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0}
      },
      {
        "id": 5,
        "title": "Work Items Over Time",
        "type": "timeseries",
        "targets": [
          {
            "expr": "beamops_agents_active_count",
            "legendFormat": "Active Agents"
          },
          {
            "expr": "beamops_work_completion_rate / 10",
            "legendFormat": "Completion Rate (scaled)"
          }
        ],
        "gridPos": {"h": 9, "w": 24, "x": 0, "y": 8}
      }
    ],
    "time": {
      "from": "now-30m",
      "to": "now"
    },
    "refresh": "5s",
    "version": 1
  }
}
EOF
    
    success "Coordination dashboard created"
}

# Function to test the integration
test_integration() {
    log "Testing Grafana integration..."
    
    if check_grafana_status; then
        success "Grafana is accessible at http://localhost:3000"
        success "Default credentials: admin/admin"
    else
        error "Grafana is not accessible"
        return 1
    fi
    
    # Test metrics endpoint
    if curl -s "http://localhost:4369/metrics" > /dev/null 2>&1; then
        success "BeamOps metrics endpoint is accessible"
    else
        warning "BeamOps metrics endpoint not accessible (may need to start BeamOps)"
    fi
}

# Function to watch coordination metrics in real-time
watch_metrics() {
    log "Starting real-time metrics monitoring..."
    log "Press Ctrl+C to stop"
    
    while true; do
        clear
        echo "====== Autonomous AI Agent Coordination Metrics ======"
        echo "$(date)"
        echo
        update_coordination_metrics
        echo
        echo "======================================================"
        sleep 5
    done
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            log "Starting autonomous Grafana integration..."
            start_grafana
            create_coordination_dashboard
            test_integration
            success "Grafana integration started successfully"
            log "Access Grafana at: http://localhost:3000"
            ;;
        "stop")
            log "Stopping Grafana..."
            docker stop beamops-grafana > /dev/null 2>&1 || true
            docker rm beamops-grafana > /dev/null 2>&1 || true
            success "Grafana stopped"
            ;;
        "status")
            if check_grafana_status; then
                success "Grafana is running at http://localhost:3000"
            else
                warning "Grafana is not running"
            fi
            ;;
        "metrics")
            update_coordination_metrics
            ;;
        "watch")
            watch_metrics
            ;;
        "test")
            test_integration
            ;;
        "dashboard")
            create_coordination_dashboard
            ;;
        "help")
            echo "Autonomous Grafana Integration for AI Self-Sustaining System"
            echo
            echo "Usage: $0 <command>"
            echo
            echo "Commands:"
            echo "  start      - Start Grafana with autonomous monitoring"
            echo "  stop       - Stop Grafana container"
            echo "  status     - Check Grafana status"
            echo "  metrics    - Update coordination metrics once"
            echo "  watch      - Watch metrics in real-time"
            echo "  test       - Test integration connectivity"
            echo "  dashboard  - Create/update coordination dashboard"
            echo "  help       - Show this help"
            ;;
        *)
            error "Unknown command: $command"
            $0 help
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v jq &> /dev/null; then
    error "jq is required but not installed. Please install jq first."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    error "bc is required but not installed. Please install bc first."
    exit 1
fi

main "$@"