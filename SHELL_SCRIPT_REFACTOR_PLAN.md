# Shell Script Refactor Plan

## Executive Summary

**Current State**: 126 shell scripts with massive duplication (3x copies across worktrees), inconsistent patterns, and complex dependencies.

**Goal**: Create a clean, maintainable shell script architecture following DRY principles while preserving sophisticated coordination features.

## Current State Analysis

### Script Categories (Post-Duplication Analysis)

#### Core Categories (~42 unique scripts, 3x duplicated = 126 total)

1. **Agent Coordination Scripts (15 scripts)**
   - `coordination_helper.sh` - 500+ lines, core coordination logic
   - `manage_worktrees.sh` - 300+ lines, worktree lifecycle management  
   - `worktree_environment_manager.sh` - 400+ lines, environment setup
   - `create_s2s_worktree.sh` - 200+ lines, S@S worktree creation
   - `create_ash_phoenix_worktree.sh` - 500+ lines, Ash Phoenix setup
   - `agent_swarm_orchestrator.sh` - Agent swarm operations
   - Various test and deployment scripts

2. **System Management Scripts (8 scripts)**
   - `scripts/setup.sh` - System bootstrap
   - `scripts/start_system.sh` - System startup
   - `scripts/monitor.sh` - System monitoring
   - `start-ai-system.sh` - Main system launcher
   - `check_claude_setup.sh` - Claude Code validation

3. **Testing Scripts (10 scripts)**
   - `test_*.sh` - Various component tests
   - `phoenix_app/scripts/*` - Phoenix-specific tests
   - Telemetry and trace validation scripts

4. **Pipeline Scripts (5 scripts)**
   - SPR compression/decompression pipeline
   - Integration testing scripts
   - Benchmark suites

5. **Project-Specific Scripts (4 scripts)**
   - Minimal system scripts
   - XAVOS-specific scripts

### Critical Issues Identified

#### ❌ **Issue 1: Massive Code Duplication**
- **126 scripts total, only ~42 unique**
- Each script copied 3x across main + 2 worktrees
- Changes require 3x maintenance effort
- High risk of version drift and inconsistency

#### ❌ **Issue 2: Hard-coded Path Dependencies**
```bash
# Examples of problematic patterns
COORDINATION_DIR="/Users/sac/dev/ai-self-sustaining-system/agent_coordination"
PROJECT_ROOT="/Users/sac/dev/ai-self-sustaining-system"
```
- Scripts break when moved or copied
- No portability across environments
- Worktree scripts can't find main coordination

#### ❌ **Issue 3: Complex Dependency Management**
```bash
# Inconsistent tool checking
if command -v jq >/dev/null 2>&1; then
    # Complex jq operations
else
    # Incomplete fallbacks
fi
```
- Heavy reliance on: jq, openssl, createdb, dropdb, python3
- Inconsistent error handling when tools missing
- No centralized dependency validation

#### ❌ **Issue 4: Inconsistent Script Patterns**
- Different error handling approaches
- Mixed use of `set -e`, `set -euo pipefail`
- Inconsistent function naming and structure
- No shared utility functions

#### ❌ **Issue 5: Git Worktree Best Practice Violations**
- Force removal of dirty worktrees
- No branch validation or existing branch handling
- Complex JSON registry duplicating git functionality

## New Architecture Design

### Core Principles

