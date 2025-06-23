#!/bin/bash
# BEAMOps V3 Deployment Monitoring

set -euo pipefail

echo "📊 Monitoring BEAMOps V3 Deployment"

# Check service health
echo "🔍 Checking service health..."
curl -f http://localhost:3000/api/health || echo "⚠️  Grafana health check failed"
curl -f http://localhost:9090/api/v1/targets || echo "⚠️  Prometheus targets check failed"
curl -f http://localhost:4000/metrics || echo "⚠️  Phoenix metrics endpoint check failed"

# Display dashboard URLs
echo "📈 Access monitoring dashboards:"
echo "   Grafana: http://localhost:3000"
echo "   Prometheus: http://localhost:9090"
echo "   Coordination: http://localhost:4000"

# Show coordination system status
echo "🤖 Coordination system status:"
./scripts/coordination_helper.sh status
