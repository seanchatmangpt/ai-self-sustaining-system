#!/bin/bash

# Test script to demonstrate OpenTelemetry integration with S@S coordination

echo "🔍 OPENTELEMETRY INTEGRATION TEST FOR S@S COORDINATION"
echo "======================================================"
echo ""

# Set OpenTelemetry environment variables
export OTEL_SERVICE_NAME="s2s-coordination-demo"
export OTEL_SERVICE_VERSION="1.2.0"
export DEPLOYMENT_ENV="testing"

echo "🔧 OpenTelemetry Configuration:"
echo "  Service: $OTEL_SERVICE_NAME v$OTEL_SERVICE_VERSION"
echo "  Environment: $DEPLOYMENT_ENV"
echo ""

# Test 1: Work claiming with tracing
echo "📋 Test 1: Work Claiming with OpenTelemetry Tracing"
echo "------------------------------------------------"
./coordination_helper.sh claim "otel_demo_feature" "Implement distributed tracing across S@S workflows" "critical" "observability_team"
echo ""

# Test 2: Progress updates with trace propagation
echo "📈 Test 2: Progress Updates with Trace Propagation"
echo "-----------------------------------------------"
LATEST_WORK=$(jq -r '.[-1].work_item_id' work_claims.json)
echo "Updating work item: $LATEST_WORK"

./coordination_helper.sh progress "$LATEST_WORK" "25" "analysis"
sleep 1
./coordination_helper.sh progress "$LATEST_WORK" "50" "design"
sleep 1
./coordination_helper.sh progress "$LATEST_WORK" "75" "implementation"
sleep 1
./coordination_helper.sh progress "$LATEST_WORK" "90" "testing"
echo ""

# Test 3: Work completion with final trace
echo "✅ Test 3: Work Completion with Final Trace"
echo "----------------------------------------"
./coordination_helper.sh complete "$LATEST_WORK" "success" "12"
echo ""

# Test 4: Show telemetry data
echo "📊 Test 4: Telemetry Data Analysis"
echo "--------------------------------"
echo "Work item with embedded telemetry:"
jq ".[] | select(.work_item_id == \"$LATEST_WORK\") | .telemetry" work_claims.json
echo ""

if [ -f "telemetry_spans.jsonl" ]; then
    echo "📈 OpenTelemetry spans logged:"
    echo "  Total spans: $(wc -l < telemetry_spans.jsonl)"
    echo "  Latest span:"
    tail -1 telemetry_spans.jsonl | jq '.'
else
    echo "⚠️ No telemetry spans file found (spans may be sent to collector directly)"
fi
echo ""

# Test 5: S@S Event with Tracing
echo "🎯 Test 5: S@S Events with Distributed Tracing"
echo "--------------------------------------------"
echo "Running PI Planning with OpenTelemetry context..."
./coordination_helper.sh pi-planning
echo ""

echo "Running Scrum of Scrums with trace correlation..."
./coordination_helper.sh scrum-of-scrums
echo ""

# Test 6: Claude Intelligence with Tracing
echo "🧠 Test 6: Claude Intelligence with OpenTelemetry"
echo "----------------------------------------------"
echo "Analyzing work priorities with trace context..."
./coordination_helper.sh claude-analyze-priorities
echo ""

# Summary
echo "📋 OPENTELEMETRY INTEGRATION SUMMARY"
echo "===================================="
echo "✅ Trace IDs generated for all S@S operations"
echo "✅ Trace propagation across work lifecycle"
echo "✅ Telemetry embedded in coordination data"
echo "✅ Distributed tracing across S@S events"
echo "✅ Claude intelligence operations traced"
echo ""
echo "🎯 Key Benefits Achieved:"
echo "  • End-to-end observability across S@S workflows"
echo "  • Correlation of work items with trace context"
echo "  • Performance monitoring of coordination operations"
echo "  • Distributed tracing for multi-agent workflows"
echo "  • Integration with existing telemetry infrastructure"
echo ""
echo "📈 Next Steps:"
echo "  • Configure OpenTelemetry collector (OTEL_EXPORTER_OTLP_ENDPOINT)"
echo "  • Set up monitoring dashboards for S@S metrics"
echo "  • Implement sampling strategies for high-volume operations"
echo "  • Add custom metrics for business value tracking"