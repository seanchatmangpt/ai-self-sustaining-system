#!/bin/bash
# S2S Dynamic Environment Detection (80/20 implementation)
# Provides environment-agnostic path resolution

# Detect S2S project root dynamically
detect_s2s_root() {
    local current="$PWD"
    local max_depth=10
    local depth=0
    
    while [[ "$current" != "/" && $depth -lt $max_depth ]]; do
        # Look for S2S project markers
        if [[ -f "$current/CLAUDE.md" && -d "$current/agent_coordination" ]]; then
            echo "$current"
            return 0
        fi
        
        # Alternative markers
        if [[ -f "$current/beamops/v3/README.md" ]] || [[ -d "$current/beamops" ]]; then
            echo "$current"
            return 0
        fi
        
        current="$(dirname "$current")"
        ((depth++))
    done
    
    # Fallback to common locations
    for fallback in "/Users/sac/dev/ai-self-sustaining-system" "$HOME/ai-self-sustaining-system" "./"; do
        if [[ -d "$fallback/agent_coordination" ]]; then
            echo "$fallback"
            return 0
        fi
    done
    
    # Last resort - use current directory
    echo "$PWD"
    return 1
}

# Get coordination directory dynamically
get_coordination_dir() {
    local root="$(detect_s2s_root)"
    local coord_dir="$root/agent_coordination"
    
    # Verify coordination directory exists
    if [[ -d "$coord_dir" ]]; then
        echo "$coord_dir"
    else
        # Look for coordination directory in current path
        local current_coord="$(dirname "${BASH_SOURCE[0]}")"
        if [[ -f "$current_coord/coordination_helper.sh" ]]; then
            echo "$current_coord"
        else
            echo "$root/agent_coordination"  # Best guess
        fi
    fi
}

# Get project-relative path
get_project_path() {
    local target_path="$1"
    local root="$(detect_s2s_root)"
    echo "$root/$target_path"
}

# Export environment variables for use in other scripts
export_s2s_env() {
    export S2S_ROOT="$(detect_s2s_root)"
    export COORDINATION_DIR="$(get_coordination_dir)"
    export PROJECT_ROOT="$S2S_ROOT"
}

# Auto-export when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export_s2s_env
fi
