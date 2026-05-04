#!/bin/bash
# Container operations wrapper - Called by Python UI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_SCRIPT="$SCRIPT_DIR/launch_jupyter_gpu.sh"

case "$1" in
    start)
        PORT="${2:-8888}"
        TYPE="${3:-gpu}"
        export PORT="$PORT"
        export CONTAINER_TYPE="$TYPE"
        $LAUNCH_SCRIPT
        ;;
    stop)
        docker stop $(docker ps -q --filter name=jupyter) 2>/dev/null || true
        echo "Container stopped"
        ;;
    status)
        docker ps --filter name=jupyter --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Usage: $0 {start|stop|status} [port] [type]"
        exit 1
        ;;
esac