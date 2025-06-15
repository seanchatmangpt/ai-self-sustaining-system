#!/usr/bin/env python3
"""
APS (Agile Protocol Specification) Command Demonstration
Shows how the APS slash commands would work in practice
"""

import yaml
import json
from datetime import datetime
import os

class APSCommandDemo:
    def __init__(self, base_path="/Users/sac/dev/ai-self-sustaining-system"):
        self.base_path = base_path
        self.role_file = os.path.join(base_path, ".claude_role_assignment")
        
    def aps_init(self):
        """Simulate /aps-init command"""
        print("🤖 Initializing APS Agent System...")
        
        # Read current assignments
        try:
            with open(self.role_file, 'r') as f:
                content = f.read()
            print(f"✓ Read role assignment file")
        except FileNotFoundError:
            print("⚠️  Role assignment file not found")
            return
        
        # Scan for APS files
        aps_files = [f for f in os.listdir(self.base_path) if f.endswith('.aps.yaml')]
        print(f"✓ Found {len(aps_files)} APS files: {aps_files}")
        
        # Apply role assignment logic
        if not aps_files:
            role = "PM_Agent"
            reason = "No active processes found"
        else:
            # Check for processes needing continuation
            role = "Developer_Agent"  # Default for demo
            reason = "Active processes found, assigning Developer role"
        
        # Register assignment
        timestamp = int(datetime.now().timestamp())
        session_id = f"claude_{timestamp}"
        
        assignment = f"{timestamp}:{role}:{session_id}:active"
        
        print(f"🤖 **{role.upper()}** activated. Session ID: {timestamp}")
        print(f"Current state: {reason}")
        print(f"Assignment: {assignment}")
        print("Ready for tasks.")
        
        return role, session_id
    
    def aps_start(self, process_name):
        """Simulate /aps-start command"""
        print(f"🚀 Starting new APS process: {process_name}")
        
        process_id = f"001_{process_name.replace(' ', '_')}"
        filename = f"{process_id}_requirements.aps.yaml"
        
        # Load template
        with open(os.path.join(self.base_path, "aps_template.yaml"), 'r') as f:
            template = yaml.safe_load(f)
        
        # Customize template
        template['process']['name'] = process_name
        template['process']['id'] = process_id
        template['process']['created_at'] = datetime.now().isoformat() + 'Z'
        template['process']['status'] = "requirements_gathering"
        
        # Write new process file
        output_path = os.path.join(self.base_path, filename)
        with open(output_path, 'w') as f:
            yaml.dump(template, f, default_flow_style=False, indent=2)
        
        print(f"✓ Created {filename}")
        print(f"✓ Process ID: {process_id}")
        print(f"✓ Status: requirements_gathering")
        
        return process_id, filename
    
    def aps_handoff(self, process_id, target_role):
        """Simulate /aps-handoff command"""
        print(f"🔄 Handing off {process_id} to {target_role}")
        
        # Find the process file
        aps_files = [f for f in os.listdir(self.base_path) if f.startswith(process_id) and f.endswith('.aps.yaml')]
        
        if not aps_files:
            print(f"❌ No APS file found for process {process_id}")
            return
        
        filename = aps_files[0]
        filepath = os.path.join(self.base_path, filename)
        
        # Update the file
        with open(filepath, 'r') as f:
            process_data = yaml.safe_load(f)
        
        # Add handoff message
        new_message = {
            'from': 'Current_Agent',
            'to': target_role,
            'timestamp': datetime.now().isoformat() + 'Z',
            'subject': f'Handoff for {process_id}',
            'content': f'Process ready for {target_role} to begin work',
            'artifacts': [{'path': filename, 'type': 'handoff', 'status': 'ready'}]
        }
        
        if 'messages' not in process_data['process']:
            process_data['process']['messages'] = []
        
        process_data['process']['messages'].append(new_message)
        process_data['process']['status'] = f"waiting_for_{target_role.lower()}"
        process_data['process']['updated_at'] = datetime.now().isoformat() + 'Z'
        
        # Write back
        with open(filepath, 'w') as f:
            yaml.dump(process_data, f, default_flow_style=False, indent=2)
        
        print(f"✓ Updated {filename}")
        print(f"✓ Status: waiting_for_{target_role.lower()}")
        print(f"✓ Message sent to {target_role}")
    
    def aps_status(self):
        """Simulate /aps-status command"""
        print("📊 APS System Status")
        print("=" * 50)
        
        # Read role assignments
        try:
            with open(self.role_file, 'r') as f:
                lines = f.readlines()
            
            active_agents = []
            for line in lines:
                if ':' in line and 'active' in line:
                    parts = line.strip().split(':')
                    if len(parts) >= 4:
                        timestamp, role, session, status = parts[:4]
                        active_agents.append((role, session, status))
        except:
            active_agents = []
        
        print(f"Active Agents: {len(active_agents)}")
        for role, session, status in active_agents:
            print(f"  • {role} ({session}): {status}")
        
        # Scan APS files
        aps_files = [f for f in os.listdir(self.base_path) if f.endswith('.aps.yaml')]
        print(f"\nActive Processes: {len(aps_files)}")
        
        for filename in aps_files:
            try:
                with open(os.path.join(self.base_path, filename), 'r') as f:
                    data = yaml.safe_load(f)
                process_name = data['process']['name']
                # Check if status exists, otherwise infer from claim
                if 'status' in data['process']:
                    process_status = data['process']['status']
                elif 'claim' in data and 'status' in data['claim']:
                    process_status = data['claim']['status']
                else:
                    process_status = "unknown"
                print(f"  • {process_name}: {process_status}")
            except Exception as e:
                print(f"  • {filename}: (parse error: {str(e)})")

def main():
    """Demonstrate APS commands"""
    demo = APSCommandDemo()
    
    print("APS Command System Demonstration")
    print("=" * 40)
    
    # Initialize agent
    role, session = demo.aps_init()
    
    print("\n")
    
    # Start a new process (if PM_Agent)
    if role == "PM_Agent":
        process_id, filename = demo.aps_start("User Authentication System")
        print("\n")
        
        # Hand off to architect
        demo.aps_handoff(process_id, "Architect_Agent")
        print("\n")
    
    # Show current status
    demo.aps_status()

if __name__ == "__main__":
    main()