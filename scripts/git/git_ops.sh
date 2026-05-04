#!/bin/bash
# git/git_ops.sh - Core Git operations

# Setup git repository
setup_git_repo() {
    if [ ! -d ".git" ]; then
        print_info "Initializing git repository..."
        git init
        
        # Create initial .gitignore
        fix_gitignore "$(pwd)"
        
        # Initial commit
        git add .
        git commit -m "Initial commit from Jupyter workspace" || true
        print_success "Git repository initialized"
        return
    fi
    
    # Check current branch status
    check_branch_status
}

# Check and fix branch status
check_branch_status() {
    # Check for uncommitted changes first
    if [ -n "$(git status --porcelain 2>/dev/null | grep -v 'Trash' || true)" ]; then
        print_warning "Uncommitted changes detected. Will handle them in commit phase."
        return
    fi
    
    # Check if we're in detached HEAD state
    if ! git symbolic-ref HEAD >/dev/null 2>&1; then
        fix_detached_head
    else
        # We're on a branch, get its name
        local current_branch_name=$(git symbolic-ref --short HEAD 2>/dev/null || echo "unknown")
        print_success "On branch: $current_branch_name"
        
        # If on a different branch than configured
        if [ "$current_branch_name" != "$CURRENT_BRANCH" ] && [ "$current_branch_name" != "unknown" ]; then
            switch_to_branch "$CURRENT_BRANCH"
        fi
    fi
}

# Fix detached HEAD state
fix_detached_head() {
    print_warning "Detached HEAD state detected. Fixing..."
    
    # Get the current commit hash
    local current_commit=$(git rev-parse HEAD)
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$CURRENT_BRANCH"; then
        print_info "Branch '$CURRENT_BRANCH' exists. Switching to it..."
        git checkout "$CURRENT_BRANCH"
        
        # Check if the detached commit is already in the branch
        if ! git merge-base --is-ancestor "$current_commit" "$CURRENT_BRANCH" 2>/dev/null; then
            print_info "The detached commit is not in the branch. Cherry-picking..."
            git cherry-pick "$current_commit" || print_warning "Cherry-pick failed, but continuing..."
        fi
    else
        print_info "Creating branch '$CURRENT_BRANCH' from detached HEAD..."
        git branch "$CURRENT_BRANCH" "$current_commit"
        git checkout "$CURRENT_BRANCH"
    fi
    
    print_success "Now on branch: $CURRENT_BRANCH"
}

# Switch to a branch
switch_to_branch() {
    local branch="$1"
    
    print_info "Switching to configured branch: $branch"
    
    # Stash any uncommitted changes if needed
    if [ -n "$(git status --porcelain 2>/dev/null || true)" ]; then
        print_info "Stashing uncommitted changes before switching branches..."
        git stash push -m "auto-stash before branch switch"
        git checkout "$branch"
        git stash pop || true
    else
        # Check if configured branch exists locally
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            git checkout "$branch"
        else
            # Create the branch from current HEAD
            git checkout -b "$branch"
        fi
    fi
    
    print_success "Switched to branch: $branch"
}

# Setup remote repository
setup_remote() {
    local repo_url="$1"
    
    if [ -z "$repo_url" ]; then
        return 0
    fi
    
    # Check if remote exists
    if git remote | grep -q origin; then
        local current_remote=$(git remote get-url origin 2>/dev/null)
        if [ "$current_remote" != "$repo_url" ]; then
            print_info "Updating remote URL..."
            git remote set-url origin "$repo_url"
        fi
    else
        print_info "Adding remote origin: $repo_url"
        git remote add origin "$repo_url"
    fi
}

# Commit and push changes
commit_and_push_changes() {
    local branch="$1"
    
    print_info "Checking for changes..."
    
    # Show current git state
    show_git_state
    
    # Ensure we're on the correct branch
    ensure_correct_branch "$branch"
    
    # Get changes with retry
    local changes=$(get_changes_with_retry)
    
    # Commit changes if any
    if [ -n "$changes" ]; then
        commit_changes "$changes"
    fi
    
    # Push changes
    push_changes "$branch"
}

# Show current git state
show_git_state() {
    echo -e "\n${CYAN}=== CURRENT GIT STATE ===${NC}"
    echo "Current directory: $(pwd)"
    echo "Current branch: $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo "Remote URL: $(git remote get-url origin 2>/dev/null || echo 'No remote')"
    echo "Git status:"
    git status --short 2>/dev/null | grep -v "Trash" || echo "  No changes"
    echo -e "${CYAN}=========================${NC}\n"
}

# Ensure we're on the correct branch
ensure_correct_branch() {
    local branch="$1"
    local current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
    
    if [ "$current_branch" = "detached" ]; then
        print_warning "Still in detached HEAD. Fixing..."
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            git checkout "$branch"
        else
            git checkout -b "$branch"
        fi
    elif [ "$current_branch" != "$branch" ]; then
        print_info "Switching to branch $branch before push..."
        git checkout "$branch"
    fi
}

# Get changes with retry on lock
get_changes_with_retry() {
    local max_retries=3
    local retry_count=0
    local changes=""
    
    while [ $retry_count -lt $max_retries ]; do
        changes=$(git status --porcelain 2>/dev/null | grep -v "Trash" || echo "")
        
        if [ -n "$changes" ] || [ "$changes" = "" ]; then
            break
        fi
        
        print_warning "Git is locked. Waiting 2 seconds... (Attempt $((retry_count+1))/$max_retries)"
        sleep 2
        retry_count=$((retry_count + 1))
        
        # Fix permissions on retry
        fix_git_permissions "$(pwd)"
    done
    
    echo "$changes"
}

