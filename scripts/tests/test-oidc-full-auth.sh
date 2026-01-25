#!/bin/bash
# scripts/tests/test-oidc-full-auth.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../.env" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 TEST: End-to-End OIDC Authentication Flow${NC}"
echo "=================================================="

# Configuration
KEYCLOAK_URL="http://localhost:8080"
REALM="${KEYCLOAK_REALM:-master}"
USER="${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-emujicad}"
PASS="${KEYCLOAK_PERMANENT_ADMIN_PASSWORD:-TempPass123!}"

# 1. Test for different clients
CLIENTS=("grafana" "open-webui" "jenkins")

for CLIENT_ID in "${CLIENTS[@]}"; do
    echo -e "\n${BLUE}🎯 Testing Client: $CLIENT_ID${NC}"
    
    # Get Secret from .env
    SECRET_VAR="KEYCLOAK_CLIENT_SECRET_$(echo $CLIENT_ID | tr 'a-z-' 'A-Z_')"
    CLIENT_SECRET="${!SECRET_VAR:-}"
    
    if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" == "changeme" ]; then
        # Fallback to general OAUTH vars
        if [ "$CLIENT_ID" == "grafana" ]; then CLIENT_SECRET="$GRAFANA_OAUTH_CLIENT_SECRET"; fi
        if [ "$CLIENT_ID" == "open-webui" ]; then CLIENT_SECRET="$OPEN_WEBUI_OAUTH_CLIENT_SECRET"; fi
        if [ "$CLIENT_ID" == "jenkins" ]; then CLIENT_SECRET="$JENKINS_OIDC_CLIENT_SECRET"; fi
    fi

    echo "1️⃣  Obtaining Token for $USER..."
    RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
        -d "client_id=$CLIENT_ID" \
        -d "username=$USER" \
        -d "password=$PASS" \
        -d "grant_type=password" \
        -d "scope=openid email profile" \
        -d "client_secret=$CLIENT_SECRET")

    ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r .access_token)

    if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
        echo -e "${RED}❌ Failed to obtain token for $CLIENT_ID${NC}"
        echo "Response: $RESPONSE"
        continue
    fi
    echo -e "${GREEN}✅ Token obtained successfully${NC}"

    echo "2️⃣  Verifying UserInfo Endpoint (Service Call)..."
    USERINFO=$(curl -s -f -X GET "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/userinfo" \
        -H "Authorization: Bearer $ACCESS_TOKEN")

    if [ $? -ne 0 ] || [ -z "$USERINFO" ]; then
        echo -e "${RED}❌ UserInfo endpoint rejected the token (401/Invalid Token)${NC}"
        continue
    fi
    echo -e "${GREEN}✅ UserInfo endpoint verified (200 OK)${NC}"

    echo "3️⃣  Verifying Roles & Claims..."
    # Robust Decode: Use jq directly on the second part of the JWT
    # We ignore the signature and just decode the payload
    PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null || echo "{}")
    
    if [ "$PAYLOAD" == "{}" ]; then
        echo -e "${RED}❌ Failed to decode token payload${NC}"
        continue
    fi

    # Check Audience
    AUD=$(echo "$PAYLOAD" | jq -r '.aud' 2>/dev/null || echo "")
    if echo "$AUD" | grep -q "$CLIENT_ID"; then
        echo -e "${GREEN}✅ Audience '$CLIENT_ID' present in token${NC}"
    else
        echo -e "${YELLOW}⚠️  Audience '$CLIENT_ID' NOT found in 'aud' claim: $AUD${NC}"
    fi

    # Check Roles
    ROLES=$(echo "$PAYLOAD" | jq -r ".resource_access.\"$CLIENT_ID\".roles[]?" 2>/dev/null || echo "")
    GLOBAL_ROLES=$(echo "$PAYLOAD" | jq -r ".roles[]?" 2>/dev/null || echo "")

    if [ -z "$ROLES" ] && [ -z "$GLOBAL_ROLES" ]; then
        echo -e "${RED}❌ NO ROLES found for client '$CLIENT_ID'${NC}"
        echo "Structures: $(echo "$PAYLOAD" | jq -c '.resource_access // {}')"
    else
        echo -e "${GREEN}✅ Roles found (Resource): $(echo $ROLES | tr '\n' ' ')${NC}"
        [ ! -z "$GLOBAL_ROLES" ] && echo -e "${GREEN}✅ Roles found (Global): $(echo $GLOBAL_ROLES | tr '\n' ' ')${NC}"
    fi
done

echo -e "\n${BLUE}🏆 E2E OIDC Flow Test Completed${NC}"
exit 0
