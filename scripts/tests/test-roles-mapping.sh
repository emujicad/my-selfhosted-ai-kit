#!/bin/bash

# =============================================================================
# Script: test-roles-mapping.sh
# Description: Verifies that Application Role Mappings are correctly configured
#              Check that docker-compose.yml contains the necessary JMESPath/Claims
#              to consume the roles created by auth-manager.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKER_COMPOSE="$PROJECT_ROOT/docker-compose.yml"

echo "🧪 TEST: Role Mapping Configuration"
echo "==================================="

# 1. Verify Docker Compose existence
if [ ! -f "$DOCKER_COMPOSE" ]; then
    echo "❌ docker-compose.yml not found at $DOCKER_COMPOSE"
    exit 1
fi

echo "Test 1: Docker Compose file exists... ✅ PASSED"

# 2. Verify Grafana Mapping
echo "Checking Grafana Role Mapping..."
if grep -q "GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH" "$DOCKER_COMPOSE"; then
     echo "   - Found ROLE_ATTRIBUTE_PATH"
     if grep -q "resource_access.grafana.roles" "$DOCKER_COMPOSE"; then
         echo "   - Verification: Correct JMESPath (resource_access.grafana.roles) found"
         echo "Test 2: Grafana Mapping Configured... ✅ PASSED"
     else
         echo "   ❌ ERROR: JMESPath does not look correct. Expected 'resource_access.grafana.roles'"
         exit 1
     fi
else
    echo "   ❌ ERROR: GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH not found in docker-compose.yml"
    exit 1
fi

# 3. Verify Open WebUI Mapping
echo "Checking Open WebUI Role Mapping..."
if grep -q "OPENID_ROLES_CLAIM" "$DOCKER_COMPOSE"; then
    echo "   - Found OPENID_ROLES_CLAIM"
     if grep -q "resource_access.open-webui.roles" "$DOCKER_COMPOSE"; then
         echo "   - Verification: Correct Claim Path found"
         echo "Test 3: Open WebUI Mapping Configured... ✅ PASSED"
     else
         echo "   ❌ ERROR: Claim path does not look correct. Expected 'resource_access.open-webui.roles'"
         exit 1
     fi
else
    echo "   ❌ ERROR: OPENID_ROLES_CLAIM not found in docker-compose.yml"
    exit 1
fi

# 4. Verify Auth Manager Logic
echo "Checking Auth Manager Script..."
AUTH_MANAGER="$PROJECT_ROOT/scripts/auth-manager.sh"
if [ -f "$AUTH_MANAGER" ]; then
    if grep -q "oidc-usermodel-client-role-mapper" "$AUTH_MANAGER"; then
        echo "   - Verification: Auth Manager creates client-role-mappers"
        echo "Test 4: Auth Manager Logic Verified... ✅ PASSED"
    else
        echo "   ❌ ERROR: Auth manager does not seem to create role mappers"
        exit 1
    fi
else
    echo "   ❌ ERROR: auth-manager.sh not found"
    exit 1
fi

echo ""
echo "✅ All Role Mapping Tests Passed"
