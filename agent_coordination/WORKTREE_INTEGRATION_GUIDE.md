# S@S Worktree Integration Guide

## Overview

The S@S (Scrum at Scale) coordination system now supports Git worktrees for running parallel Claude Code sessions with complete isolation. This enables simultaneous development on multiple features, including the Ash Phoenix migration.

## Architecture

### Directory Structure
```
/Users/sac/dev/ai-self-sustaining-system/
├── agent_coordination/           # Main S@S coordination
├── phoenix_app/                  # Current Phoenix app (master branch)
├── worktrees/                    # Isolated worktrees
│   ├── ash-phoenix-migration/    # Ash Phoenix rewrite
│   ├── feature-n8n-v2/          # N8n improvements
│   └── performance-optimization/ # Performance work
└── shared_coordination/          # Cross-worktree coordination
    ├── worktree_registry.json    # Active worktrees
    ├── cross_worktree_locks.json # Resource locks
    └── shared_telemetry.jsonl    # Unified telemetry
```

### Key Components

1. **Isolated Agent Coordination**: Each worktree has its own coordination system
2. **Cross-Worktree Communication**: Shared coordination prevents conflicts
3. **Unified Telemetry**: All worktrees report to shared OpenTelemetry collector
4. **Branch-Specific Work Claims**: Work items tagged with worktree context

## Shell Scripts

### 1. `create_s2s_worktree.sh`
Creates new worktrees with full S@S coordination setup.

```bash
# Basic worktree creation
./create_s2s_worktree.sh feature-name

# With specific branch and base
./create_s2s_worktree.sh feature-name custom-branch master
```

**Features:**
- Creates Git worktree with new branch
- Sets up isolated agent coordination
- Initializes telemetry tracking
- Registers in shared coordination system
- Generates OpenTelemetry trace context

### 2. `manage_worktrees.sh`
Manages, monitors, and cleans up worktrees.

```bash
# List all worktrees and status
./manage_worktrees.sh list

# Show detailed status of specific worktree
./manage_worktrees.sh status ash-phoenix-migration

# Mark worktree for cleanup
./manage_worktrees.sh remove feature-name

# Clean up marked worktrees
./manage_worktrees.sh cleanup

# Show cross-worktree coordination
./manage_worktrees.sh cross
```

### 3. `create_ash_phoenix_worktree.sh`
Specialized script for Ash Phoenix migration.

```bash
# Create Ash Phoenix migration worktree
./create_ash_phoenix_worktree.sh
```

**Features:**
- Creates dedicated worktree for Ash Phoenix
- Generates new Phoenix project with Ash integration
- Copies original app files for reference
- Creates migration plan and instructions
- Sets up Ash resources and domains
- Provides migration scripts and helpers

## Workflows

### Creating Ash Phoenix Migration Worktree

1. **Create the worktree:**
   ```bash
   cd agent_coordination
   ./create_ash_phoenix_worktree.sh
   ```

2. **Navigate to the project:**
   ```bash
   cd ../worktrees/ash-phoenix-migration/self_sustaining_ash
   ```

3. **Manual setup (required):**
   - Edit `apps/self_sustaining_ash/mix.exs` (add Ash dependencies)
   - Update database configuration in `config/dev.exs`

4. **Install and setup:**
   ```bash
   mix deps.get
   mix ecto.setup
   ```

5. **Start Claude Code in isolation:**
   ```bash
   claude
   ```

### Parallel Development Workflow

1. **Create multiple worktrees for different features:**
   ```bash
   ./create_s2s_worktree.sh n8n-improvements
   ./create_s2s_worktree.sh performance-boost
   ./create_ash_phoenix_worktree.sh
   ```

2. **Start Claude in each worktree:**
   ```bash
   # Terminal 1
   cd worktrees/n8n-improvements && claude
   
   # Terminal 2  
   cd worktrees/performance-boost && claude
   
   # Terminal 3
   cd worktrees/ash-phoenix-migration/self_sustaining_ash && claude
   ```

3. **Monitor coordination across worktrees:**
   ```bash
   ./manage_worktrees.sh list
   ./manage_worktrees.sh cross
   ```

## S@S Coordination Features

