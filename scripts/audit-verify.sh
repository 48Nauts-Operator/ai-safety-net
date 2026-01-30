#!/bin/bash
# JARVIS Audit Chain Verifier
# Walks the chain and verifies all hashes
# Usage: audit-verify.sh [--verbose]

AUDIT_FILE="$HOME/clawd/audit/audit.jsonl"
VERBOSE="${1:-}"

if [ ! -f "$AUDIT_FILE" ]; then
    echo "❌ No audit log found at $AUDIT_FILE"
    exit 1
fi

echo "🔍 Verifying JARVIS Audit Chain..."
echo "=================================="

EXPECTED_PREV="genesis"
ERRORS=0
TOTAL=0

while IFS= read -r line; do
    TOTAL=$((TOTAL + 1))
    
    # Extract fields
    SEQ=$(echo "$line" | jq -r '.seq')
    ACTION=$(echo "$line" | jq -r '.action')
    DESC=$(echo "$line" | jq -r '.description')
    TS=$(echo "$line" | jq -r '.timestamp')
    PREV=$(echo "$line" | jq -r '.prevHash')
    STORED_HASH=$(echo "$line" | jq -r '.hash')
    
    # Verify prev_hash links correctly
    if [ "$PREV" != "$EXPECTED_PREV" ]; then
        echo "❌ Entry $SEQ: Chain broken! Expected prev=$EXPECTED_PREV, got prev=$PREV"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Recalculate hash
    ENTRY_DATA="${SEQ}|${ACTION}|${DESC}|${TS}|${PREV}"
    CALC_HASH=$(echo -n "$ENTRY_DATA" | openssl sha256 -hex 2>/dev/null | awk '{print $2}')
    
    # Verify hash matches
    if [ "$CALC_HASH" != "$STORED_HASH" ]; then
        echo "❌ Entry $SEQ: Hash mismatch! Tampering detected."
        echo "   Stored:     $STORED_HASH"
        echo "   Calculated: $CALC_HASH"
        ERRORS=$((ERRORS + 1))
    elif [ "$VERBOSE" = "--verbose" ]; then
        echo "✅ Entry $SEQ: $ACTION - verified"
    fi
    
    # Update expected prev for next iteration
    EXPECTED_PREV="$STORED_HASH"
    
done < "$AUDIT_FILE"

echo "=================================="
echo "Total entries: $TOTAL"

if [ $ERRORS -eq 0 ]; then
    echo "✅ Chain integrity: VERIFIED"
    echo "🔗 All hashes valid, no tampering detected."
    exit 0
else
    echo "❌ Chain integrity: FAILED"
    echo "🚨 $ERRORS error(s) found - possible tampering!"
    exit 1
fi
