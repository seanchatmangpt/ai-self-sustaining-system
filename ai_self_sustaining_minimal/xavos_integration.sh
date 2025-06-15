#!/bin/bash

# XAVOS Integration Helper for AI Self-Sustaining System
# Monitors and manages the connection between autonomous operations and XAVOS Reactors

set -e

API_BASE="${API_BASE:-http://localhost:4000/api}"
XAVOS_API_BASE="${XAVOS_API_BASE:-http://localhost:4001/api}"

usage() {
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  status                          Get XAVOS bridge status"
    echo "  workflows                       List active XAVOS workflows"
    echo "  bridge-stats                    Show bridge statistics"
    echo "  test-connectivity               Test XAVOS connectivity"
    echo "  trigger-reactor <work_id>       Manually trigger XAVOS Reactor for work item"
    echo "  list-xavos-work                 List work items processed by XAVOS"
    echo "  health                          Check overall integration health"
    echo ""
    echo "Environment Variables:"
    echo "  API_BASE       Local API base URL (default: http://localhost:4000/api)"
    echo "  XAVOS_API_BASE XAVOS API base URL (default: http://localhost:4001/api)"
}

get_bridge_status() {
    echo "🌉 Getting XAVOS Reactor Bridge status:"
    
    curl -s -X GET "$API_BASE/xavos/bridge/status" \
        -H "Content-Type: application/json" \
        | jq '.'
}

get_active_workflows() {
    echo "⚙️ Getting active XAVOS workflows:"
    
    curl -s -X GET "$API_BASE/xavos/bridge/workflows" \
        -H "Content-Type: application/json" \
        | jq '.'
}

get_bridge_stats() {
    echo "📊 Getting XAVOS bridge statistics:"
    
    curl -s -X GET "$API_BASE/xavos/bridge/stats" \
        -H "Content-Type: application/json" \
        | jq '.'
}

test_xavos_connectivity() {
    echo "🔌 Testing XAVOS connectivity:"
    
    # Test local system
    echo "Testing local system..."
    local_status=$(curl -s -w "%{http_code}" -X GET "$API_BASE/otlp/health" 2>/dev/null)
    local_code="${local_status: -3}"
    
    if [[ "$local_code" == "200" ]]; then
        echo "✅ Local system: Connected"
    else
        echo "❌ Local system: Failed (HTTP $local_code)"
    fi
    
    # Test XAVOS system
    echo "Testing XAVOS system..."
    xavos_status=$(curl -s -w "%{http_code}" -X GET "$XAVOS_API_BASE/health" 2>/dev/null)
    xavos_code="${xavos_status: -3}"
    
    if [[ "$xavos_code" == "200" ]]; then
        echo "✅ XAVOS system: Connected"
    else
        echo "❌ XAVOS system: Failed (HTTP $xavos_code)"
        echo "   Make sure XAVOS is running on port 4001"
    fi
    
    # Test bridge integration
    echo "Testing bridge integration..."
    bridge_status=$(curl -s -w "%{http_code}" -X GET "$API_BASE/xavos/bridge/status" 2>/dev/null)
    bridge_code="${bridge_status: -3}"
    
    if [[ "$bridge_code" == "200" ]]; then
        echo "✅ Bridge integration: Active"
    else
        echo "❌ Bridge integration: Failed (HTTP $bridge_code)"
    fi
}

trigger_reactor_manually() {
    local work_id="$1"
    
    if [[ -z "$work_id" ]]; then
        echo "Error: work_id is required"
        return 1
    fi
    
    echo "🚀 Manually triggering XAVOS Reactor for work: $work_id"
    
    curl -s -X POST "$API_BASE/xavos/bridge/trigger" \
        -H "Content-Type: application/json" \
        -d "{\"work_id\": \"$work_id\"}" \
        | jq '.'
}

list_xavos_work() {
    echo "📋 Listing work items processed by XAVOS:"
    
    curl -s -X GET "$API_BASE/coordination/work?xavos_processed=true" \
        -H "Content-Type: application/json" \
        | jq '.data[] | {
            work_item_id: .work_item_id,
            work_type: .work_type,
            status: .status,
            xavos_workflow_id: .payload.xavos_workflow_id,
            xavos_integration_at: .payload.xavos_integration_at
          }'
}

check_integration_health() {
    echo "🏥 Checking overall XAVOS integration health:"
    echo ""
    
    # Get bridge status
    bridge_response=$(curl -s -X GET "$API_BASE/xavos/bridge/status" 2>/dev/null)
    bridge_connected=$(echo "$bridge_response" | jq -r '.xavos_connected // false' 2>/dev/null)
    
    if [[ "$bridge_connected" == "true" ]]; then
        echo "✅ Bridge Status: Connected"
        
        # Get statistics
        active_workflows=$(echo "$bridge_response" | jq -r '.active_workflows // 0' 2>/dev/null)
        total_triggered=$(echo "$bridge_response" | jq -r '.bridge_stats.total_workflows_triggered // 0' 2>/dev/null)
        successful_integrations=$(echo "$bridge_response" | jq -r '.bridge_stats.successful_integrations // 0' 2>/dev/null)
        
        echo "📊 Active Workflows: $active_workflows"
        echo "📊 Total Triggered: $total_triggered"
        echo "📊 Successful Integrations: $successful_integrations"
        
        # Calculate success rate
        if [[ "$total_triggered" -gt 0 ]]; then
            success_rate=$(echo "scale=1; $successful_integrations * 100 / $total_triggered" | bc -l 2>/dev/null || echo "0")
            echo "📊 Success Rate: ${success_rate}%"
        fi
        
        echo ""
        echo "🎯 Integration Status: OPERATIONAL"
    else
        echo "❌ Bridge Status: Disconnected"
        echo "⚠️ Integration Status: DEGRADED"
        echo ""
        echo "💡 Troubleshooting:"
        echo "   1. Check if XAVOS is running: curl $XAVOS_API_BASE/health"
        echo "   2. Check bridge logs: docker logs <bridge_container>"
        echo "   3. Verify network connectivity between systems"
    fi
}

# Main command dispatch
case "$1" in
    "status")
        get_bridge_status
        ;;
    "workflows")
        get_active_workflows
        ;;
    "bridge-stats")
        get_bridge_stats
        ;;
    "test-connectivity")
        test_xavos_connectivity
        ;;
    "trigger-reactor")
        trigger_reactor_manually "$2"
        ;;
    "list-xavos-work")
        list_xavos_work
        ;;
    "health")
        check_integration_health
        ;;
    "help"|"-h"|"--help"|"")
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac