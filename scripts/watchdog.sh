#!/bin/bash
# watchdog.sh — Background monitor (cron)
# Add to crontab: */5 * * * * /path/to/watchdog.sh
# Catches crashes that happen between explicit operations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh" 2>/dev/null || true

HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-http://localhost:3000/health}"
FAIL_FILE="/tmp/clawdbot-watchdog-fails"
MAX_FAILS="${MAX_FAILS:-3}"
LOG_FILE="${LOG_FILE:-$HOME/clawd/logs/watchdog.log}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

if curl -s --max-time 10 "$HEALTH_ENDPOINT" > /dev/null 2>&1; then
    # Healthy - reset fail counter
    rm -f "$FAIL_FILE"
    exit 0
fi

# Not healthy - increment fail counter
FAILS=$(($(cat "$FAIL_FILE" 2>/dev/null || echo 0) + 1))
echo $FAILS > "$FAIL_FILE"

log "Health check failed ($FAILS/$MAX_FAILS)"

if [ $FAILS -ge $MAX_FAILS ]; then
    log "🚨 $MAX_FAILS consecutive failures — attempting restart"
    
    clawdbot gateway restart &
    
    # Alert human
    if command -v osascript &> /dev/null; then
        osascript -e 'display notification "Gateway was down, attempted restart" with title "🐕 Watchdog Alert"'
    fi
    
    # Reset counter
    rm -f "$FAIL_FILE"
fi
