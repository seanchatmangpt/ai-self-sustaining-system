#!/bin/bash
# Monitor the self-sustaining AI system

PROJECT_ROOT="/Users/sac/dev/ai-self-sustaining-system"
cd "$PROJECT_ROOT"

echo "📊 Self-Sustaining System Monitor"
echo "================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check service status
check_service() {
    local service=$1
    local port=$2
    local url=$3
    
    if curl -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $service is running on port $port"
        return 0
    else
        echo -e "${RED}✗${NC} $service is not responding on port $port"
        return 1
    fi
}

# Continuous monitoring loop
while true; do
    clear
    echo "📊 Self-Sustaining System Monitor"
    echo "================================"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Check services
    echo "Service Status:"
    check_service "Phoenix" 4000 "http://localhost:4000"
    check_service "n8n" 5678 "http://localhost:5678/healthz"
    check_service "PostgreSQL" 5432 "localhost:5432"
    
    echo ""
    echo "System Metrics:"
    
    # Check enhancement system
    if check_service "Phoenix" 4000 "http://localhost:4000" > /dev/null 2>&1; then
        # Get enhancement stats
        stats=$(curl -s http://localhost:4000/api/enhancements/stats 2>/dev/null || echo "{}")
        
        if [ ! -z "$stats" ] && [ "$stats" != "{}" ]; then
            echo "- Enhancements discovered: $(echo $stats | jq -r .discovered // 0)"
            echo "- Successfully deployed: $(echo $stats | jq -r .deployed // 0)"
            echo "- In progress: $(echo $stats | jq -r .in_progress // 0)"
            echo "- Failed: $(echo $stats | jq -r .failed // 0)"
        fi
    fi
    
    echo ""
    echo "Recent Activity:"
    # Show recent logs
    if [ -f monitoring/activity.log ]; then
        tail -5 monitoring/activity.log
    fi
    
    echo ""
    echo "Press Ctrl+C to exit"
    
    sleep 5
done
