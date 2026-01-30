#!/bin/bash
# JARVIS Audit Trail - Hash-Chained Action Log
# Usage: audit-log.sh "action_type" "description" ["metadata_json"]

ACTION="${1:-unknown}"
DESCRIPTION="${2:-No description}"
METADATA="${3:-null}"

AUDIT_DIR="$HOME/clawd/audit"
AUDIT_FILE="$AUDIT_DIR/audit.jsonl"
CHAIN_FILE="$AUDIT_DIR/chain-state.json"

mkdir -p "$AUDIT_DIR"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get previous hash (or "genesis" if first entry)
if [ -f "$CHAIN_FILE" ]; then
    PREV_HASH=$(jq -r '.lastHash' "$CHAIN_FILE")
    SEQ=$(jq -r '.sequence' "$CHAIN_FILE")
    SEQ=$((SEQ + 1))
else
    PREV_HASH="genesis"
    SEQ=1
fi

# Build the entry (without hash first)
ENTRY_DATA="${SEQ}|${ACTION}|${DESCRIPTION}|${TIMESTAMP}|${PREV_HASH}"

# Calculate SHA256 hash
HASH=$(echo -n "$ENTRY_DATA" | openssl sha256 -hex 2>/dev/null | awk '{print $2}')

# Handle metadata - if it looks like JSON, use it; otherwise make it a string
if echo "$METADATA" | jq -e . >/dev/null 2>&1; then
    META_JSON="$METADATA"
else
    META_JSON="null"
fi

# Build JSON entry
ENTRY=$(cat <<EOF
{"seq":$SEQ,"action":"$ACTION","description":"$DESCRIPTION","timestamp":"$TIMESTAMP","prevHash":"$PREV_HASH","hash":"$HASH","metadata":$META_JSON}
EOF
)

# Append to audit log
echo "$ENTRY" >> "$AUDIT_FILE"

# Update chain state
cat > "$CHAIN_FILE" <<EOF
{"sequence":$SEQ,"lastHash":"$HASH","lastUpdate":"$TIMESTAMP"}
EOF

# Output for caller
echo "$ENTRY" | jq .
