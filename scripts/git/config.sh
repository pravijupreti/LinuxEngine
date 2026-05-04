#!/bin/bash
# git/config.sh - Configuration management functions

DEFAULT_BRANCH="main"

# Global variables (will be set by load_config)
GITHUB_REPO=""
CURRENT_BRANCH=""
CONFIG_FILE=""

# Load saved configuration
load_config() {
    local git_dir="$1"
    CONFIG_FILE="$git_dir/.jupyter_git_config"
    
    if [ -f "$CONFIG_FILE" ]; then
        # Source the config file safely
        source "$CONFIG_FILE"
        print_success "Loaded saved configuration"
        echo "   Repository: $GITHUB_REPO"
        echo "   Branch: $CURRENT_BRANCH"
        echo ""
        return 0
    else
        # First time setup
        first_time_setup "$git_dir"
    fi
}

# First time setup - ask for repository
first_time_setup() {
    local git_dir="$1"
    
    print_header "First Time GitHub Repository Setup"
    
    # Get repository URL
    while true; do
        read -p "Enter GitHub repository URL: " GITHUB_REPO
        if [[ -n "$GITHUB_REPO" ]]; then
            break
        fi
        print_warning "Repository URL cannot be empty"
    done
    
    # Get branch name
    read -p "Enter branch name (default: $DEFAULT_BRANCH): " new_branch
    CURRENT_BRANCH="${new_branch:-$DEFAULT_BRANCH}"
    
    # Save configuration
    save_config "$git_dir"
    
    print_success "Configuration saved to $CONFIG_FILE"
    echo ""
}

# Save configuration to file
save_config() {
    local git_dir="$1"
    CONFIG_FILE="$git_dir/.jupyter_git_config"
    
    cat > "$CONFIG_FILE" << EOF
# Jupyter Git Auto-Push Configuration
# Last updated: $(date)
GITHUB_REPO="$GITHUB_REPO"
CURRENT_BRANCH="$CURRENT_BRANCH"
EOF
    
    # Add to .gitignore if it exists
    if [ -f "$git_dir/../.gitignore" ]; then
        if ! grep -q ".jupyter_git_config" "$git_dir/../.gitignore" 2>/dev/null; then
            echo ".jupyter_git_config" >> "$git_dir/../.gitignore"
        fi
    fi
}

# Update configuration
update_config() {
    local git_dir="$1"
    local key="$2"
    local value="$3"
    
    case "$key" in
        repo)
            GITHUB_REPO="$value"
            ;;
        branch)
            CURRENT_BRANCH="$value"
            ;;
        *)
            print_warning "Unknown config key: $key"
            return 1
            ;;
    esac
    
    save_config "$git_dir"
}

# Get config value
get_config() {
    local key="$1"
    case "$key" in
        repo)
            echo "$GITHUB_REPO"
            ;;
        branch)
            echo "$CURRENT_BRANCH"
            ;;
        *)
            echo ""
            ;;
    esac
}