#!/bin/bash

# =============================================================================
# Script: test-health-deep.sh
# Description: Validates that services are not just "running" but "ready"
#              by polling their application-level health endpoints.
# =============================================================================

set -u

# Find docker command
DOCKER_CMD="docker"
if ! docker ps &>/dev/null; then
    if sudo docker ps &>/dev/null; then
        DOCKER_CMD="sudo docker"
    fi
fi

echo "🧪 TEST: Deep Health Check (Ready State)"
echo "======================================"

# Function to wait for a URL to return 200
wait_for_url() {
    local NAME=$1
    local URL=$2
    local TIMEOUT=${3:-60} # Default 60 seconds
    local INTERVAL=5
    local ELAPSED=0

    echo -n "   ⏳ Waiting for $NAME ($URL)... "

    while [ $ELAPSED -lt $TIMEOUT ]; do
        if curl -s -f "$URL" > /dev/null 2>&1; then
            echo "✅ READY!"
            return 0
        fi
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    echo "❌ TIMEOUT (After ${TIMEOUT}s)"
    return 1
}

ERRORS=0

# 1. Keycloak (Critical for Auth Tests)
# Endpoint: /health/ready (Standard Microprofile Health)
wait_for_url "Keycloak" "http://localhost:8080/health/ready" 90 || ((ERRORS++))

# 2. Grafana (Port 3001)
# Endpoint: /api/health
wait_for_url "Grafana" "http://localhost:3001/api/health" 30 || ((ERRORS++))

# 3. Open WebUI (Port 3000)
# Endpoint: /healthz
# We also check the main page for "Activation Pending" to avoid false positives
echo -n "   ⏳ Waiting for Open WebUI ($URL)... "
wait_for_url "Open WebUI" "http://localhost:3000/healthz" 30 || ((ERRORS++))

# Content Check: Ensure we aren't stuck in "Pending" state
CONTENT=$(curl -s -L "http://localhost:3000/auth/")
if echo "$CONTENT" | grep -q "Account Activation Pending"; then
    echo "   ❌ FAILURE: Open WebUI is UP but showing 'Account Activation Pending'."
    echo "      Fix: Set DEFAULT_USER_ROLE=user in docker-compose.yml"
    ((ERRORS++))
elif echo "$CONTENT" | grep -q "Internal Server Error"; then
    echo "   ❌ FAILURE: Open WebUI is UP but showing 'Internal Server Error'."
    ((ERRORS++))
else
    echo "   ✅ Content Check: Login page seems normal."
fi

# 4. Ollama (via HAProxy Queue on Port 80)
# Endpoint: /ollama/ (Should return "Ollama is running")
wait_for_url "Ollama (Queue)" "http://localhost:80/ollama/" 15 || ((ERRORS++))

# Final Report
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ DEEP HEALTH CHECK PASSED: All services are application-ready."
    exit 0
else
    echo "❌ DEEP HEALTH CHECK FAILED: Some services did not become ready in time."
    exit 1
fi
