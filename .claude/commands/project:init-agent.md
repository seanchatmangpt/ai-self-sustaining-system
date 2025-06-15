# Enterprise Agent Initialization & Scrum Team Assignment

**Purpose**: Generate nanosecond-precision agent ID and assign to optimal Scrum at Scale team based on current PI objectives and sprint capacity.

```bash
/project:init-agent [team_preference]
```

## Enterprise Scrum at Scale Features
- **Nanosecond Agent ID**: Mathematically unique agent identification
- **PI Context Awareness**: Understands current Program Increment and sprint status
- **Team Capacity Planning**: Assigns based on team velocity and sprint commitments
- **ART Coordination**: Integrates with Agile Release Train structure
- **YAML-First Configuration**: All coordination data stored in YAML format

## Agent ID Generation (Automatic)
```bash
# Generate mathematically unique nanosecond-based agent ID
AGENT_ID="agent_$(date +%s%N)"  # Example: agent_1749970490597398000
export AGENT_ID

# Determine current PI and Sprint context
CURRENT_PI="PI_$(date +%Y)_Q$(($(date +%-m-1)/3+1))"
CURRENT_SPRINT="sprint_$(date +%Y)_$(date +%U)"
export CURRENT_PI CURRENT_SPRINT
```

## Scrum at Scale Team Assignment Logic
1. **Check Current PI Objectives**: Analyze `agent_coordination/backlog.yaml` for PI priorities
2. **Assess Team Capacity**: Review sprint commitments and current velocity
3. **Evaluate Agent Skills**: Match agent capabilities with team needs
4. **Assign to Optimal Team**:
   - `coordination_team`: Agent coordination and process optimization
   - `development_team`: Feature implementation and quality assurance
   - `platform_team`: Infrastructure and architectural governance
   - `autonomous_team`: Multi-role agent for cross-team support

## Team Assignment Criteria
```yaml
team_assignment_logic:
  coordination_team:
    when: "High coordination needs OR Scrum Master role required"
    capacity: 40
    focus: "Process optimization and agent coordination"
    
  development_team:
    when: "Feature development work OR Developer role needed"
    capacity: 45
    focus: "Sprint goal achievement and feature delivery"
    
  platform_team:
    when: "Infrastructure work OR DevOps/Architecture role needed"
    capacity: 35
    focus: "Technical governance and system reliability"
    
  autonomous_team:
    when: "Multi-role support OR cross-team coordination needed"
    capacity: 100
    focus: "Flexible support across all ART teams"
```

## Enterprise Implementation Sequence

### 1. Agent Registration with Nanosecond Precision
```bash
# Generate unique agent identity
AGENT_ID="agent_$(date +%s%N)"
AGENT_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Register in YAML coordination system
register_agent_in_art() {
    yq eval '.agents["'$AGENT_ID'"] = {
        "agent_id": "'$AGENT_ID'",
        "registered_at": "'$AGENT_TIMESTAMP'",
        "status": "initializing",
        "pi": "'$CURRENT_PI'",
        "sprint": "'$CURRENT_SPRINT'"
    }' -i agent_coordination/agent_status.yaml
}
```

### 2. PI and Sprint Context Analysis
```bash
# Analyze current Program Increment objectives
analyze_pi_context() {
    current_pi_objectives=$(yq eval '.program_increments["'$CURRENT_PI'"].objectives' agent_coordination/backlog.yaml)
    sprint_commitments=$(yq eval '.current_sprint.team_commitments' agent_coordination/backlog.yaml)
    
    # Determine highest priority work areas
    priority_work=$(yq eval '.current_sprint.high_priority_areas[]' agent_coordination/backlog.yaml)
}
```

