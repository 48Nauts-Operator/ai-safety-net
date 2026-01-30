# config.sh — Safety Net Configuration

# How long safety-net.sh waits before checking (minutes)
DELAY_MINUTES=5

# Health check endpoint
HEALTH_ENDPOINT="http://localhost:3000/health"

# Where to store config backups
BACKUP_DIR="$HOME/clawd/backups/config"

# Changelog location
CHANGELOG="$HOME/clawd/CHANGELOG.md"

# Log file
LOG_FILE="$HOME/clawd/logs/safety-net.log"

# Watchdog: consecutive failures before restart
MAX_FAILS=3

# For emergency Claude API calls (optional)
# ANTHROPIC_API_KEY="sk-ant-..."
