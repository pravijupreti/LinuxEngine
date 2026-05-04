#!/bin/bash
# repo_manager.sh - Git repository management (clone/init/connect)
# Usage: ./repo_manager.sh {clone|init|connect|info} [args]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to show usage
show_usage() {
    echo "Usage: $0 {clone|init|connect|info} [options]"
    echo ""
    echo "Commands:"
    echo "  clone <url> [branch] [path]  - Clone existing repository"
    echo "  init <name> <url> [branch]   - Initialize new repository"
    echo "  connect <url> [branch]       - Connect local repo to remote"
    echo "  info                         - Show current repo info"
    echo ""
    echo "Examples:"
    echo "  $0 clone https://github.com/user/repo.git main"
    echo "  $0 init my-project https://github.com/user/my-project.git"
    echo "  $0 connect https://github.com/user/repo.git main"
}

# Function to clone repository
clone_repo() {
    local url="$1"
    local branch="${2:-main}"
    local path="${3:-.}"
    
    echo -e "${BLUE}📦 Cloning repository...${NC}"
    echo "   URL: $url"
    echo "   Branch: $branch"
    echo "   Path: $path"
    
    # Clone the repository
    if [ "$path" = "." ]; then
        git clone -b "$branch" "$url" .
    else
        git clone -b "$branch" "$url" "$path"
        cd "$path"
    fi
    
    echo -e "${GREEN}✅ Repository cloned successfully!${NC}"
}

# Function to initialize new repository
init_repo() {
    local name="$1"
    local url="$2"
    local branch="${3:-main}"
    
    echo -e "${BLUE}📁 Initializing new repository: $name${NC}"
    
    # Check if already a git repo
    if [ -d ".git" ]; then
        echo -e "${YELLOW}⚠️  Git repository already exists${NC}"
    else
        git init
        echo -e "${GREEN}✅ Git initialized${NC}"
    fi
    
    # Create .gitignore if not exists
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
.ipynb_checkpoints/
*/.ipynb_checkpoints/*
__pycache__/
*.pyc
.DS_Store
.env
*.log
*.tmp
data/
*.csv
*.npy
*.h5
EOF
        echo -e "${GREEN}✅ .gitignore created${NC}"
    fi
    
    # Add all files
    git add .
    
    # Commit
    git commit -m "Initial commit: $name" || echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    
    # Rename branch if needed
    current_branch=$(git branch --show-current 2>/dev/null || echo "master")
    if [ "$current_branch" != "$branch" ]; then
        git branch -M "$branch"
        echo -e "${GREEN}✅ Branch renamed to: $branch${NC}"
    fi
    
    # Add remote
    if git remote | grep -q origin; then
        git remote set-url origin "$url"
        echo -e "${GREEN}✅ Remote URL updated${NC}"
    else
        git remote add origin "$url"
        echo -e "${GREEN}✅ Remote added: $url${NC}"
    fi
    
    # Push to remote
    echo -e "${BLUE}⬆️  Pushing to remote...${NC}"
    git push -u origin "$branch"
    
    echo -e "${GREEN}✅ Repository initialized and pushed!${NC}"
}

# Function to connect local repo to remote
connect_remote() {
    local url="$1"
    local branch="${2:-main}"
    
    echo -e "${BLUE}🔗 Connecting to remote...${NC}"
    echo "   URL: $url"
    echo "   Branch: $branch"
    
    # Check if git repo exists
    if [ ! -d ".git" ]; then
        echo -e "${RED}❌ Not a git repository. Run 'git init' first.${NC}"
        exit 1
    fi
    
    # Add or update remote
    if git remote | grep -q origin; then
        git remote set-url origin "$url"
        echo -e "${GREEN}✅ Remote URL updated${NC}"
    else
        git remote add origin "$url"
        echo -e "${GREEN}✅ Remote added${NC}"
    fi
    
    # Push
    echo -e "${BLUE}⬆️  Pushing to remote...${NC}"
    git push -u origin "$branch"
    
    echo -e "${GREEN}✅ Connected to remote successfully!${NC}"
}

# Function to show repository info
show_info() {
    echo -e "${BLUE}📊 Repository Information${NC}"
    echo "=========================="
    
    # Check if git repo
    if [ -d ".git" ]; then
        echo "📍 Location: $(pwd)"
        
        # Remote URL
        remote=$(git remote get-url origin 2>/dev/null || echo "Not configured")
        echo "🔗 Remote: $remote"
        
        # Current branch
        branch=$(git branch --show-current 2>/dev/null || echo "detached")
        echo "🌿 Branch: $branch"
        
        # Last commit
        commit=$(git log -1 --oneline 2>/dev/null || echo "No commits")
        echo "💾 Last commit: $commit"
        
        # Status
        status=$(git status --short 2>/dev/null | wc -l)
        echo "📝 Uncommitted changes: $status files"
        
        # Branches
        echo ""
        echo "🌿 Local branches:"
        git branch --list | sed 's/^/   /'
        
        # Remotes
        echo ""
        echo "🔗 Remotes:"
        git remote -v | sed 's/^/   /'
    else
        echo -e "${RED}❌ Not a git repository${NC}"
        echo "   Run 'git init' or clone a repository first"
    fi
}

# Main execution
case "$1" in
    clone)
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Error: URL required${NC}"
            show_usage
            exit 1
        fi
        clone_repo "$2" "$3" "$4"
        ;;
    init)
        if [ $# -lt 3 ]; then
            echo -e "${RED}❌ Error: Name and URL required${NC}"
            show_usage
            exit 1
        fi
        init_repo "$2" "$3" "$4"
        ;;
    connect)
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Error: URL required${NC}"
            show_usage
            exit 1
        fi
        connect_remote "$2" "$3"
        ;;
    info)
        show_info
        ;;
    *)
        show_usage
        exit 1
        ;;
esac