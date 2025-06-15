# APS Common Workflows Guide

This guide provides proven workflow patterns for the AI Agent Swarm using the Agile Protocol Specification (APS). These workflows are optimized for multi-agent coordination, Phoenix/Elixir development, and continuous system improvement.

## 🤖 Agent Swarm Coordination Workflows

### 1. Agent Initialization & Role Discovery

**Scenario**: Starting a new Claude Code session and joining the agent swarm.

```bash
# Quick initialization
/project:init-agent

# Manual role assignment (if needed)
/project:check-handoffs
/project:claim-work [process_id]
```

**Pattern**: Always start with automatic role assignment, then verify current system state before beginning work.

### 2. Multi-Agent Handoff Workflow

**Scenario**: Completing work and passing to the next agent in the pipeline.

```bash
# Complete current work
/project:system-health  # Verify system stability
/project:tdd-cycle     # Ensure tests pass

# Update APS status and notify next agent
/project:send-message [next_agent_role] "Ready for [next_phase]" "Detailed handoff message"
/project:check-handoffs  # Confirm successful handoff
```

**Pattern**: Verify → Complete → Document → Notify → Confirm

### 3. Parallel Agent Coordination

**Scenario**: Multiple agents working simultaneously on different features.

```bash
# Claim specific work to avoid conflicts
/project:claim-work [feature_id]

# Regular coordination checks
/project:check-handoffs  # Every 30 minutes or major milestone

# Coordinate merge conflicts
/project:send-message Developer_Agent "Merge Coordination" "Working on overlapping files: [list]"
```

**Pattern**: Claim → Coordinate → Communicate → Resolve

## 📋 APS Process Management Workflows

### 4. New Feature Development Process

**Scenario**: Implementing a new feature from concept to deployment.

```bash
# PM_Agent: Requirements gathering
/project:create-aps "Feature_[Name]" "Description"
# Creates: [ID]_requirements.aps.yaml with Gherkin scenarios

# Architect_Agent: System design
/project:claim-work [ID]
# Creates: [ID]_architecture.aps.yaml with C4 model

# Developer_Agent: Implementation
/project:claim-work [ID]
/project:tdd-cycle  # Red-Green-Refactor development
# Creates: Source code + unit tests

# QA_Agent: Testing & validation
/project:claim-work [ID]
# Creates: [ID]_test_results.aps.yaml

# DevOps_Agent: Deployment & monitoring
/project:claim-work [ID]
/project:system-health
# Updates: telemetry.log with deployment metrics
```

**Pattern**: Requirements → Architecture → Development → Testing → Deployment

### 5. Bug Fix & Hotfix Workflow

**Scenario**: Rapid response to production issues.

```bash
# Any agent can initiate
/project:debug-system
/project:create-aps "Hotfix_[Issue]" "Critical bug fix"

# Developer_Agent: Immediate fix
/project:tdd-cycle  # Write failing test first
# Implement fix
/project:system-health  # Verify fix

# QA_Agent: Rapid validation
# Test critical paths only

# DevOps_Agent: Emergency deployment
/project:workflow-health  # Monitor post-deployment
```

**Pattern**: Diagnose → Fix → Test → Deploy → Monitor

## 🛠️ Development & Quality Workflows

### 6. Test-Driven Development Cycle

**Scenario**: Implementing new functionality with comprehensive testing.

```bash
# Start TDD cycle
/project:tdd-cycle

# Follow Red-Green-Refactor pattern:
# 1. Write failing test (Red)
# 2. Write minimal code to pass (Green)  
# 3. Refactor for quality (Refactor)
# 4. Repeat

# Ash Framework specific patterns
mix ash_postgres.generate_migrations  # After resource changes
mix test --cover  # Verify coverage
```

**Pattern**: Red → Green → Refactor → Repeat

### 7. Phoenix/Elixir Development Workflow

**Scenario**: Working with Phoenix application and Ash Framework.

```bash
# System health check
/project:system-health

# Database migration workflow
mix ash_postgres.generate_migrations
# Review generated migrations
mix ecto.migrate

# Development cycle
/project:tdd-cycle
iex -S mix phx.server  # Interactive development

# Verify integration
mix test
mix dialyzer  # Type checking
```

**Pattern**: Health Check → Migrate → Develop → Test → Type Check

### 8. Debugging Complex Issues Workflow

**Scenario**: Systematic approach to difficult bugs.

```bash
# Start debugging session
/project:debug-system

# Choose appropriate debugging mode:
# 1. Phoenix/Elixir Application Debug
# 2. n8n Workflow Debug  
# 3. System Infrastructure Debug
# 4. Test Failure Analysis
# 5. Performance Investigation

# Create debugging APS process if complex
/project:create-aps "Debug_[Issue]" "Complex debugging investigation"

# Document findings
/project:memory-session  # Log patterns and solutions
```

**Pattern**: Identify → Isolate → Investigate → Document → Resolve

## 🚀 Continuous Improvement Workflows

### 9. AI-Powered Enhancement Discovery

**Scenario**: Systematically improving the system using AI analysis.

```bash
# Discover improvement opportunities
/project:discover-enhancements

# Log hypothesis for testing
/project:memory-session  # Select: Log Improvement Hypotheses

# Create enhancement APS process
/project:create-aps "Enhancement_[Area]" "AI-discovered improvement"

# Implement with quality gates
/project:implement-enhancement
/project:tdd-cycle  # Ensure tests pass
/project:system-health  # Verify stability
```

