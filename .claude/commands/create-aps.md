Create a new APS (Agile Protocol Specification) process for agent coordination.

Generate a structured APS YAML file for the process: $ARGUMENTS

Requirements:
1. **Process Structure**: Create complete APS YAML with:
   - Unique process ID (sequential: 001, 002, etc.)
   - Process name and description
   - Agent roles and responsibilities (PM_Agent → Architect_Agent → Developer_Agent → QA_Agent → DevOps_Agent)
   - High-level activities with task breakdown
   - Gherkin scenario templates
   - Communication data structures

2. **Workflow State Machine**: Include all process states:
   - initialized → requirements_in_progress → requirements_complete
   - architecture_in_progress → architecture_complete  
   - implementation_in_progress → implementation_complete
   - testing_in_progress → testing_complete
   - deployment_in_progress → deployment_complete

3. **Coordination Metadata**: 
   - Current agent assignment
   - Next agent in pipeline
   - Handoff conditions
   - Progress tracking
   - Message log placeholder

4. **File Naming**: Use format `[ID]_[Process_Name].aps.yaml`

5. **Initial Status**: Set to "initialized" and ready for PM_Agent to begin requirements analysis

Follow the APS YAML structure exactly as defined in CLAUDE.md section 2.