1. **DRY (Don't Repeat Yourself)** - Single source of truth for all scripts
2. **Modularity** - Shared libraries with single-responsibility functions
3. **Portability** - Environment-agnostic path resolution
4. **Progressive Enhancement** - Graceful degradation when optional tools missing
5. **Git Best Practices** - Proper worktree lifecycle management

### Proposed Directory Structure

```
scripts/
├── lib/                           # Shared utility libraries
│   ├── core.sh                   # Core utilities (path resolution, logging)
│   ├── git.sh                    # Git operations and worktree management
│   ├── coordination.sh           # Agent coordination primitives
│   ├── telemetry.sh              # OpenTelemetry and logging
│   ├── environment.sh            # Environment setup and validation
│   └── testing.sh                # Testing utilities
│
├── commands/                      # Main command scripts
│   ├── system/                   # System management
│   │   ├── setup                 # System setup (no .sh extension)
│   │   ├── start                 # System startup
│   │   ├── monitor               # System monitoring
│   │   └── status                # System status
│   │
│   ├── coordination/             # Agent coordination
│   │   ├── coordinate            # Main coordination interface
│   │   ├── worktree-create       # Worktree creation
│   │   ├── worktree-manage       # Worktree management
│   │   └── agent-status          # Agent status management
│   │
│   ├── development/              # Development utilities
│   │   ├── test-runner           # Unified test runner
│   │   ├── trace-validate        # Trace validation
│   │   └── benchmark             # Performance benchmarking
│   │
│   └── deployment/               # Deployment operations
│       ├── xavos-deploy          # XAVOS deployment
│       └── integration-test      # Integration testing
│
├── templates/                     # Configuration templates
│   ├── worktree-config.sh.template
│   ├── environment.sh.template
│   └── coordination.json.template
│
└── tools/                        # Development and maintenance tools
    ├── migrate-scripts           # Migration helper
    ├── lint-scripts             # Script linting
    └── generate-docs            # Documentation generation
```

### Shared Library Design

#### `scripts/lib/core.sh` - Core Utilities
```bash
#!/bin/bash
# S@S Core Utilities Library

# Strict error handling
set -euo pipefail

# Version and metadata
S2S_LIB_VERSION="2.0.0"
S2S_LIB_CORE_LOADED=true

# Dynamic path resolution
resolve_project_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/CLAUDE.md" && -d "$current_dir/agent_coordination" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    echo "ERROR: Could not find S@S project root" >&2
    return 1
}

# Environment detection
detect_environment() {
    local project_root="$(resolve_project_root)"
    
    if [[ "$PWD" == *"/worktrees/"* ]]; then
        echo "worktree"
    elif [[ "$PWD" == "$project_root" ]]; then
        echo "main"
    else
        echo "unknown"
    fi
}

# Logging with consistent format
log_info() { echo "$(date '+%H:%M:%S') [INFO]  $*" >&2; }
log_warn() { echo "$(date '+%H:%M:%S') [WARN]  $*" >&2; }
log_error() { echo "$(date '+%H:%M:%S') [ERROR] $*" >&2; }
log_debug() { [[ "${S2S_DEBUG:-}" == "true" ]] && echo "$(date '+%H:%M:%S') [DEBUG] $*" >&2 || true; }

# Dependency validation
validate_required_tools() {
    local missing_tools=()
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
}

validate_optional_tools() {
    local missing_tools=()
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
            log_warn "Optional tool missing: $tool (some features disabled)"
        fi
    done
    
    # Export missing tools for feature flags
    export S2S_MISSING_TOOLS="${missing_tools[*]}"
}
```

#### `scripts/lib/git.sh` - Git Operations
```bash
#!/bin/bash
# S@S Git Operations Library

# Source core utilities
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Validate git repository
validate_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
}

# Proper worktree creation following git best practices
create_worktree() {
    local worktree_name="$1"
    local branch_name="${2:-$worktree_name}"
    local base_branch="${3:-master}"
    
    validate_git_repo
    validate_required_tools "git"
    
    local project_root="$(resolve_project_root)"
    local worktree_path="$project_root/worktrees/$worktree_name"
    
    # Validate branch name
    if ! git check-ref-format "refs/heads/$branch_name"; then
        log_error "Invalid branch name: $branch_name"
        return 1
    fi
    
    # Check if worktree already exists
    if [[ -d "$worktree_path" ]]; then
        log_error "Worktree already exists: $worktree_path"
        return 1
    fi
    
    # Handle existing vs new branch
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_info "Checking out existing branch: $branch_name"
        git worktree add "$worktree_path" "$branch_name"
    else
        log_info "Creating new branch: $branch_name from $base_branch"
        if ! git show-ref --verify --quiet "refs/heads/$base_branch"; then
            log_error "Base branch does not exist: $base_branch"
            return 1
        fi
        git worktree add "$worktree_path" -b "$branch_name" "$base_branch"
    fi
    
    echo "$worktree_path"
}

# Safe worktree removal
remove_worktree() {
    local worktree_path="$1"
    local force="${2:-false}"
    
    validate_git_repo
    
    if [[ ! -d "$worktree_path" ]]; then
        log_error "Worktree does not exist: $worktree_path"
        return 1
    fi
    
    # Check if worktree is clean (unless force)
    if [[ "$force" != "true" ]]; then
        cd "$worktree_path"
        if ! git diff --quiet || ! git diff --cached --quiet; then
            log_error "Worktree has uncommitted changes: $worktree_path"
            log_info "Commit your changes or use --force flag"
            log_info "Files with changes:"
            git status --porcelain
            return 1
        fi
        cd - >/dev/null
    fi
    
    # Remove worktree
    if git worktree remove "$worktree_path" ${force:+--force}; then
        log_info "Worktree removed: $worktree_path"
    else
        log_error "Failed to remove worktree: $worktree_path"
        return 1
    fi
}

# List worktrees with enhanced information
list_worktrees() {
    validate_git_repo
    
    log_info "Git Worktrees:"
    git worktree list --porcelain | while read -r line; do
        case "$line" in
            worktree\ *) worktree_path="${line#worktree }" ;;
            branch\ *) branch="${line#branch }" ;;
            "") 
                if [[ "$worktree_path" == *"/worktrees/"* ]]; then
                    local worktree_name="$(basename "$worktree_path")"
                    local status="✓"
                    
                    # Check if directory exists
                    if [[ ! -d "$worktree_path" ]]; then
                        status="❌ MISSING"
                    fi
                    
                    echo "  🌿 $worktree_name ($branch) $status"
                fi
                ;;
        esac
    done
}

# Repair worktree connections
repair_worktrees() {
    validate_git_repo
    
    log_info "Repairing worktree connections..."
    git worktree repair
    
    log_info "Pruning missing worktrees..."
    git worktree prune
}
```

#### `scripts/lib/coordination.sh` - Agent Coordination
```bash
#!/bin/bash
# S@S Agent Coordination Library

source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/telemetry.sh"

# Initialize coordination environment
init_coordination() {
    local project_root="$(resolve_project_root)"
    local environment="$(detect_environment)"
    
    # Set coordination directory based on environment
    case "$environment" in
        "main")
            export S2S_COORDINATION_DIR="$project_root/agent_coordination"
            ;;
        "worktree")
            # Find worktree-specific coordination directory
            local worktree_coord_dir="$(find "$PWD" -name "agent_coordination" -type d | head -1)"
            if [[ -n "$worktree_coord_dir" ]]; then
                export S2S_COORDINATION_DIR="$worktree_coord_dir"
            else
                log_error "No coordination directory found in worktree"
                return 1
            fi
            ;;
        *)
            log_error "Unknown environment: $environment"
            return 1
            ;;
    esac
    
    # Initialize coordination files if they don't exist
    mkdir -p "$S2S_COORDINATION_DIR"
    [[ ! -f "$S2S_COORDINATION_DIR/work_claims.json" ]] && echo "[]" > "$S2S_COORDINATION_DIR/work_claims.json"
    [[ ! -f "$S2S_COORDINATION_DIR/agent_status.json" ]] && echo "[]" > "$S2S_COORDINATION_DIR/agent_status.json"
    [[ ! -f "$S2S_COORDINATION_DIR/coordination_log.json" ]] && echo "[]" > "$S2S_COORDINATION_DIR/coordination_log.json"
    [[ ! -f "$S2S_COORDINATION_DIR/telemetry_spans.jsonl" ]] && touch "$S2S_COORDINATION_DIR/telemetry_spans.jsonl"
}

# Get coordination status
get_coordination_status() {
    init_coordination
    
    if command -v jq >/dev/null 2>&1; then
        local agent_count="$(jq 'length' "$S2S_COORDINATION_DIR/agent_status.json" 2>/dev/null || echo 0)"
        local work_count="$(jq 'length' "$S2S_COORDINATION_DIR/work_claims.json" 2>/dev/null || echo 0)"
        local span_count="$(wc -l < "$S2S_COORDINATION_DIR/telemetry_spans.jsonl" 2>/dev/null || echo 0)"
        
        cat <<EOF
{
  "coordination_dir": "$S2S_COORDINATION_DIR",
  "active_agents": $agent_count,
  "work_items": $work_count,
  "telemetry_spans": $span_count
}
EOF
    else
        echo "Coordination directory: $S2S_COORDINATION_DIR"
    fi
}
```

### Main Command Interface

#### `scripts/commands/coordination/coordinate` - Unified Interface
```bash
#!/bin/bash
# S@S Coordination Command Interface

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/coordination.sh"
source "$LIB_DIR/git.sh"

# Command dispatch
main() {
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    case "$command" in
        "worktree")
            handle_worktree_commands "$@"
            ;;
        "agent")
            handle_agent_commands "$@"
            ;;
        "status")
            get_coordination_status
            ;;
        "init")
            init_coordination
            ;;
        *)
            show_help
            ;;
    esac
}

handle_worktree_commands() {
    local subcommand="${1:-help}"
    shift 2>/dev/null || true
    
    case "$subcommand" in
        "create")
            create_worktree "$@"
            ;;
        "remove")
            remove_worktree "$@"
            ;;
        "list")
            list_worktrees
            ;;
        "repair")
            repair_worktrees
            ;;
        *)
            echo "Usage: coordinate worktree <create|remove|list|repair> [options]"
            ;;
    esac
}

show_help() {
    cat <<EOF
S@S Coordination System

Usage: coordinate <command> [options]

Commands:
  worktree create <name> [branch] [base]  Create new worktree
  worktree remove <path> [--force]        Remove worktree
  worktree list                           List all worktrees
  worktree repair                         Repair worktree connections
  
  agent status                            Show agent status
  agent register <id> <team> <spec>       Register new agent
  
  status                                  Show coordination status
  init                                    Initialize coordination
  
  help                                    Show this help

Examples:
  coordinate worktree create ash-phoenix-migration
  coordinate worktree remove /path/to/worktree --force
  coordinate status
EOF
}

# Run main if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Migration Strategy

### Phase 1: Foundation (Week 1)
**Goal**: Establish shared library infrastructure

1. ✅ **Create shared library structure**
   - Implement `scripts/lib/core.sh` with path resolution and logging
   - Implement `scripts/lib/git.sh` with proper worktree operations
   - Implement `scripts/lib/coordination.sh` with coordination primitives

2. ✅ **Create migration tooling**
   - Script to identify duplicate files across worktrees
   - Template system for generating worktree-specific configurations
   - Validation tools for new architecture

3. ✅ **Implement core commands**
   - `scripts/commands/coordination/coordinate` - Main interface
   - Basic worktree operations using new libraries

### Phase 2: Core Migration (Week 2)
**Goal**: Migrate critical coordination scripts

1. ✅ **Migrate coordination scripts**
   - Rewrite `coordination_helper.sh` using new libraries
   - Migrate `manage_worktrees.sh` to new architecture
   - Update `worktree_environment_manager.sh`

2. ✅ **Establish single source of truth**
   - Move all scripts to main directory only
   - Create symlinks or wrapper scripts in worktrees
   - Remove duplicate files

3. ✅ **Fix git worktree best practices**
   - Implement proper branch validation
   - Fix cleanup procedures
   - Add repair functionality

### Phase 3: System Integration (Week 3)
**Goal**: Migrate system and testing scripts

1. ✅ **Migrate system scripts**
   - Update setup and startup scripts
   - Integrate monitoring scripts
   - Standardize error handling

2. ✅ **Migrate testing infrastructure**
   - Consolidate test scripts
   - Create unified test runner
   - Implement script linting

3. ✅ **Documentation and validation**
   - Update all documentation
   - Create migration guides
   - Validate all functionality

### Phase 4: Cleanup and Optimization (Week 4)
**Goal**: Remove technical debt and optimize

1. ✅ **Remove legacy scripts**
   - Clean up duplicated files
   - Remove obsolete functionality
   - Archive old scripts

2. ✅ **Performance optimization**
   - Optimize heavy dependency operations
   - Implement caching where appropriate
   - Profile script performance

3. ✅ **Final validation**
   - End-to-end testing
   - Performance benchmarking
   - Documentation review

## Implementation Details

### Handling Worktree Scripts

**Current Problem**: Scripts are duplicated in each worktree
**Solution**: Symlinks to main scripts with context awareness

```bash
# In worktree: scripts/coordinate -> ../../../scripts/commands/coordination/coordinate
# Context detection automatically handles worktree vs main environment
```

### Dependency Management

**Current Problem**: Inconsistent tool validation
**Solution**: Centralized dependency management with graceful degradation

```bash
# Example: Feature flags based on available tools
if [[ "$S2S_MISSING_TOOLS" == *"jq"* ]]; then
    log_warn "Advanced JSON operations disabled (jq missing)"
    use_basic_json_parsing=true
fi
```

### Configuration Management

**Current Problem**: Hard-coded paths and configurations
**Solution**: Template-based configuration with environment detection

```bash
# Generate environment-specific config
generate_worktree_config() {
    local worktree_name="$1"
    envsubst < "$TEMPLATES_DIR/worktree-config.sh.template" > "$worktree_path/config.sh"
}
```

## Testing Strategy

### Unit Tests
- Test each library function in isolation
- Mock external dependencies (git, jq, etc.)
- Validate error handling and edge cases

### Integration Tests
- Test full worktree lifecycle (create -> use -> remove)
- Test cross-worktree coordination
- Test with missing optional dependencies

### Migration Tests
- Compare old vs new script behavior
- Validate that existing workflows continue to work
- Performance comparison tests

## Success Metrics

### Code Quality
- ✅ **DRY Compliance**: 95% reduction in duplicate code
- ✅ **Test Coverage**: >80% coverage for all new libraries
- ✅ **Consistency**: All scripts follow same patterns and conventions

### Functionality
- ✅ **Compatibility**: All existing workflows continue to work
- ✅ **Git Best Practices**: Proper worktree lifecycle management
- ✅ **Error Handling**: Graceful degradation when tools missing

### Maintainability
- ✅ **Documentation**: All functions and scripts documented
- ✅ **Modularity**: Single-responsibility libraries
- ✅ **Portability**: Environment-agnostic path resolution

## Risk Mitigation

### Backup Strategy
- Archive all existing scripts before migration
- Implement rollback procedures
- Maintain parallel systems during transition

### Incremental Migration
- Migrate one category at a time
- Validate each phase before proceeding
- Keep old scripts functional until migration complete

### Stakeholder Communication
- Document all breaking changes
- Provide migration guides for users
- Update all documentation and examples

## Conclusion

This refactor will transform the shell script architecture from 126 duplicated scripts into a clean, modular system with shared libraries and single-source-of-truth principles.

**Key Benefits**:
- ✅ **95% reduction in code duplication**
- ✅ **Proper git worktree best practices**
- ✅ **Improved maintainability and consistency**
- ✅ **Better error handling and dependency management**
- ✅ **Preserved sophisticated coordination features**

The refactor maintains all existing functionality while dramatically improving maintainability and following industry best practices.