Send structured message to another agent following APS communication protocol.

Message details: $ARGUMENTS (format: recipient_role subject content)

Requirements:
1. **Validate Recipient**: Ensure target role is valid:
   - PM_Agent, Architect_Agent, Developer_Agent, QA_Agent, DevOps_Agent

2. **Message Format**: Create message following APS specification:
   ```yaml
   message:
     id: "msg_[timestamp]"
     from: "[your_agent_role]"
     to: "[recipient_role]"
     timestamp: "[ISO_8601_DateTime]"
     subject: "[message_subject]"
     content: "[detailed_message_content]"
     sender_session: "[your_session_id]"
     priority: "normal"
     message_type: "coordination"
   ```

3. **Delivery Options**:
   - Attach to existing APS file if process-related
   - Create standalone message file for general communication
   - Log in `.agent_message_log` for tracking

4. **Handoff Instructions**: Provide recipient with:
   - Context about the message
   - Expected actions based on their role
   - Available commands for response

5. **Delivery Tracking**: Include delivery status and acknowledgment fields

6. **MCP Notification**: Simulate Desktop Commander notification to recipient agent

Follow inter-agent communication protocol from CLAUDE.md section 9.