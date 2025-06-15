# AI Context & Memory Management

**Purpose**: Session memory, documentation, and knowledge management.

```bash
/project:memory-session [mode]
```

## Memory Workflows

### 1. Create Session Memory Context
- **Session Initialization**: Current session context capture
- **Goal Documentation**: Session objectives and success criteria
- **State Preservation**: System state snapshot creation
- **Context Linking**: Related session and project linking

### 2. Update CLAUDE.md Documentation
- **Pattern Documentation**: Successful pattern template creation
- **Learning Capture**: Knowledge and insight documentation
- **Best Practices**: Proven approach documentation
- **Configuration Updates**: Environment and setup improvements

### 3. Generate Workflow Runbooks
- **Operational Guides**: Step-by-step operational procedures
- **Troubleshooting Guides**: Problem resolution documentation
- **Deployment Procedures**: Release and deployment workflows
- **Emergency Procedures**: Incident response and recovery guides

### 4. Create Pattern Templates
- **Code Patterns**: Reusable code templates and examples
- **Workflow Patterns**: Process and workflow templates
- **Configuration Patterns**: Setup and configuration templates
- **Testing Patterns**: Test strategy and implementation templates

### 5. Log Improvement Hypotheses
- **Hypothesis Documentation**: Improvement theory documentation
- **Experiment Design**: Testing and validation methodology
- **Results Tracking**: Outcome measurement and analysis
- **Learning Synthesis**: Knowledge extraction and application

### 6. Session Summary & Handoff
- **Achievement Summary**: Session accomplishment documentation
- **Knowledge Transfer**: Key learning and insight transfer
- **Continuation Planning**: Next session preparation and context
- **Handoff Documentation**: Agent transition preparation

## Memory Management Features

### 1. Context Preservation
```yaml
session_context:
  id: "session_timestamp"
  agent_role: "current_agent_role"
  objectives: ["session_goals"]
  achievements: ["completed_tasks"]
  challenges: ["encountered_issues"]
  learnings: ["key_insights"]
  next_steps: ["planned_actions"]
```

### 2. Knowledge Capture
- **Pattern Recognition**: Successful approach identification
- **Anti-Pattern Documentation**: Failed approach documentation
- **Decision Rationale**: Decision-making process documentation
- **Context Dependencies**: Environmental factor documentation

### 3. Documentation Synthesis
- **Automated Documentation**: AI-powered documentation generation
- **Knowledge Organization**: Structured information organization
- **Search Optimization**: Searchable knowledge base creation
- **Version Control**: Documentation version management

### 4. Learning Integration
- **Feedback Loops**: Continuous learning integration
- **Performance Analysis**: Success factor identification
- **Improvement Identification**: Enhancement opportunity recognition
- **Knowledge Application**: Learning-based recommendation generation

## Runbook Categories

### 1. Development Runbooks
- **Setup Procedures**: Development environment setup
- **Testing Procedures**: Test execution and validation
- **Debugging Procedures**: Problem diagnosis and resolution
- **Code Review Procedures**: Quality assurance processes

### 2. Deployment Runbooks
- **Release Procedures**: Software release and deployment
- **Environment Management**: Environment setup and configuration
- **Monitoring Setup**: Performance and health monitoring
- **Rollback Procedures**: Deployment rollback and recovery

### 3. Operational Runbooks
- **Maintenance Procedures**: Routine maintenance tasks
- **Backup Procedures**: Data backup and recovery
- **Security Procedures**: Security monitoring and response
- **Performance Optimization**: System optimization procedures

### 4. Emergency Runbooks
- **Incident Response**: Emergency situation response
- **Recovery Procedures**: System recovery and restoration
- **Communication Plans**: Stakeholder communication protocols
- **Escalation Procedures**: Issue escalation and management

## Usage Examples
```bash
/project:memory-session                           # Interactive mode selection
/project:memory-session context                 # Create session context
/project:memory-session documentation           # Update CLAUDE.md
/project:memory-session runbook                 # Generate workflow runbook
/project:memory-session patterns                # Create pattern templates
/project:memory-session hypothesis              # Log improvement hypothesis
/project:memory-session handoff                 # Prepare session handoff
```

## Integration Features
- **CLAUDE.md Integration**: Direct CLAUDE.md file updates
- **Session Continuity**: Cross-session knowledge preservation
- **Agent Coordination**: Multi-agent knowledge sharing
- **Project Memory**: Long-term project knowledge management
- **Searchable Knowledge**: AI-powered knowledge retrieval