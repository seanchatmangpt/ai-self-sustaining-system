#!/bin/bash
# BEAMOps V3 Enterprise Stack Deployment

set -euo pipefail

echo "🚀 Deploying BEAMOps V3 Enterprise Stack"

# Phase 1: Foundation Infrastructure
echo "🏗️  Phase 1: Foundation Infrastructure"
./scripts/chapters/chapter-02-terraform.sh
./scripts/chapters/chapter-03-docker.sh
./scripts/chapters/chapter-04-cicd.sh
./scripts/chapters/chapter-05-development.sh
./scripts/chapters/chapter-06-production.sh

# Phase 2: Distributed Systems
echo "🌐 Phase 2: Distributed Systems"
./scripts/chapters/chapter-07-secrets.sh
./scripts/chapters/chapter-08-swarm.sh
./scripts/chapters/chapter-09-distributed.sh

# Phase 3: Enterprise Operations
echo "📊 Phase 3: Enterprise Operations"
./scripts/chapters/chapter-10-autoscaling.sh
./scripts/chapters/chapter-11-instrumentation.sh
./scripts/chapters/chapter-12-monitoring.sh

echo "✅ BEAMOps V3 Enterprise Stack Deployed"
