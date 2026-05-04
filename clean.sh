cd ~/Desktop/Script

# First, ignore the .Trash-0 directory (it's a system trash folder)
export SED_OPTIONS="--follow-symlinks"

# Fix jupyter_manager.py - remove sudo from the git_fix_permissions function
sed -i 's/sudo chown/chown/g' jupyter_manager.py

# Fix git/permissions.sh
sed -i 's/sudo chown/chown/g' scripts/git/permissions.sh

# Fix jupyter_notebook.sh - remove USE_SUDO line and all sudo references
sed -i 's/USE_SUDO="sudo"/USE_SUDO=""/g' scripts/jupyter_notebook.sh
sed -i 's/sudo //g' scripts/jupyter_notebook.sh

# Fix run.sh - replace with proper version (no sudo)
cat > run.sh << 'EOF'
#!/bin/bash
# run.sh - Run Jupyter Manager normally (Polkit handles privileges)

cd "$(dirname "$0")"
python3 jupyter_manager.py
EOF

# Remove the checkpoint files (they're backups, not needed)
rm -rf .ipynb_checkpoints/

# Fix any remaining sudo in git_auto_push.sh
sed -i 's/sudo //g' scripts/git_auto_push.sh

# Fix launch_jupyter_gpu.sh
sed -i 's/sudo //g' scripts/launch_jupyter_gpu.sh
sed -i 's/DOCKER_CMD="sudo docker"/DOCKER_CMD="docker"/g' scripts/launch_jupyter_gpu.sh