#!/bin/bash

# Coordination Helper for Minimal AI Self-Sustaining System
# Uses new Ash-based API endpoints

set -e

API_BASE="${API_BASE:-http://localhost:4000/api}"
AGENT_ID="${AGENT_ID:-agent_$(date +%s%N)}"

usage() {
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  register [capabilities]         Register agent with optional capabilities"
    echo "  heartbeat                       Send heartbeat for current agent"
    echo "  submit <work_type> <desc> [priority]  Submit work item"
    echo "  claim <work_id>                 Claim a work item"
    echo "  start <work_id>                 Start a claimed work item"
    echo "  complete <work_id> [result]     Complete a work item"
    echo "  list-agents                     List active agents"
    echo "  list-work [status]              List work items"
    echo "  status                          Get OTLP pipeline status"
    echo "  health                          Check system health"
    echo ""
    echo "Environment Variables:"
    echo "  API_BASE    API base URL (default: http://localhost:4000/api)"
    echo "  AGENT_ID    Agent ID (default: agent_<timestamp>)"
}

register_agent() {
    local capabilities="${1:-[]}"
    echo "🤖 Registering agent: $AGENT_ID"
    
    curl -s -X POST "$API_BASE/coordination/agents/register" \
        -H "Content-Type: application/json" \
        -d "{\"agent_id\": \"$AGENT_ID\", \"capabilities\": $capabilities}" \
        | jq '.'
}

send_heartbeat() {
    echo "💓 Sending heartbeat for agent: $AGENT_ID"
    
    curl -s -X PUT "$API_BASE/coordination/agents/$AGENT_ID/heartbeat" \
        -H "Content-Type: application/json" \
        | jq '.'
}

submit_work() {
    local work_type="$1"
    local description="$2"
    local priority="${3:-medium}"
    
    if [[ -z "$work_type" || -z "$description" ]]; then
        echo "Error: work_type and description are required"
        return 1
    fi
    
    echo "📝 Submitting work: $work_type"
    
    curl -s -X POST "$API_BASE/coordination/work" \
        -H "Content-Type: application/json" \
        -d "{\"work_type\": \"$work_type\", \"description\": \"$description\", \"priority\": \"$priority\"}" \
        | jq '.'
}

claim_work() {
    local work_id="$1"
    
    if [[ -z "$work_id" ]]; then
        echo "Error: work_id is required"
        return 1
    fi
    
    echo "🎯 Claiming work: $work_id"
    
    curl -s -X PUT "$API_BASE/coordination/work/$work_id/claim" \
        -H "Content-Type: application/json" \
        -d "{\"agent_id\": \"$AGENT_ID\"}" \
        | jq '.'
}

start_work() {
    local work_id="$1"
    
    if [[ -z "$work_id" ]]; then
        echo "Error: work_id is required"
        return 1
    fi
    
    echo "🚀 Starting work: $work_id"
    
    curl -s -X PUT "$API_BASE/coordination/work/$work_id/start" \
        -H "Content-Type: application/json" \
        -d "{}" \
        | jq '.'
}

complete_work() {
    local work_id="$1"
    local result="${2:-{}}"
    
    if [[ -z "$work_id" ]]; then
        echo "Error: work_id is required"
        return 1
    fi
    
    echo "✅ Completing work: $work_id"
    
    curl -s -X PUT "$API_BASE/coordination/work/$work_id/complete" \
        -H "Content-Type: application/json" \
        -d "{\"result\": $result}" \
        | jq '.'
}

list_agents() {
    echo "👥 Listing active agents:"
    
    curl -s -X GET "$API_BASE/coordination/agents" \
        -H "Content-Type: application/json" \
        | jq '.'
}

list_work() {
    local status="$1"
    local url="$API_BASE/coordination/work"
    
    if [[ -n "$status" ]]; then
        url="$url?status=$status"
    fi
    
    echo "📋 Listing work items:"
    
    curl -s -X GET "$url" \
        -H "Content-Type: application/json" \
        | jq '.'
}

get_status() {
    echo "📊 Getting OTLP pipeline status:"
    
    curl -s -X GET "$API_BASE/otlp/pipeline/status" \
        -H "Content-Type: application/json" \
        | jq '.'
}

check_health() {
    echo "🏥 Checking system health:"
    
    curl -s -X GET "$API_BASE/otlp/health" \
        -H "Content-Type: application/json" \
        | jq '.'
}

# Main command dispatch
case "$1" in
    "register")
        register_agent "$2"
        ;;
    "heartbeat")
        send_heartbeat
        ;;
    "submit")
        submit_work "$2" "$3" "$4"
        ;;
    "claim")
        claim_work "$2"
        ;;
    "start")
        start_work "$2"
        ;;
    "complete")
        complete_work "$2" "$3"
        ;;
    "list-agents")
        list_agents
        ;;
    "list-work")
        list_work "$2"
        ;;
    "status")
        get_status
        ;;
    "health")
        check_health
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
