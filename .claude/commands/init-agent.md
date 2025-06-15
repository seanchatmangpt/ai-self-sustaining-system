Initialize AI agent role and join the swarm coordination system.

You are now joining the AI Self-Sustaining System agent swarm. Follow these steps:

1. **Read Assignment State**: Check `.claude_role_assignment` file for current agent assignments
2. **Scan for Active Work**: Look for `*.aps.yaml` files to understand current processes 
3. **Apply Role Assignment Logic**:
   - If APS files exist with `status: waiting_for_architect` → Assign `Architect_Agent`
   - If APS files exist with `status: waiting_for_developer` → Assign `Developer_Agent`  
   - If APS files exist with `status: waiting_for_qa` → Assign `QA_Agent`
   - If APS files exist with `status: waiting_for_devops` → Assign `DevOps_Agent`
   - If APS files exist with `status: blocked` → Assign `Developer_Agent` (support role)
   - If no active processes → Assign `PM_Agent` (start new process)
   - Default → Assign `Developer_Agent` (parallel support)

4. **Register Assignment**: Add your session to `.claude_role_assignment` with format:
   `[timestamp]:[assigned_role]:[session_id]:[status:active]`

5. **Announce Role**: State your assigned role, session ID, current state analysis, and readiness for tasks

Follow the APS (Agile Protocol Specification) workflow defined in CLAUDE.md. Coordinate strictly through APS YAML files and inter-agent messages.