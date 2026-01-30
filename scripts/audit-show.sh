#!/bin/bash
# JARVIS Audit Log Viewer
# Usage: audit-show.sh [--last N] [--action TYPE] [--today]

AUDIT_FILE="$HOME/clawd/audit/audit.jsonl"

if [ ! -f "$AUDIT_FILE" ]; then
    echo "No audit log found."
    exit 1
fi

# Parse arguments
LAST=""
ACTION_FILTER=""
TODAY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --last)
            LAST="$2"
            shift 2
            ;;
        --action)
            ACTION_FILTER="$2"
            shift 2
            ;;
        --today)
            TODAY=$(date -u +"%Y-%m-%d")
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Build filter
FILTER="."
if [ -n "$ACTION_FILTER" ]; then
    FILTER="select(.action == \"$ACTION_FILTER\")"
fi
if [ -n "$TODAY" ]; then
    FILTER="select(.timestamp | startswith(\"$TODAY\"))"
fi

# Output
if [ -n "$LAST" ]; then
    tail -n "$LAST" "$AUDIT_FILE" | jq -c "$FILTER" | jq -s '.'
else
    cat "$AUDIT_FILE" | jq -c "$FILTER" | jq -s '.'
fi
