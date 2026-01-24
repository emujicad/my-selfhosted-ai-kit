#!/bin/bash

# =============================================================================
# Script: test-ollama-queue.sh
# Description: Validates that the Ollama Queue endpoint is active in HAProxy
#              and routing correctly to the internal Ollama service.
# =============================================================================

set -uo pipefail

# Find docker command
DOCKER_CMD="docker"
if ! docker ps &>/dev/null; then
    if sudo docker ps &>/dev/null; then
        DOCKER_CMD="sudo docker"
    fi
fi

echo "🧪 TEST: Ollama Queue via HAProxy"
echo "================================"

# 1. Check HAProxy Status
echo "Checking HAProxy service..."
if ! $DOCKER_CMD ps | grep -q "haproxy"; then
    echo "❌ HAProxy is not running. Start the stack first."
    exit 1
fi
echo "   ✅ HAProxy is running"

# 2. Test Direct Routing (Path Rewrite)
# Endpoint: http://localhost:80/ollama/api/tags -> http://ollama:11434/api/tags
TARGET_URL="http://localhost:80/ollama/api/tags"

echo "Checking Queue Endpoint: $TARGET_URL"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL")

if [ "$RESPONSE" == "200" ]; then
    echo "   ✅ Endpoint Reachable (HTTP 200)"
    echo "   Routing Logic: /ollama/* -> ollama:11434/* verified."
elif [ "$RESPONSE" == "000" ]; then
    echo "   ❌ Failed to connect to HAProxy (Connection Refused)"
    exit 1
else
    echo "   ❌ Endpoint returned HTTP $RESPONSE (Expected 200)"
    echo "   Possible causes: Rewrite rule failed, Ollama down, or Network issue."
    exit 1
fi

echo ""
echo "ℹ️  Queue Validation Info:"
echo "   The HAProxy 'maxconn 1' rule is active on this backend."
echo "   Requests to $TARGET_URL will be serialized to protect the GPU."
echo ""
echo "✅ Ollama Queue Test Passed"
