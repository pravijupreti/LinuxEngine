#!/bin/bash
# git.sh - Main entry point (calls the real script in git folder)
# Usage: ./git.sh [manual|window_closed]

# Get the directory where this script is located
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call the real git script in the git folder
exec "$PROJECT_ROOT/git/git.sh" "$@"