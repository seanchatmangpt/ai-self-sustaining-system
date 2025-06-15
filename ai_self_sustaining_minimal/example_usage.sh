#!/bin/bash

# Example usage of the coordination helper

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/coordination_helper.sh"

echo "🚀 Example Agent Workflow"
echo "========================="

# 1. Register agent
echo "1. Registering agent..."
$HELPER register '["data_processing", "telemetry_analysis"]'

# 2. Send heartbeat
echo -e "\n2. Sending heartbeat..."
$HELPER heartbeat

# 3. Submit work
echo -e "\n3. Submitting work item..."
WORK_RESULT=$($HELPER submit "data_analysis" "Process telemetry data from OTLP pipeline" "high")
WORK_ID=$(echo "$WORK_RESULT" | jq -r '.data.work_item_id')

# 4. List pending work
echo -e "\n4. Listing pending work..."
$HELPER list-work pending

# 5. Claim the work
echo -e "\n5. Claiming work: $WORK_ID"
$HELPER claim "$WORK_ID"

# 6. Complete the work
echo -e "\n6. Completing work with results..."
$HELPER complete "$WORK_ID" '{"processed_records": 1000, "anomalies_detected": 5}'

# 7. Check system status
echo -e "\n7. Checking system status..."
$HELPER status

# 8. Check health
echo -e "\n8. Checking system health..."
$HELPER health

echo -e "\n✅ Example workflow completed!"
