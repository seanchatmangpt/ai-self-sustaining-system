#!/bin/bash
# Live Smart Routing Enhancement

route_work_to_specialist() {
    local work_type="$1"
    
    case "$work_type" in
        *"observability"*) echo "observability_team" ;;
        *"trace"*) echo "trace_team" ;;
        *"coordination"*) echo "coordination_team" ;;
        *"8020"*) echo "8020_team" ;;
        *) echo "autonomous_team" ;;
    esac
}

# Test live routing
echo "Smart routing active: $(route_work_to_specialist 'observability_test')"
