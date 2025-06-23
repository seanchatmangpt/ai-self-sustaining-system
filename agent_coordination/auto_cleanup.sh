#!/bin/bash
# Automatic cleanup script for cron
cd "/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
bash benchmark_cleanup_script.sh --auto >> "/Users/sac/dev/ai-self-sustaining-system/agent_coordination/logs/auto_cleanup.log" 2>&1