**Pattern**: Discover → Hypothesize → Plan → Implement → Verify

### 10. Performance Optimization Workflow

**Scenario**: Systematic performance improvement.

```bash
# Baseline measurement
/project:system-health
/project:workflow-health

# Identify bottlenecks
/project:debug-system  # Select: Performance Investigation

# Create optimization APS process
/project:create-aps "Optimization_[Component]" "Performance improvement"

# Implement with measurement
/project:tdd-cycle  # Performance tests
# Measure improvement
/project:system-health  # Verify gains
```

**Pattern**: Measure → Identify → Optimize → Verify → Monitor

## 🧠 Advanced Coordination Workflows

### 11. Session Continuity & Knowledge Transfer

**Scenario**: Maintaining context across agent sessions and handoffs.

```bash
# Session initialization with context
/project:init-agent
/project:memory-session  # Review session history

# Create session memory context
/project:memory-session  # Select: Create Session Memory Context

# Regular knowledge updates
/project:memory-session  # Select: Update CLAUDE.md Documentation

# End-of-session handoff
/project:memory-session  # Select: Session Summary & Handoff
```

**Pattern**: Initialize → Review → Update → Transfer

### 12. Conflict Resolution Workflow

**Scenario**: Resolving conflicts between parallel agents.

```bash
# Detect conflict
/project:check-handoffs  # Shows conflicting claims

# Coordinate resolution
/project:send-message [conflicting_agent] "Conflict Resolution" "Detailed coordination message"

# Implement resolution strategy:
# - Time-based priority (earlier timestamp wins)
# - Work partitioning (split features)
# - Sequential handoff (convert to pipeline)

# Update APS files with resolution
# Continue with resolved workflow
```

**Pattern**: Detect → Communicate → Resolve → Document → Continue

### 13. Emergency Response Workflow

**Scenario**: System-wide issues requiring immediate attention.

```bash
# Emergency assessment
/project:system-health
/project:debug-system

# Create emergency APS process
/project:create-aps "Emergency_[Issue]" "Critical system issue"

# All-hands coordination
/project:send-message ALL_AGENTS "Emergency Response" "System issue requires immediate attention"

# Parallel emergency response:
# - Developer_Agent: Implement fixes
# - QA_Agent: Rapid testing
# - DevOps_Agent: System monitoring
# - PM_Agent: Stakeholder communication

# Recovery verification
/project:system-health
/project:workflow-health
```

**Pattern**: Assess → Alert → Coordinate → Respond → Verify

## 🎯 Best Practices & Patterns

### Workflow Selection Guidelines

1. **Simple Tasks**: Direct execution without APS process
2. **Feature Development**: Full APS pipeline (PM → Architect → Developer → QA → DevOps)
3. **Bug Fixes**: Abbreviated pipeline (Developer → QA → DevOps)
4. **Improvements**: Discovery-driven approach with hypothesis testing
5. **Emergencies**: Parallel response with centralized coordination

### Communication Patterns

- **Start Broad**: Use `/project:check-handoffs` to understand full context
- **Be Specific**: Include detailed technical information in APS messages
- **Verify Understanding**: Confirm handoffs before proceeding
- **Document Decisions**: Use `/project:memory-session` for important patterns

### Quality Gates

- **Always Test**: Use `/project:tdd-cycle` for all code changes
- **Verify Health**: Run `/project:system-health` before major changes
- **Check Coverage**: Ensure comprehensive test coverage
- **Type Safety**: Use Elixir's dialyzer for type checking

### Error Recovery

- **Graceful Degradation**: Design workflows to handle agent failures
- **State Recovery**: Use APS files to resume interrupted workflows
- **Conflict Resolution**: Clear protocols for resource conflicts
- **Emergency Procedures**: Rapid response workflows for critical issues

## 🔧 Tool Integration Patterns

### Slash Command Sequences

Common command combinations for efficient workflows:

```bash
# Agent startup sequence
/project:init-agent && /project:check-handoffs

# Development readiness check  
/project:system-health && /project:tdd-cycle

# Enhancement workflow
/project:discover-enhancements && /project:memory-session

# Quality assurance sequence
/project:tdd-cycle && /project:system-health && /project:workflow-health

# Session wrap-up
/project:check-handoffs && /project:memory-session
```

### Phoenix/Elixir Integration

```bash
# Standard development cycle
mix ash_postgres.generate_migrations
mix ecto.migrate
/project:tdd-cycle
mix test --cover
mix dialyzer

# Deployment verification
/project:system-health
mix phx.server  # Manual verification
/project:workflow-health
```

### n8n Workflow Integration

```bash
# Workflow development
/project:workflow-health  # Check current state
# Edit n8n workflows through UI
/project:workflow-health  # Verify changes
/project:system-health    # Full system check
```

---

**Remember**: These workflows are living patterns that evolve with the system. Use `/project:memory-session` to document new patterns and improvements as they emerge. The APS protocol ensures coordination, but these workflows provide the practical execution patterns for common scenarios.

Each workflow should be adapted to specific circumstances while maintaining the core patterns of coordination, quality, and continuous improvement that define the AI agent swarm approach.