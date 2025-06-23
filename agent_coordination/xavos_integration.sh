#!/bin/bash
# XAVOS S@S Integration Bridge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XAVOS_DIR="$SCRIPT_DIR/../worktrees/xavos-system/xavos"

show_xavos_status() {
    echo "📊 XAVOS S@S INTEGRATION STATUS"
    echo "================================"
    echo ""
    
    if [ -d "$XAVOS_DIR" ]; then
        echo "✅ XAVOS system found at: $XAVOS_DIR"
        
        # Check if XAVOS is running
        if lsof -Pi :4001 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "🟢 XAVOS Phoenix server running on port 4001"
        else
            echo "🔴 XAVOS Phoenix server not running"
        fi
        
        echo ""
        echo "🌐 XAVOS Access Points:"
        echo "  Main Application: http://localhost:4001"
        echo "  Phoenix Dashboard: http://localhost:4001/dev/dashboard"
        
    else
        echo "❌ XAVOS system not found"
        echo "   Run: ./deploy_xavos_complete.sh"
    fi
}

case "${1:-help}" in
    "status")
        show_xavos_status
        ;;
    "start-xavos")
        cd "$XAVOS_DIR"
        ./scripts/start_xavos.sh
        ;;
    *)
        echo "XAVOS S@S Integration Commands:"
        echo "  status      Show XAVOS integration status"
        echo "  start-xavos Start XAVOS system"
        ;;
esac
