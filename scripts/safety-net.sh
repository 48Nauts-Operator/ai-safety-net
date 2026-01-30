#!/bin/bash
# safety-net.sh — Detached guardian process
# Usage: safety-net.sh [delay_minutes] [context]
# Spawned by preflight.sh, runs independently

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh" 2>/dev/null || true

DELAY_MINUTES="${1:-5}"
CONTEXT="${2:-Unspecified operation}"
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-http://localhost:3000/health}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/clawd/backups/config}"
LOG_FILE="${LOG_FILE:-$HOME/clawd/logs/safety-net.log}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

check_gateway() {
    if pgrep -f "clawdbot" > /dev/null 2>&1; then
        curl -s --max-time 10 "$HEALTH_ENDPOINT" > /dev/null 2>&1
        return $?
    fi
    return 1
}

attempt_recovery() {
    log "🔧 Attempting recovery..."
    
    # Try 1: Simple restart
    clawdbot gateway stop 2>/dev/null
    sleep 3
    clawdbot gateway start &
    sleep 15
    
    if check_gateway; then
        log "✅ Recovery successful (restart)"
        return 0
    fi
    
    # Try 2: Restore last good config
    if [ -f "$BACKUP_DIR/config.yaml.lastgood" ]; then
        log "🔧 Restoring last good config..."
        cp "$BACKUP_DIR/config.yaml.lastgood" ~/.config/clawdbot/config.yaml
        clawdbot gateway restart &
        sleep 15
        
        if check_gateway; then
            log "✅ Recovery successful (config restore)"
            return 0
        fi
    elif [ -f "$BACKUP_DIR/clawdbot.json.lastgood" ]; then
        log "🔧 Restoring last good config..."
        cp "$BACKUP_DIR/clawdbot.json.lastgood" ~/.clawdbot/clawdbot.json
        clawdbot gateway restart &
        sleep 15
        
        if check_gateway; then
            log "✅ Recovery successful (config restore)"
            return 0
        fi
    fi
    
    log "❌ Recovery failed"
    return 1
}

call_claude_for_help() {
    log "🆘 Calling Claude API for diagnosis..."
    
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        log "❌ No ANTHROPIC_API_KEY set, cannot call Claude"
        return 1
    fi
    
    RECENT_LOGS=$(tail -100 ~/clawd/logs/gateway.log 2>/dev/null || echo "No logs available")
    
    RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"claude-sonnet-4-20250514\",
            \"max_tokens\": 1024,
            \"messages\": [{
                \"role\": \"user\",
                \"content\": \"AI assistant gateway is dead after operation: $CONTEXT\\n\\nRecent logs:\\n$RECENT_LOGS\\n\\nDiagnose the issue and suggest a fix in 2-3 sentences.\"
            }]
        }" 2>/dev/null)
    
    log "Claude says: $RESPONSE"
    echo "$RESPONSE" >> "$LOG_FILE"
}

alert_human() {
    log "📢 Alerting human..."
    
    # macOS notification
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"Gateway down after: $CONTEXT\" with title \"🚨 AI Safety Net\" sound name \"Basso\""
    fi
    
    # Could add: SMS, email, Slack webhook, etc.
}

main() {
    log "🛡️ Safety net activated"
    log "   Operation: $CONTEXT"
    log "   Checking in: $DELAY_MINUTES minutes"
    
    sleep $((DELAY_MINUTES * 60))
    
    log "⏰ Safety net waking up..."
    
    if check_gateway; then
        log "✅ Gateway healthy — all good"
        exit 0
    fi
    
    log "❌ Gateway DOWN — initiating recovery"
    
    if attempt_recovery; then
        alert_human  # Still alert even on success
        exit 0
    fi
    
    call_claude_for_help
    alert_human
    
    log "🚨 Recovery failed — human intervention required"
    exit 1
}

# Detach from terminal
main "$@"
