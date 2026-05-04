#!/usr/bin/env python3
"""
Setup privileges for Jupyter Manager
Run this once to configure Polkit and permissions
"""

import os
import sys
import subprocess
import grp
import pwd

class PrivilegeSetup:
    """Automatically configure Polkit and permissions"""
    
    def __init__(self):
        self.username = pwd.getpwuid(os.getuid()).pw_name
        
    def run(self):
        """Run all setup steps"""
        print("🔧 Setting up privileges for Jupyter Manager...")
        
        # Check if already configured
        if self.is_configured():
            print("✅ Privileges already configured")
            return True
        
        # Run setup steps
        steps = [
            self.add_to_docker_group,
            self.create_polkit_policy,
            self.create_wrappers,
            self.fix_file_permissions,
            self.configure_docker_socket
        ]
        
        for step in steps:
            if not step():
                print(f"❌ Failed: {step.__name__}")
                return False
        
        print("\n✅ Setup complete! Please log out and log back in.")
        print("   Then restart Jupyter Manager.")
        return True
    
    def is_configured(self):
        """Check if already configured"""
        # Check if user is in docker group
        try:
            user_groups = [g.gr_name for g in grp.getgrall() if self.username in g.gr_mem]
            if 'docker' in user_groups:
                return True
        except:
            pass
        return False
    
    def add_to_docker_group(self):
        """Add user to docker group"""
        print("📦 Adding user to docker group...")
        try:
            subprocess.run(['sudo', 'usermod', '-aG', 'docker', self.username], 
                          check=True, capture_output=True)
            print("   ✅ Added to docker group (requires logout)")
            return True
        except Exception as e:
            print(f"   ❌ Failed: {e}")
            return False
    
    def create_polkit_policy(self):
        """Create Polkit policy file"""
        print("📜 Creating Polkit policy...")
        
        policy_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="com.jupyter.docker">
    <description>Run Docker containers for Jupyter</description>
    <message>Authentication is required to run Docker containers</message>
    <defaults>
      <allow_any>auth_admin_keep</allow_any>
      <allow_inactive>auth_admin_keep</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/bin/docker</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>

  <action id="com.jupyter.containerd">
    <description>Run containerd for Docker</description>
    <message>Authentication is required to manage containers</message>
    <defaults>
      <allow_any>auth_admin_keep</allow_any>
      <allow_inactive>auth_admin_keep</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/bin/containerd</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>

  <action id="com.jupyter.nvidia">
    <description>Configure NVIDIA Container Toolkit</description>
    <message>Authentication is required to configure NVIDIA</message>
    <defaults>
      <allow_any>auth_admin_keep</allow_any>
      <allow_inactive>auth_admin_keep</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/bin/nvidia-ctk</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>'''
        
        try:
            # Write policy file
            with open('/tmp/com.jupyter.policy', 'w') as f:
                f.write(policy_content)
            
            subprocess.run(['sudo', 'cp', '/tmp/com.jupyter.policy', 
                          '/usr/share/polkit-1/actions/'], check=True)
            subprocess.run(['sudo', 'chmod', '644', 
                          '/usr/share/polkit-1/actions/com.jupyter.policy'], check=True)
            print("   ✅ Polkit policy created")
            return True
        except Exception as e:
            print(f"   ❌ Failed: {e}")
            return False
    
    def create_wrappers(self):
        """Create privilege wrapper scripts"""
        print("🔧 Creating wrapper scripts...")
        
        # Docker wrapper
        docker_wrapper = '''#!/bin/bash
# Auto-generated wrapper for Docker
if [ "$1" = "ps" ] || [ "$1" = "images" ] || [ "$1" = "info" ] || [ "$1" = "version" ]; then
    /usr/bin/docker "$@"
else
    /usr/bin/pkexec /usr/bin/docker "$@"
fi
'''
        
        try:
            # Create wrapper
            with open('/tmp/docker-wrapper', 'w') as f:
                f.write(docker_wrapper)
            
            subprocess.run(['sudo', 'cp', '/tmp/docker-wrapper', '/usr/local/bin/docker'], check=True)
            subprocess.run(['sudo', 'chmod', '755', '/usr/local/bin/docker'], check=True)
            print("   ✅ Wrapper scripts created")
            return True
        except Exception as e:
            print(f"   ❌ Failed: {e}")
            return False
    
    def fix_file_permissions(self):
        """Fix file permissions for user directories"""
        print("📁 Fixing file permissions...")
        
        # Get current directory
        current_dir = os.getcwd()
        
        try:
            # Fix ownership of current directory
            subprocess.run(['sudo', 'chown', '-R', f'{self.username}:{self.username}', 
                          current_dir], check=True, capture_output=True)
            
            # Fix .git directory if exists
            git_dir = os.path.join(current_dir, '.git')
            if os.path.exists(git_dir):
                subprocess.run(['sudo', 'chown', '-R', f'{self.username}:{self.username}', 
                              git_dir], check=True, capture_output=True)
            
            print("   ✅ File permissions fixed")
            return True
        except Exception as e:
            print(f"   ⚠️  Warning: {e}")
            return True  # Non-critical, continue
    
    def configure_docker_socket(self):
        """Configure Docker socket permissions"""
        print("🔌 Configuring Docker socket...")
        
        try:
            # Check if docker socket is accessible
            result = subprocess.run(['docker', 'ps'], capture_output=True)
            if result.returncode == 0:
                print("   ✅ Docker already accessible")
                return True
            
            # Fix socket permissions
            subprocess.run(['sudo', 'chmod', '666', '/var/run/docker.sock'], 
                          check=True, capture_output=True)
            print("   ✅ Docker socket configured")
            return True
        except Exception as e:
            print(f"   ⚠️  Warning: {e}")
            return True  # Non-critical, continue


def main():
    """Main entry point"""
    if os.geteuid() == 0:
        print("❌ Please don't run this script with sudo")
        print("   Run as normal user: python3 setup_privileges.py")
        sys.exit(1)
    
    setup = PrivilegeSetup()
    if setup.run():
        print("\n" + "="*50)
        print("⚠️  IMPORTANT: Please log out and log back in")
        print("   Then restart Jupyter Manager")
        print("="*50)
    else:
        print("\n❌ Setup failed. Please run manually:")
        print("   sudo usermod -aG docker $USER")
        print("   Then log out and back in")


if __name__ == "__main__":
    main()