### Isolated Agent Coordination
Each worktree maintains its own:
- `work_claims.json` - Work items specific to the worktree
- `agent_status.json` - Agents working in this worktree
- `coordination_log.json` - Completion history
- `telemetry_spans.jsonl` - Telemetry data

### Cross-Worktree Coordination
Shared coordination prevents:
- Resource conflicts between worktrees
- Duplicate work across teams
- Telemetry data loss
- Agent assignment conflicts

### OpenTelemetry Integration
- **Unified Tracing**: All worktrees use correlated trace IDs
- **Cross-Worktree Spans**: Operations span multiple worktrees
- **Shared Telemetry**: Consolidated telemetry pipeline
- **Performance Monitoring**: Compare performance across worktrees

## Ash Phoenix Migration Strategy

### Phase 1: Foundation (High Priority)
- Create Ash domains for core business logic
- Set up Ash resources for existing Ecto schemas  
- Configure Ash Phoenix integration
- Migrate basic CRUD operations

### Phase 2: Workflow Orchestration (High Priority)
- Migrate Reactor workflows to Ash actions
- Integrate agent coordination with Ash resources
- Port telemetry middleware to Ash hooks
- Migrate N8n integration workflows

### Phase 3: Advanced Features (Medium Priority)
- Migrate AI/ML components to Ash AI
- Port self-improvement orchestrator
- Migrate performance monitoring
- Integrate OpenTelemetry with Ash

### Phase 4: Web Interface (Medium Priority)
- Migrate LiveView components
- Update controllers to use Ash actions
- Migrate authentication system
- Port dashboard functionality

### Phase 5: Integrations (Low Priority)
- Port Livebook integration
- Migrate Claude Code integration
- Update deployment configurations
- Migrate test suites

## Key Benefits

### 1. Complete Isolation
- Each Claude instance works in isolated environment
- No interference between parallel development
- Independent file states and Git history

### 2. Coordinated Development
- S@S coordination prevents conflicts
- Shared telemetry for unified monitoring
- Cross-worktree communication protocols

### 3. Flexible Workflows
- Multiple features developed simultaneously
- Easy switching between development contexts
- Isolated testing and experimentation

### 4. Migration Safety
- Original app remains untouched during migration
- Incremental migration with rollback capability
- Parallel testing and validation

## Usage Examples

### Start Ash Phoenix Migration
```bash
# Create and set up Ash Phoenix worktree
./create_ash_phoenix_worktree.sh

# Navigate and start development
cd ../worktrees/ash-phoenix-migration/self_sustaining_ash
claude
```

### Monitor All Worktrees
```bash
# List active worktrees
./manage_worktrees.sh list

# Check specific worktree status
./manage_worktrees.sh status ash-phoenix-migration

# View cross-worktree coordination
./manage_worktrees.sh cross
```

### Cleanup Completed Work
```bash
# Mark worktree for removal
./manage_worktrees.sh remove completed-feature

# Clean up all marked worktrees
./manage_worktrees.sh cleanup
```

## Integration with Existing S@S System

The worktree system integrates seamlessly with:
- **Agent Coordination**: Nanosecond agent IDs with worktree context
- **Work Claims**: Atomic work claiming across worktrees
- **Telemetry**: OpenTelemetry traces span worktrees
- **Quality Gates**: Elixir toolchain works in each worktree
- **Claude Commands**: All existing `/project:*` commands work

## Success Criteria

- ✅ Complete isolation between Claude instances
- ✅ S@S coordination across worktrees
- ✅ OpenTelemetry trace correlation
- ✅ Ash Phoenix project generation
- ✅ Migration plan and resources
- ✅ Shell script automation
- ✅ Cross-worktree monitoring

## Next Steps

1. **Run the Ash Phoenix migration:**
   ```bash
   ./create_ash_phoenix_worktree.sh
   ```

2. **Start parallel Claude sessions:**
   - One in the Ash Phoenix worktree
   - One in the main development branch
   - Additional worktrees for specific features

3. **Monitor and coordinate:**
   - Use `manage_worktrees.sh` for oversight
   - Track progress through S@S coordination
   - Validate migration through testing

The S@S worktree integration is now ready for production use with complete agent coordination, telemetry, and parallel development capabilities.