Monitor pending work and inter-agent communications for coordination opportunities.

Analysis target: $ARGUMENTS (optional: specific process ID or agent role)

Coordination Analysis:
1. **Current Agent Assignments**: 
   - Read `.claude_role_assignment` to show active agents
   - Display current role, session ID, and activation time
   - Identify your current role and session

2. **APS Process Status Scan**:
   - Find all `*.aps.yaml` files
   - Check each for handoff opportunities:
     * `requirements_complete` → Ready for Architect_Agent
     * `architecture_complete` → Ready for Developer_Agent  
     * `implementation_complete` → Ready for QA_Agent
     * `testing_complete` → Ready for DevOps_Agent
     * `blocked` → Needs Developer_Agent support

3. **Message Review**:
   - Check `.agent_message_log` for recent inter-agent communications
   - Scan APS files for unread messages targeted to your role
   - Show message count and subjects

4. **Role-Specific Recommendations**: Provide guidance based on your agent role:
   - PM_Agent: Look for new processes needing requirements
   - Architect_Agent: Check for completed requirements
   - Developer_Agent: Find architecture ready for implementation or blocked processes
   - QA_Agent: Locate completed implementations for testing
   - DevOps_Agent: Find tested features ready for deployment

5. **Swarm Health Status**:
   - Count active agents, total processes, completed processes
   - Identify coordination bottlenecks
   - Report pending handoffs and blocked work

6. **Action Recommendations**: Suggest next steps for maintaining workflow momentum

Follow coordination protocols from CLAUDE.md sections 8-9.