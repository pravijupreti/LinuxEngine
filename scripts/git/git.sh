#!/bin/bash
# git/git.sh - Main Git Auto-Push Script
# Usage: ./git/git.sh [manual|window_closed]

set -e

# Get the directory where this script is located (git folder)
GIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules from the same directory
source "$GIT_DIR/config.sh"
source "$GIT_DIR/permissions.sh"
source "$GIT_DIR/git_ops.sh"
source "$GIT_DIR/utils.sh"

# ==================== MAIN EXECUTION ====================

main() {
    # Get trigger reason
    local trigger_reason="${1:-manual}"
    
    # Validate trigger
    if [[ "$trigger_reason" != "window_closed" && "$trigger_reason" != "manual" ]]; then
        print_warning "This script should only be called when browser window closes or manually"
        echo "Exiting..."
        exit 0
    fi
    
    print_header "Git Auto-Push for Jupyter Notebooks"
    echo "Workspace: $(pwd)"
    echo "Git Dir: $GIT_DIR"
    echo "Trigger: $trigger_reason - backing up your work..."
    echo ""
    
    # Create logs directory in git folder
    mkdir -p "$GIT_DIR/logs"
    
    # Fix all permission issues
    fix_all_permissions "$(pwd)"
    
    # Load configuration (from git folder)
    load_config "$GIT_DIR"
    
    # Setup git repository
    setup_git_repo
    
    # Setup remote
    setup_remote "$GITHUB_REPO"
    
    # Commit and push changes
    commit_and_push_changes "$CURRENT_BRANCH"
    
    # Show final status
    show_final_status
    
    print_success "Git auto-push process completed!"
    
    # Log completion
    echo "[$(date)] Git auto-push completed for $(pwd)" >> "$GIT_DIR/logs/git.log"
}

# Run main function with all arguments
main "$@"