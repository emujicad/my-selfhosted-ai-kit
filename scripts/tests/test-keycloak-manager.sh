#!/bin/bash

# ============================================================================
# Script: test-keycloak-manager.sh
# Description: Comprehensive tests for keycloak-manager.sh
# Tests OAuth client creation without modifying actual Keycloak
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KEYCLOAK_MANAGER="$PROJECT_ROOT/scripts/keycloak-manager.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: keycloak-manager.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$KEYCLOAK_MANAGER" ]; then
    echo -e "${GREEN}✓ keycloak-manager.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ keycloak-manager.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$KEYCLOAK_MANAGER" ]; then
    echo -e "${GREEN}✓ keycloak-manager.sh is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ keycloak-manager.sh is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify help command works
echo -e "${BLUE}Test 2: Verify help command${NC}"
if "$KEYCLOAK_MANAGER" help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Help command works${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Help command failed${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 3: Verify script has all required functions
echo -e "${BLUE}Test 3: Verify required functions exist${NC}"
REQUIRED_FUNCTIONS=(
    "setup_grafana"
    "setup_openwebui"
    "setup_n8n"
)

OPTIONAL_FUNCTIONS=(
    "setup_jenkins"
)

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" "$KEYCLOAK_MANAGER" || grep -q "^function ${func}" "$KEYCLOAK_MANAGER"; then
        echo -e "${GREEN}✓ Function '$func' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Function '$func' NOT found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done

for func in "${OPTIONAL_FUNCTIONS[@]}"; do
    if grep -q "^${func}()" "$KEYCLOAK_MANAGER" || grep -q "^function ${func}" "$KEYCLOAK_MANAGER"; then
        echo -e "${GREEN}✓ Optional function '$func' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${BLUE}ℹ Optional function '$func' not implemented (OK)${NC}"
    fi
done
echo

# Test 4: Verify script checks for Keycloak running
echo -e "${BLUE}Test 4: Verify Keycloak availability check${NC}"
if grep -q "docker.*keycloak" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Script checks if Keycloak is running${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No Keycloak availability check found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 5: Verify script uses environment variables
echo -e "${BLUE}Test 5: Verify environment variable usage${NC}"
REQUIRED_VARS=(
    "KEYCLOAK_ADMIN"
    "KEYCLOAK_ADMIN_PASSWORD"
    "KEYCLOAK_REALM"
)

for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "\$${var}" "$KEYCLOAK_MANAGER" || grep -q "\${${var}" "$KEYCLOAK_MANAGER"; then
        echo -e "${GREEN}✓ Uses environment variable: $var${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ May not use: $var${NC}"
    fi
done
echo

# Test 6: Verify OAuth client configurations
echo -e "${BLUE}Test 6: Verify OAuth client configurations${NC}"
REQUIRED_CLIENTS=("grafana" "open-webui" "n8n")
OPTIONAL_CLIENTS=("jenkins")

for client in "${REQUIRED_CLIENTS[@]}"; do
    if grep -qi "$client" "$KEYCLOAK_MANAGER"; then
        echo -e "${GREEN}✓ Configuration for '$client' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Configuration for '$client' NOT found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done

for client in "${OPTIONAL_CLIENTS[@]}"; do
    if grep -qi "$client" "$KEYCLOAK_MANAGER"; then
        echo -e "${GREEN}✓ Optional configuration for '$client' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${BLUE}ℹ Optional configuration for '$client' not implemented (OK)${NC}"
    fi
done
echo

# Test 7: Verify redirect URIs are configurable
echo -e "${BLUE}Test 7: Verify redirect URI configuration${NC}"
if grep -q "REDIRECT_URI" "$KEYCLOAK_MANAGER" || grep -q "redirect" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Redirect URI configuration found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Redirect URI configuration may be hardcoded${NC}"
fi
echo

# Test 8: Verify error handling
echo -e "${BLUE}Test 8: Verify error handling${NC}"
if grep -q "set -e" "$KEYCLOAK_MANAGER" || grep -q "exit 1" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Error handling present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ No error handling found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 9: Verify idempotency (checks if client exists)
echo -e "${BLUE}Test 9: Verify idempotency checks${NC}"
if grep -qi "already exists\|client.*exists" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Idempotency checks found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ May not handle existing clients gracefully${NC}"
fi
echo

# Test 10: Verify script validates .env file
echo -e "${BLUE}Test 10: Verify .env validation${NC}"
if grep -q "\.env" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Script references .env file${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ May not validate .env${NC}"
fi
echo

# Test 11: Verify authentication with Keycloak
echo -e "${BLUE}Test 11: Verify Keycloak authentication logic${NC}"
if grep -qi "kcadm\|curl.*token\|authenticate" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Authentication logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ No authentication logic found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 12: Verify client secret generation/handling
echo -e "${BLUE}Test 12: Verify client secret handling${NC}"
if grep -qi "secret\|client.*secret" "$KEYCLOAK_MANAGER"; then
    echo -e "${GREEN}✓ Client secret handling found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ May not handle client secrets${NC}"
fi
echo

# Test 13: Check if Keycloak is actually running (optional)
echo -e "${BLUE}Test 13: Check Keycloak availability (optional)${NC}"
if docker ps | grep -q keycloak; then
    echo -e "${GREEN}✓ Keycloak is running${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Test 14: Try to get help from actual script (safe operation)
    echo -e "${BLUE}Test 14: Execute help command (safe)${NC}"
    if "$KEYCLOAK_MANAGER" help > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Script executes successfully${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Script execution failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠ Keycloak NOT running (skipping execution tests)${NC}"
fi
echo

# Summary
echo -e "${BLUE}============================================================================${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${GREEN}keycloak-manager.sh is validated and ready for use${NC}"
    echo
    exit 0
else
    echo -e "${YELLOW}⚠️  TESTS COMPLETED WITH WARNINGS ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${YELLOW}Some tests failed or have warnings. Review the output above.${NC}"
    echo
    exit 1
fi
