#!/usr/bin/env python3
"""
Polkit Setup - Automatic privilege configuration for Jupyter Manager
"""

import os
import subprocess
import sys
from pathlib import Path


class PolkitSetup:
    """Handle automatic Polkit and privilege configuration"""
    
    def __init__(self):
        self.policy_path = Path("/usr/share/polkit-1/actions/com.docker.policy")
        self.docker_group = "docker"
        
    def is_configured(self):
        """Check if Polkit is already configured"""
        return self.policy_path.exists()
    
    def check_docker_group(self):
        """Check if user is in docker group"""
        try:
            result = subprocess.run(['groups'], capture_output=True, text=True)
            return 'docker' in result.stdout
        except:
            return False
    
    def setup_polkit(self):
        """Setup Polkit policy (requires pkexec)"""
        policy_content = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="com.docker.admin">
    <description>Run Docker containers for Jupyter Notebook</description>
    <message>Authentication is required to run Docker containers</message>
    <defaults>
      <allow_any>auth_admin_keep</allow_any>
      <allow_inactive>auth_admin_keep</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/bin/docker</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>'''
        
        # Write to temp file
        temp_file = "/tmp/com.docker.policy"
        with open(temp_file, 'w') as f:
            f.write(policy_content)
        
        # Copy to system location using pkexec (will show GUI password dialog)
        try:
            result = subprocess.run(
                ['pkexec', 'cp', temp_file, str(self.policy_path)],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            print(f"Polkit setup failed: {e}")
            return False
    
    def add_to_docker_group(self):
        """Add current user to docker group (requires pkexec)"""
        username = os.environ.get('USER', os.getlogin())
        
        try:
            result = subprocess.run(
                ['pkexec', 'usermod', '-aG', self.docker_group, username],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            print(f"Failed to add to docker group: {e}")
            return False
    
    def setup_docker_socket(self):
        """Fix docker socket permissions if needed"""
        try:
            # Check if docker works without sudo
            result = subprocess.run(['docker', 'ps'], capture_output=True)
            if result.returncode == 0:
                return True
            
            # Fix socket permissions
            subprocess.run(
                ['pkexec', 'chmod', '666', '/var/run/docker.sock'],
                capture_output=True
            )
            return True
        except:
            return False
    
    def run_full_setup(self, parent_widget=None):
        """Run complete privilege setup"""
        
        # Check if already configured
        if self.is_configured() and self.check_docker_group():
            return True
        
        # Show dialog if parent widget provided
        if parent_widget:
            from PyQt5.QtWidgets import QMessageBox
            
            msg = QMessageBox(parent_widget)
            msg.setIcon(QMessageBox.Question)
            msg.setWindowTitle("Privilege Setup Required")
            msg.setText("Jupyter Manager needs to configure system privileges")
            msg.setInformativeText(
                "This one-time setup will:\n\n"
                "• Configure Polkit for Docker access\n"
                "• Add your user to the docker group\n"
                "• Fix Docker socket permissions\n\n"
                "You will be prompted for your password once.\n"
                "After setup, please restart the application."
            )
            msg.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
            
            if msg.exec_() != QMessageBox.Yes:
                return False
        
        # Run setup steps
        success = True
        
        if not self.is_configured():
            if not self.setup_polkit():
                success = False
        
        if not self.check_docker_group():
            if not self.add_to_docker_group():
                success = False
        
        self.setup_docker_socket()
        
        if success and parent_widget:
            from PyQt5.QtWidgets import QMessageBox
            QMessageBox.information(
                parent_widget,
                "Setup Complete",
                "Privileges have been configured.\n"
                "Please log out and log back in for changes to take effect,\n"
                "then restart Jupyter Manager."
            )
        
        return success


# Standalone run for testing
if __name__ == "__main__":
    setup = PolkitSetup()
    
    if not setup.is_configured() or not setup.check_docker_group():
        print("Running Polkit setup...")
        if setup.run_full_setup():
            print("Setup complete! Please log out and log back in.")
        else:
            print("Setup failed. Please run manually: sudo usermod -aG docker $USER")
    else:
        print("Polkit already configured!")