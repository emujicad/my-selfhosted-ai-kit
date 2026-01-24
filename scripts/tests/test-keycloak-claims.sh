#!/bin/bash

# =============================================================================
# Script: test-keycloak-claims.sh
# Description: Integration Test that logs in to Keycloak and inspects the JWT Token
#              to verify that Roles are actually being sent to applications.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Load Environment Variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

KEYCLOAK_URL=${KEYCLOAK_URL_PUBLIC:-http://localhost:8080}
REALM=${KEYCLOAK_REALM:-master}
# Use the permanent admin if configured, otherwise fallback to bootstrap admin
# Check configured variables in order of preference
USER="${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-${KEYCLOAK_ADMIN:-${KEYCLOAK_ADMIN_USER:-admin}}}"
PASS="${KEYCLOAK_PERMANENT_ADMIN_PASSWORD:-${KEYCLOAK_ADMIN_PASSWORD:-}}"

if [ -z "$PASS" ]; then
    echo "❌ Error: Password not found in .env"
    exit 1
fi

echo "🧪 TEST: Keycloak Token Claims Verification"
echo "============================================"
echo "🎯 Target User: $USER"
echo "🌍 Realm: $REALM"

# Prerequisite: ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is not installed. Please install it to run this test."
    exit 1
fi

echo ""
echo "1️⃣  Obtaining Access Token..."

# Get Token using Direct Access Grant (username/password)
RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=$USER" \
    -d "password=$PASS" \
    -d "grant_type=password")

if echo "$RESPONSE" | grep -q "error"; then
    echo "❌ Login Failed:"
    echo "$RESPONSE" | jq .
    exit 1
fi

TOKEN=$(echo "$RESPONSE" | jq -r .access_token)
echo "✅ Token obtained successfully (Length: ${#TOKEN} chars)"

echo ""
echo "2️⃣  Assigning 'grafana-admin' role to user for verification..."
# We need to give the user the role to see if it appears in the token
# Get User ID
USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$USER" | jq -r '.[0].id')

if [ "$USER_ID" == "null" ]; then
    echo "❌ Could not find user ID for $USER"
    exit 1
fi

# Get Client ID for Grafana
CLIENT_UUID=$(curl -s -H "Authorization: Bearer $TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=grafana" | jq -r '.[0].id')

if [ "$CLIENT_UUID" == "null" ] || [ -z "$CLIENT_UUID" ]; then
    echo "⚠️  Grafana client not found. Running './scripts/auth-manager.sh --fix-clients'..."
    bash "$PROJECT_ROOT/scripts/auth-manager.sh" --fix-clients > /dev/null
    CLIENT_UUID=$(curl -s -H "Authorization: Bearer $TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=grafana" | jq -r '.[0].id')
fi

# Get Role definition
ROLE_REP=$(curl -s -H "Authorization: Bearer $TOKEN" "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/roles/grafana-admin")

# Assign Role
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/role-mappings/clients/$CLIENT_UUID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "[$ROLE_REP]"

echo "✅ Role 'grafana-admin' assigned temporarily."

echo ""
echo "3️⃣  Refreshing Token to get new claims..."
# Request token again to see the new role
RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
    -d "client_id=grafana" \
    -d "username=$USER" \
    -d "password=$PASS" \
    -d "grant_type=password" \
    -d "client_secret=${GRAFANA_OAUTH_CLIENT_SECRET}") # Assuming secret is in env, otherwise we use admin-cli and check mapping logic

# Note: Login as 'grafana' client requires secret. If not available in shell env, we use admin-cli 
# but we need to check if admin-cli shows the mapped roles.
# Better approach: Check specific userinfo endpoint or introspect.
# Actually, the 'resource_access' claim is visible in any token if the scope includes it.

TOKEN_PAYLOAD=$(echo "$RESPONSE" | jq -r .access_token | cut -d "." -f 2 | base64 -d 2>/dev/null || echo "")

if [ -z "$TOKEN_PAYLOAD" ]; then
    # Base64 decode fix for padding
    TOKEN_PART=$(echo "$RESPONSE" | jq -r .access_token | cut -d "." -f 2)
    LEN=$((${#TOKEN_PART} % 4))
    if [ $LEN -eq 2 ]; then TOKEN_PART="${TOKEN_PART}=="; fi
    if [ $LEN -eq 3 ]; then TOKEN_PART="${TOKEN_PART}="; fi
    TOKEN_PAYLOAD=$(echo "$TOKEN_PART" | base64 -d)
fi

echo ""
echo "4️⃣  Verifying Claims..."

# Extract the roles section
echo "🔍 Searching for 'roles' (Top Level)..."

# Check using jq
if echo "$TOKEN_PAYLOAD" | jq -e '.roles | index("grafana-admin")' > /dev/null; then
    echo "✅ SUCCESS: Found 'grafana-admin' role in token!"
    echo "   Path: roles -> [grafana-admin]"
else
    echo "❌ FAILURE: 'grafana-admin' role NOT found in token."
    echo "   Payload dump (Full):"
    echo "$TOKEN_PAYLOAD" | jq .
    exit 1
fi

echo ""
echo "5️⃣  Cleanup..."
# Remove the role
curl -s -X DELETE "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/role-mappings/clients/$CLIENT_UUID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "[$ROLE_REP]"
echo "✅ Role removed."

echo ""
echo "🏆 INTEGRATION TEST PASSED: Keycloak is correctly issuing mapped roles."
