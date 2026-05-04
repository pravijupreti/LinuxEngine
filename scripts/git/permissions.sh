#!/bin/bash
# git/permissions.sh - Fix permission and lock issues

# Fix all permission issues (main function)
fix_all_permissions() {
    local workspace="$1"
    
    fix_safe_directory "$workspace"
    fix_git_permissions "$workspace"
    fix_gitignore "$workspace"
    fix_trash_issues "$workspace"
}

# Fix Git safe.directory issue
fix_safe_directory() {
    local dir="$1"
    
    # Check if we need to add this directory to safe.directory
    if ! git config --global --get-all safe.directory 2>/dev/null | grep -q "^$dir$"; then
        print_info "Adding $dir to Git safe.directory..."
        git config --global --add safe.directory "$dir"
        print_success "Directory added to safe list"
    fi
}

# Fix .git directory permissions
fix_git_permissions() {
    local git_dir="$1/.git"
    
    # Check if .git directory exists
    if [ ! -d "$git_dir" ]; then
        return 0
    fi
    
    print_info "Checking git permissions..."
    
    # Fix ownership if needed (skip if not possible)
    if [ "$(stat -c '%U' "$git_dir" 2>/dev/null)" != "$USER" ]; then
        print_info "Fixing .git directory ownership..."
        chown -R "$USER":"$USER" "$git_dir" 2>/dev/null || true
    fi
    
    # Remove stale lock files
    remove_stale_locks "$git_dir"
    
    # Fix file permissions
    fix_file_permissions "$git_dir"
}

# Remove stale lock files
remove_stale_locks() {
    local git_dir="$1"
    
    local lock_patterns=(
        "$git_dir/index.lock"
        "$git_dir/HEAD.lock"
        "$git_dir/refs/heads/*.lock"
        "$git_dir/refs/tags/*.lock"
        "$git_dir/refs/remotes/*/*.lock"
    )
    
    for lock_pattern in "${lock_patterns[@]}"; do
        # Use find to handle wildcards safely
        find "$git_dir" -path "$lock_pattern" -type f 2>/dev/null | while read -r lock_file; do
            if [ -f "$lock_file" ]; then
                # Check if lock is stale (older than 5 minutes)
                lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_file") ))
                if [ $lock_age -gt 300 ]; then
                    print_info "Removing stale lock file: $lock_file"
                    rm -f "$lock_file"
                else
                    # Check if any git process is actually running
                    if ! pgrep -f "git" > /dev/null; then
                        print_info "No git process found. Removing stale lock file: $lock_file"
                        rm -f "$lock_file"
                    fi
                fi
            fi
        done
    done
}

# Fix file permissions in .git directory
fix_file_permissions() {
    local git_dir="$1"
    
    # Fix permissions on all git files
    find "$git_dir" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find "$git_dir" -type d -exec chmod 755 {} \; 2>/dev/null || true
}

# Fix gitignore to exclude trash and system files
fix_gitignore() {
    local gitignore="$1/.gitignore"
    
    # Create .gitignore if it doesn't exist
    if [ ! -f "$gitignore" ]; then
        cat > "$gitignore" << 'EOF'
# Jupyter notebooks
.ipynb_checkpoints/
*/.ipynb_checkpoints/*
*.ipynb

# Python
__pycache__/
*.pyc
*.pyo
*.pyd

# System files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
*.swp
.*.swp
.Trash-*/
.Trash-0/

# Git config (contains sensitive info)
.jupyter_git_config

# Logs
logs/
*.log
EOF
        print_success "Created .gitignore file"
    else
        # Ensure .jupyter_git_config is in .gitignore
        if ! grep -q ".jupyter_git_config" "$gitignore" 2>/dev/null; then
            echo "" >> "$gitignore"
            echo "# Git config (contains sensitive info)" >> "$gitignore"
            echo ".jupyter_git_config" >> "$gitignore"
            print_info "Added .jupyter_git_config to .gitignore"
        fi
    fi
}

# Fix trash directory issues
fix_trash_issues() {
    local workspace="$1"
    
    # Configure git to ignore permission errors on trash
    git config --global core.sharedRepository true
    
    # Set environment to avoid permission issues
    export GIT_OPTIONAL_LOCKS=0
    export GIT_FLUSH=0
    
    # Add trash to local gitignore if not already
    if [ -f "$workspace/.git/info/exclude" ]; then
        if ! grep -q ".Trash" "$workspace/.git/info/exclude" 2>/dev/null; then
            echo ".Trash-*/" >> "$workspace/.git/info/exclude"
            echo ".Trash-0/" >> "$workspace/.git/info/exclude"
        fi
    fi
}