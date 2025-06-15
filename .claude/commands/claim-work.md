Claim specific APS process for work to prevent conflicts between parallel agents.

Target process: $ARGUMENTS

Steps:
1. **List Available Processes**: Show all `*.aps.yaml` files with:
   - Process name and current status
   - Currently assigned agent (if any)
   - Availability (claimed/unclaimed)

2. **Validate Selection**: Ensure the process is appropriate for your current agent role:
   - PM_Agent: Can claim "initialized" processes
   - Architect_Agent: Can claim "requirements_complete" processes  
   - Developer_Agent: Can claim "architecture_complete" or "blocked" processes
   - QA_Agent: Can claim "implementation_complete" processes
   - DevOps_Agent: Can claim "testing_complete" processes

3. **Check for Conflicts**: Verify no other agent has active claim on the same process

4. **Add Claim Information**: Update APS file with:
   ```yaml
   claim:
     claimed_by: "[session_id]"
     agent_role: "[your_role]"
     claimed_at: "[ISO_timestamp]"
     estimated_completion: "[estimated_time]"
     status: "claimed"
   ```

5. **Provide Task Guidance**: Show role-specific tasks and next steps based on the process status

6. **Update Assignment**: Record claim in `.claude_role_assignment` system

Follow work claiming protocol from CLAUDE.md section 8 to ensure proper coordination.