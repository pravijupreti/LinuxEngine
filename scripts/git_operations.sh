#!/bin/bash
# Git operations wrapper - Called by Python UI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_AUTO_PUSH="$SCRIPT_DIR/git_auto_push.sh"

case "$1" in
    status)
        git status
        ;;
    log)
        git log --oneline --graph -20
        ;;
    branches)
        git branch -a
        ;;
    commit)
        shift
        message="$*"
        git add .
        git commit -m "$message"
        ;;
    push)
        $GIT_AUTO_PUSH manual
        ;;
    pull)
        git pull
        ;;
    new-branch)
        shift
        git checkout -b "$1"
        ;;
    switch)
        shift
        git checkout "$1"
        ;;
    discard)
        git checkout -- .
        ;;
    *)
        echo "Usage: $0 {status|log|branches|commit|push|pull|new-branch|switch|discard}"
        exit 1
        ;;
esac