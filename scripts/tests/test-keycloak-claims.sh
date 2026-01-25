#!/bin/bash

# =============================================================================
# Script: test-keycloak-claims.sh
# Description: Verifies that Keycloak issues tokens with correct claims/roles
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env" 2>/dev/null

echo "🧪 TEST: Keycloak Token Claims Verification"
echo "============================================"

# Configuration
KEYCLOAK_URL=${KEYCLOAK_URL_PUBLIC:-http://localhost:8080}
REALM="master"
USER="emujicad"
PASS="${KEYCLOAK_ADMIN_PASSWORD:-TempPass123!}"

echo "🎯 Target User: $USER"
echo "🌍 Realm: $REALM"

# 1. Obtain Token for 'open-webui' client
echo ""
echo "1️⃣  Obtaining Access Token..."

RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
    -d "client_id=open-webui" \
    -d "username=$USER" \
    -d "password=$PASS" \
    -d "grant_type=password" \
    -d "client_secret=${KEYCLOAK_CLIENT_SECRET_OPEN_WEBUI}")

ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r .access_token)

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to obtain token. Check credentials."
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Token obtained successfully (Length: ${#ACCESS_TOKEN} chars)"

# 2. Decode and Verify Roles
echo ""
echo "2️⃣  Verifying Claims..."
echo "🔍 Searching for 'roles' (Top Level)..."

# Decode JWT header.payload.signature -> payload -> base64 decode
ROLES=$(echo "$ACCESS_TOKEN" | awk -F. '{print $2}' | base64 -d 2>/dev/null | jq -r '.roles[]?')

if echo "$ROLES" | grep -q "openwebui-admin"; then
    echo "✅ SUCCESS: Found 'openwebui-admin' role in token!"
    echo "   Path: roles -> [openwebui-admin]"
else
    echo "❌ FAILURE: 'openwebui-admin' role NOT found in token."
    echo "   Found roles: $(echo "$ROLES" | tr '\n' ' ')"
    # Don't fail the script if this is just a check, but for verification we want to know
    exit 1
fi

echo ""
echo "🏆 CLAIMS TEST PASSED"
