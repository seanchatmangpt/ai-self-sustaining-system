# SPR: Coordination Operations Command Reference

Comprehensive shell command interface for enterprise-grade AI agent coordination, Scrum at Scale management, and Claude AI intelligence integration.

## Core Coordination Commands

**Work Management**: Atomic operations with nanosecond-precision agent IDs and zero-conflict guarantees.

```bash
# Basic work lifecycle
coordination_helper.sh claim <work_type> <description> [priority] [team]
coordination_helper.sh progress <work_id> <percent> [status]
coordination_helper.sh complete <work_id> [result] [velocity_points]
coordination_helper.sh register <agent_id> [team] [capacity] [specialization]

# Intelligent work claiming with Claude AI optimization
coordination_helper.sh claim-intelligent <work_type> <description> [priority] [team]
coordination_helper.sh claude-recommend-work <type>  # AI-powered work recommendation
```

## Claude AI Intelligence Integration

**Structured Analysis**: JSON-validated output with schema enforcement and retry logic.

```bash
# Priority and optimization analysis
coordination_helper.sh claude-analyze-priorities     # Work priority optimization with structured JSON
coordination_helper.sh claude-optimize-assignments [team]  # Agent assignment and load balancing
coordination_helper.sh claude-health-analysis        # Comprehensive swarm health analysis
coordination_helper.sh claude-team-analysis [team]   # Detailed team performance analysis

# Real-time intelligence streaming
coordination_helper.sh claude-stream <focus> [duration]    # Live coordination insights
coordination_helper.sh claude-pipe <analysis_type>         # Unix-style data pipeline analysis
coordination_helper.sh claude-enhanced <type> <input> <output> [retries]  # Enhanced analysis with retry

# Intelligence dashboard
coordination_helper.sh claude-dashboard  # Show available AI analysis reports and commands
```

## Scrum at Scale Event Management

**Enterprise Ceremonies**: Automated facilitation of PI Planning, ART coordination, and business value demonstration.

```bash
# Program Increment management
coordination_helper.sh pi-planning              # 8-week PI planning with business value prioritization
coordination_helper.sh system-demo             # Integrated solution demonstration with metrics
coordination_helper.sh inspect-adapt           # Improvement workshop with problem-solving

# ART coordination and synchronization
coordination_helper.sh art-sync                # Cross-team dependency management and risk mitigation
coordination_helper.sh scrum-of-scrums         # Daily inter-team coordination and impediment resolution

# Innovation and continuous improvement
coordination_helper.sh innovation-planning     # Innovation & Planning iteration management
coordination_helper.sh portfolio-kanban        # Epic flow management and portfolio-level coordination
coordination_helper.sh value-stream           # End-to-end value stream mapping and optimization
```

## Enterprise Coordination Patterns

**Team Formation**: Autonomous specialization based on capability analysis and workload patterns.

```bash
# Coordination dashboards and monitoring
coordination_helper.sh dashboard               # Real-time Scrum at Scale coordination status
coordination_helper.sh generate-id            # Generate nanosecond-precision agent ID

# Coach and leadership development
coordination_helper.sh coach-training         # Scrum at Scale coach certification and development
```

## File-Based Coordination Architecture

**Atomic Operations**: JSON-based coordination with file locking mechanisms ensuring zero-conflict guarantees.

**Coordination Files**:
- `work_claims.json`: Active work items with nanosecond timestamps and agent assignments
- `agent_status.json`: Team formations, capacity utilization, performance metrics
- `coordination_log.json`: Completed work history and velocity tracking
- `telemetry_spans.jsonl`: OpenTelemetry distributed tracing data

**State Management**: Work progression through atomic transitions: `pending → active → completed`

**Conflict Resolution**: File locking with exponential backoff retry logic prevents coordination conflicts.

## Telemetry and Observability

**OpenTelemetry Integration**: Distributed tracing with trace ID propagation across all coordination operations.

**Performance Metrics**: Real-time coordination efficiency, agent utilization, and business value delivery tracking.

**Health Monitoring**: Composite scoring based on coordination performance, system health, and PI objective progress.

## Business Value Optimization

**PI Objectives**: Program Increment planning with business value prioritization and cross-team coordination.

**ART Metrics**: Agile Release Train velocity tracking, predictability measurement, and quality assessment.

**Customer Value**: Jobs-to-be-Done integration with outcome measurement and satisfaction tracking.

**Continuous Improvement**: Innovation cycles, retrospectives, and process optimization based on telemetry data.

## Usage Patterns

**Emergency Response**: Critical work escalation triggers automatic ART synchronization and resource reallocation.

**Proactive Enhancement**: Low work volume triggers innovation planning and capability research initiatives.

**Balanced Operations**: Steady-state coordination with optimal team formation and workload distribution.

**Enterprise Integration**: Full Scrum at Scale ceremony participation with autonomous facilitation and business value focus.