### 3. Team Capacity and Velocity Assessment
```bash
# Check team capacity and current velocity
assess_team_capacity() {
    for team in coordination_team development_team platform_team; do
        current_capacity=$(yq eval '.teams[] | select(.name == "'$team'") | .current_capacity' agent_coordination/backlog.yaml)
        committed_work=$(yq eval '.teams[] | select(.name == "'$team'") | .sprint_commitment' agent_coordination/backlog.yaml)
        
        # Calculate available capacity for new agent
        available_capacity=$((current_capacity - committed_work))
        echo "Team: $team, Available: $available_capacity"
    done
}
```

### 4. Optimal Team Assignment
```bash
# Assign to team with highest need and available capacity
assign_to_optimal_team() {
    if [ "$coordination_needs" == "high" ] && [ "$coordination_capacity" -gt 0 ]; then
        AGENT_TEAM="coordination_team"
        AGENT_ROLE="Scrum_Master_Agent"
    elif [ "$development_needs" == "high" ] && [ "$development_capacity" -gt 0 ]; then
        AGENT_TEAM="development_team"
        AGENT_ROLE="Developer_Agent"
    elif [ "$platform_needs" == "high" ] && [ "$platform_capacity" -gt 0 ]; then
        AGENT_TEAM="platform_team"
        AGENT_ROLE="DevOps_Agent"
    else
        AGENT_TEAM="autonomous_team"
        AGENT_ROLE="MultiRole_Agent"
    fi
    
    # Register team assignment in YAML
    yq eval '.agents["'$AGENT_ID'"].team = "'$AGENT_TEAM'"' -i agent_coordination/agent_status.yaml
    yq eval '.agents["'$AGENT_ID'"].role = "'$AGENT_ROLE'"' -i agent_coordination/agent_status.yaml
}
```

### 5. ART Registration and Sprint Integration
```bash
# Register with Agile Release Train coordination
register_with_art() {
    # Update team capacity
    agent_coordination/coordination_helper.sh register_agent "$AGENT_ID" "$AGENT_TEAM" 100 "sprint_contribution"
    
    # Set agent status to active
    yq eval '.agents["'$AGENT_ID'"].status = "active"' -i agent_coordination/agent_status.yaml
    
    # Log registration in coordination log
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): Agent $AGENT_ID registered to $AGENT_TEAM as $AGENT_ROLE" >> agent_coordination/coordination_log.yaml
}
```

## Role-Specific Initialization Guidance

### Scrum_Master_Agent (coordination_team)
- **Responsibilities**: Facilitate team coordination, remove impediments, track velocity
- **Focus**: Daily Scrum facilitation, cross-team dependency resolution
- **Tools**: Sprint burndown tracking, impediment logs, team velocity optimization

### Developer_Agent (development_team)  
- **Responsibilities**: Implement features, write tests, contribute to sprint goals
- **Focus**: Story implementation, code quality, technical debt reduction
- **Tools**: TDD cycles, code review, automated testing, continuous integration

### DevOps_Agent (platform_team)
- **Responsibilities**: Infrastructure management, deployment automation, system reliability
- **Focus**: CI/CD optimization, monitoring, security, architectural governance
- **Tools**: Deployment pipelines, system monitoring, infrastructure as code

### MultiRole_Agent (autonomous_team)
- **Responsibilities**: Flexible support across all teams, cross-functional coordination
- **Focus**: Wherever highest value can be delivered to ART objectives
- **Tools**: All tools available, context-switching capabilities

## Usage Examples
```bash
/project:init-agent                    # Auto-assign to optimal team
/project:init-agent coordination_team  # Prefer coordination team
/project:init-agent development_team   # Prefer development team
/project:init-agent platform_team      # Prefer platform team
```

## Enterprise Coordination Compliance
- **Nanosecond ID Generation**: Mathematical uniqueness guarantee
- **YAML-First**: All configuration stored in YAML format
- **Team Capacity Awareness**: Respects sprint commitments and velocity
- **PI Objective Alignment**: Agent work aligns with Program Increment goals
- **ART Integration**: Full integration with Agile Release Train structure
- **Audit Trail**: Complete registration and assignment logging