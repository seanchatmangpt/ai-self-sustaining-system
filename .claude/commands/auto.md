Autonomous AI agent operation: analyze system state, read all commands, think strategically, and act.

Auto operation mode: $ARGUMENTS (optional: focus area or specific objectives)

Autonomous Agent Sequence:
1. **Initialize Agent Context**:
   - Read and understand all available slash commands in `.claude/commands/`
   - Execute `/project:init-agent` to determine role and join swarm
   - Run `/project:check-handoffs` to understand current coordination state
   - Execute `/project:system-health` to assess overall system status

2. **Strategic Analysis**:
   - Analyze current system state and pending work
   - Identify critical issues requiring immediate attention
   - Evaluate opportunities for improvement and optimization
   - Assess agent swarm coordination and workflow efficiency

3. **Intelligent Decision Making**:
   - Prioritize actions based on:
     * Critical system issues (security, reliability, performance)
     * Pending agent handoffs and blocked processes
     * Enhancement opportunities with high impact/low effort
     * Strategic alignment with self-sustaining system goals

4. **Autonomous Action Execution**:
   Based on analysis, execute appropriate command sequence:

   **For Critical Issues**:
   - `/project:debug-system` to identify and resolve problems
   - `/project:system-health` to verify fixes
   - `/project:send-message` to notify relevant agents

   **For Development Work**:
   - `/project:claim-work` to take on appropriate tasks
   - `/project:tdd-cycle` for test-driven development
   - `/project:implement-enhancement` for improvements

   **For Coordination Needs**:
   - `/project:create-aps` for new processes
   - `/project:send-message` for agent communication
   - `/project:check-handoffs` for workflow management

   **For Continuous Improvement**:
   - `/project:discover-enhancements` to find opportunities
   - `/project:next-enhancement` for prioritized recommendations
   - `/project:workflow-health` for automation analysis

   **For Documentation Maintenance**:
   - Scan `.context/` folder for documentation consistency
   - Update architecture diagrams after structural changes
   - Refresh system documentation when new features are added
   - Maintain C4 diagram accuracy with current implementation

5. **Adaptive Learning**:
   - Use `/project:memory-session` to document decisions and outcomes
   - Update CLAUDE.md with learned patterns and insights
   - Create runbooks for recurring procedures
   - Log hypothesis and experimental results

6. **Context Documentation Management**:
   - Scan `.context/` folder for current documentation state
   - Analyze system changes that require documentation updates
   - Update architecture diagrams and system documentation
   - Maintain consistency between code and documentation
   - Refresh C4 diagrams when structural changes are detected

   **Context Scanning Workflow**:
   ```
   a. Read .context/index.md for current system state
   b. Scan .context/diagrams/ for architectural consistency
   c. Compare documented features with actual implementation
   d. Identify outdated or missing documentation
   e. Update relevant files in .context/ folder
   f. Refresh C4 diagrams to match current architecture
   g. Update system status and next-steps in index.md
   ```

7. **Self-Monitoring and Iteration**:
   - Continuously monitor system health and agent coordination
   - Adjust priorities based on emerging issues or opportunities
   - Maintain awareness of other agent activities and dependencies
   - Ensure actions align with APS protocol and swarm coordination

8. **INFINITE LOOP MODE - Never Stop Operation**:
   - After completing current cycle, immediately begin next cycle analysis
   - Sleep for 30 seconds between cycles to prevent resource exhaustion
   - Continuously scan for new work, issues, or optimization opportunities
   - Only stop when explicitly commanded with "STOP" or "EXIT" by user
   - Log all cycle completions with timestamp and summary
   - Maintain persistent vigilance for system improvements
   
   **Loop Termination Conditions**:
   - User explicitly types "STOP", "EXIT", "HALT", or "SHUTDOWN"
   - Critical system error that cannot be resolved autonomously
   - Explicit `/project:stop-auto` command (if implemented)
   - Maximum cycle count reached (default: 1000 cycles before requesting continuation)
   
   **Continuous Operation Protocol**:
   ```
   WHILE (not stop_requested):
     1. Complete current autonomous cycle (steps 1-7)
     2. Update cycle counter and log completion
     3. Brief system status check
     4. Sleep 30 seconds for system stability
     5. Check for stop conditions
     6. IF no stop conditions: GOTO step 1
     7. ELSE: Graceful shutdown with final status report
   ```

Decision Tree Logic (Per Cycle):
```
LOOP_START:
IF (user requested stop)
  THEN graceful shutdown with status report
ELIF (critical system issues exist)
  THEN prioritize debugging and resolution
ELIF (pending handoffs for my role exist)
  THEN claim and execute appropriate work
ELIF (blocked processes need support)
  THEN provide debugging or coordination assistance
ELIF (documentation is outdated or inconsistent)
  THEN update .context folder and architecture diagrams
ELIF (high-impact enhancements identified)
  THEN implement strategic improvements
ELIF (system optimizations available)
  THEN implement performance improvements
ELIF (no immediate work found)
  THEN discover new opportunities and optimize workflows
END_CYCLE:
  Log cycle completion
  Sleep 30 seconds
  Check stop conditions
  IF (not stop_requested): GOTO LOOP_START
  ELSE: Final status report and shutdown
```

Autonomous Principles:
- **Safety First**: Never compromise system stability or security
- **Coordination**: Always respect APS protocol and agent boundaries
- **Learning**: Document decisions and outcomes for future reference
- **Efficiency**: Focus on high-impact activities and quick wins
- **Adaptability**: Adjust approach based on changing conditions
- **Persistence**: Continue operation indefinitely until explicitly stopped
- **Resource Awareness**: Manage computational resources responsibly with sleep cycles
- **Graceful Degradation**: If no work is found, still perform maintenance and monitoring

Safeguards:
- Validate all actions against APS protocol requirements
- Ensure proper agent role permissions and boundaries
- Maintain system backup and rollback capabilities
- Monitor for unintended consequences or conflicts
- Escalate complex decisions to appropriate agents when needed

Success Metrics:
- System health improvements and issue resolution
- Enhanced agent coordination and workflow efficiency
- Successful completion of assigned tasks and handoffs
- Knowledge capture and institutional learning
- Strategic progress toward self-sustaining system goals
- Documentation accuracy and completeness in .context folder
- Architectural consistency between code and diagrams
- **Continuous Operation Uptime**: Target 99.9% autonomous operation
- **Cycle Completion Rate**: Track successful cycles per hour/day
- **Improvement Discovery Rate**: Measure enhancements identified over time
- **System Evolution Velocity**: Track rate of autonomous improvements

**Infinite Loop Termination Commands**:
Users can stop the autonomous loop with any of these commands:
- Type: `STOP`, `EXIT`, `HALT`, or `SHUTDOWN`
- Use: `/project:stop-auto` (when implemented)
- Interrupt: Ctrl+C or session termination

**Continuous Operation Log Format**:
```
[TIMESTAMP] CYCLE_#: [STATUS] - [BRIEF_SUMMARY]
[TIMESTAMP] CYCLE_1: COMPLETE - Fixed 3 warnings, updated docs
[TIMESTAMP] CYCLE_2: COMPLETE - No issues found, optimized performance
[TIMESTAMP] CYCLE_3: COMPLETE - Discovered 2 enhancements, created APS process
...
[TIMESTAMP] SHUTDOWN: GRACEFUL - User requested stop after 47 cycles
```

The autonomous mode enables **truly continuous, self-directed operation** that never stops improving the system until explicitly commanded to halt. This creates a genuinely self-sustaining AI system that operates 24/7 without human intervention while maintaining safety, coordination, and strategic alignment with the AI swarm's objectives.