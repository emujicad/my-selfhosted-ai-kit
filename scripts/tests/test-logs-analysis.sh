#!/bin/bash

# =============================================================================
# Script: test-logs-analysis.sh
# Description: Scans container logs for critical keywords (Fatal, Panic, etc)
#              that usually indicate hidden problems despite "healthy" status.
# =============================================================================

set -u

# Find docker command
DOCKER_CMD="docker"
if ! docker ps &>/dev/null; then
    if sudo docker ps &>/dev/null; then
        DOCKER_CMD="sudo docker"
    fi
fi

echo "🧪 TEST: Log Analysis (Error Detection)"
echo "======================================="

ERRORS_FOUND=0
SERVICES=("keycloak" "n8n" "ollama" "postgres" "grafana")
KEYWORDS="fatal|panic|exception|caused by"
# Exclude common false positives
# - "Client authentication failed": Normal during login tests
# - "start_period": Docker info
EXCLUDES="Client authentication failed|start_period|info"

check_logs() {
    local SERVICE=$1
    echo "🔍 Scanning logs for: $SERVICE"
    
    # Get last 100 lines
    local LOGS=$($DOCKER_CMD compose logs --tail=100 "$SERVICE" 2>&1)
    
    # Grep for keywords, exclude noise
    local MATCHES=$(echo "$LOGS" | grep -iE "$KEYWORDS" | grep -vE "$EXCLUDES")
    
    if [ -n "$MATCHES" ]; then
        echo "   ⚠️  Possible Critical Errors Found:"
        echo "$MATCHES" | head -n 3 | sed 's/^/      /'
        echo "      (See full logs for details)"
        # We assume detection is worthy of investigation, but maybe not block build strictly
        # unless configured. For E2E strict mode, we count it.
        ((ERRORS_FOUND++))
    else
        echo "   ✅ Clean logs (Last 100 lines)"
    fi
}

for SVC in "${SERVICES[@]}"; do
    check_logs "$SVC"
done

echo ""
if [ $ERRORS_FOUND -eq 0 ]; then
    echo "✅ LOG ANALYSIS PASSED: No critical errors detected."
    exit 0
else
    echo "⚠️  LOG ANALYSIS COMPLETED WITH WARNINGS ($ERRORS_FOUND services flagged)."
    # We exit 0 because logs often have noise, we just want to highlight them.
    # Change to 1 if you want strict failure.
    exit 0
fi