# Commit changes
commit_changes() {
    local changes="$1"
    
    echo -e "${GREEN}📝 Changes detected:${NC}"
    echo "$changes" | while read line; do
        echo "  $line"
    done
    
    # Add all changes
    git add . 2>/dev/null || true
    
    # Create commit with timestamp
    local commit_msg="Auto-commit: Notebook work saved on $(date '+%Y-%m-%d %H:%M:%S')"
    if git commit -m "$commit_msg" 2>/dev/null; then
        echo -e "${GREEN}✅ Changes committed${NC}"
        echo "  Commit hash: $(git rev-parse HEAD)"
        echo "  Commit message: $commit_msg"
    else
        echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    fi
}

# Push changes to remote
push_changes() {
    local branch="$1"
    
    # Check if remote exists
    if ! git remote | grep -q origin; then
        echo -e "${YELLOW}⚠️  No remote repository configured. Commit saved locally.${NC}"
        return 0
    fi
    
    echo -e "\n${CYAN}=== PUSH OPERATION ===${NC}"
    echo "Pushing to GitHub ($branch)..."
    
    # Check if there are unpushed commits
    check_unpushed_commits "$branch"
    
    # Determine push command
    local push_cmd=$(get_push_command "$branch")
    
    echo "Running: $push_cmd"
    echo ""
    
    # Execute push
    execute_push "$push_cmd" "$branch"
    
    echo -e "${CYAN}=========================${NC}\n"
}

# Check for unpushed commits
check_unpushed_commits() {
    local branch="$1"
    
    local unpushed=$(git log @{u}.. 2>/dev/null || echo "NO_UPSTREAM")
    
    if [ "$unpushed" = "NO_UPSTREAM" ]; then
        echo "No upstream branch configured. Will set upstream on push."
    elif [ -z "$unpushed" ]; then
        echo "No unpushed commits found. Checking if remote is ahead..."
        
        # Check if remote has commits we don't have
        git fetch origin "$branch" 2>/dev/null || true
        local remote_commits=$(git log ..origin/"$branch" 2>/dev/null || echo "")
        
        if [ -n "$remote_commits" ]; then
            echo -e "${YELLOW}⚠️  Remote has commits not in local:${NC}"
            echo "$remote_commits"
            echo "Run: git pull origin $branch --rebase"
        fi
    else
        echo -e "${GREEN}📤 Unpushed commits:${NC}"
        echo "$unpushed"
    fi
}

# Get push command
get_push_command() {
    local branch="$1"
    
    # Check if remote branch exists
    if git ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
        echo "Remote branch '$branch' exists."
        
        # Check if we need to pull first
        git fetch origin "$branch" 2>/dev/null || true
        local behind=$(git rev-list --count HEAD..origin/"$branch" 2>/dev/null || echo "0")
        
        if [ "$behind" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  Local branch is behind remote by $behind commits. Pulling first...${NC}"
            git pull --rebase origin "$branch" || echo "Pull failed, but continuing..."
        fi
        
        echo "git push origin $branch"
    else
        echo "Remote branch '$branch' does not exist. Will create it."
        echo "git push -u origin $branch"
    fi
}

# Execute push command
execute_push() {
    local push_cmd="$1"
    local branch="$2"
    
    # Execute push command and capture output
    local push_output
    local push_exit_code
    
    push_output=$(eval "$push_cmd" 2>&1)
    push_exit_code=$?
    
    echo "$push_output"
    echo ""
    
    if [ $push_exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ SUCCESS: Changes pushed to GitHub${NC}"
        verify_push "$branch"
    else
        echo -e "${RED}❌ FAILED: Could not push to GitHub${NC}"
        echo ""
        echo "Possible issues:"
        echo "  1. Authentication failed - need to login to GitHub"
        echo "  2. Remote has changes you need to pull first"
        echo "  3. Branch protection rules on GitHub"
        echo ""
        echo "Try manually:"
        echo "  git pull origin $branch --rebase"
        echo "  $push_cmd"
    fi
}

# Verify push was successful
verify_push() {
    local branch="$1"
    
    git fetch origin "$branch" 2>/dev/null || true
    local local_hash=$(git rev-parse HEAD)
    local remote_hash=$(git rev-parse origin/"$branch" 2>/dev/null || echo "")
    
    if [ "$local_hash" = "$remote_hash" ]; then
        echo -e "${GREEN}✓ Verified: Local and remote are in sync${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Local and remote may not be in sync${NC}"
    fi
}

# Show final status
show_final_status() {
    echo -e "\n${BLUE}=== FINAL GIT STATUS ===${NC}"
    echo "Current branch: $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo ""
    echo "Git status:"
    git status --short 2>/dev/null | grep -v "Trash" || echo "No git repo"
    
    echo ""
    echo "Last commit:"
    git log --oneline -1 2>/dev/null || echo "No commits yet"
    
    echo ""
    echo "Remote URL:"
    git remote -v 2>/dev/null || echo "No remote"
    
    echo ""
    echo "Unpushed commits:"
    if git status 2>/dev/null | grep -q "Your branch is ahead"; then
        git log @{u}.. 2>/dev/null || echo "No upstream branch"
    else
        echo "None - everything is pushed"
    fi
    echo -e "${BLUE}=========================${NC}"
}