#!/bin/bash
# preflight.sh — Run before any risky operation
# Usage: preflight.sh "Description of what I'm doing"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh" 2>/dev/null || true

DESCRIPTION="${1:-Unspecified operation}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-$HOME/clawd/backups/config}"
CHANGELOG="${CHANGELOG:-$HOME/clawd/CHANGELOG.md}"
DELAY_MINUTES="${DELAY_MINUTES:-5}"

echo "🛫 PRE-FLIGHT CHECKLIST"
echo "========================"
echo "Operation: $DESCRIPTION"
echo ""

# 1. Backup current config
mkdir -p "$BACKUP_DIR"
if [ -f ~/.config/clawdbot/config.yaml ]; then
    cp ~/.config/clawdbot/config.yaml "$BACKUP_DIR/config.yaml.$TIMESTAMP"
    cp ~/.config/clawdbot/config.yaml "$BACKUP_DIR/config.yaml.lastgood"
    echo "✅ Config backed up → $BACKUP_DIR/config.yaml.$TIMESTAMP"
elif [ -f ~/.clawdbot/clawdbot.json ]; then
    cp ~/.clawdbot/clawdbot.json "$BACKUP_DIR/clawdbot.json.$TIMESTAMP"
    cp ~/.clawdbot/clawdbot.json "$BACKUP_DIR/clawdbot.json.lastgood"
    echo "✅ Config backed up → $BACKUP_DIR/clawdbot.json.$TIMESTAMP"
else
    echo "⚠️  No config file found to backup"
fi

# 2. Log to changelog
mkdir -p "$(dirname "$CHANGELOG")"
echo "" >> "$CHANGELOG"
echo "### $(date '+%Y-%m-%d %H:%M') — $DESCRIPTION" >> "$CHANGELOG"
echo "**Status:** 🔄 IN PROGRESS" >> "$CHANGELOG"
echo "✅ Logged to CHANGELOG.md"

# 3. Spawn safety net
"$SCRIPT_DIR/safety-net.sh" "$DELAY_MINUTES" "$DESCRIPTION" &
disown $!
echo "✅ Safety net active (${DELAY_MINUTES} min)"

# 4. Log to audit chain (if available)
if [ -f "$HOME/clawd/scripts/audit-log.sh" ]; then
    "$HOME/clawd/scripts/audit-log.sh" "preflight" "$DESCRIPTION" '{"backup":"'$TIMESTAMP'"}' > /dev/null
    echo "✅ Logged to audit chain"
fi

echo ""
echo "Ready. Proceed with: $DESCRIPTION"
