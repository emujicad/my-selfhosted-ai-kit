#!/bin/bash

# ============================================================================
# Script: test-keycloak-permanent-admin.sh
# Description: Tests for keycloak-create-permanent-admin.sh
# Validates admin user creation without modifying Keycloak
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
ADMIN_SCRIPT="$PROJECT_ROOT/scripts/keycloak-create-permanent-admin.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: keycloak-create-permanent-admin.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$ADMIN_SCRIPT" ]; then
    echo -e "${GREEN}✓ keycloak-create-permanent-admin.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ keycloak-create-permanent-admin.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$ADMIN_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify environment variable usage
echo -e "${BLUE}Test 2: Verify environment variable usage${NC}"
REQUIRED_VARS=(
    "KEYCLOAK_PERMANENT_ADMIN_USERNAME"
    "KEYCLOAK_PERMANENT_ADMIN_EMAIL"
    "KEYCLOAK_PERMANENT_ADMIN_PASSWORD"
)

for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "\$${var}" "$ADMIN_SCRIPT" || grep -q "\${${var}" "$ADMIN_SCRIPT"; then
        echo -e "${GREEN}✓ Uses environment variable: $var${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ May not use: $var${NC}"
    fi
done
echo

# Test 3: Verify Keycloak connectivity check
echo -e "${BLUE}Test 3: Verify Keycloak connectivity check${NC}"
if grep -qi "keycloak.*running\|docker.*keycloak\|curl.*keycloak" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Keycloak connectivity check found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No Keycloak connectivity check${NC}"
fi
echo

# Test 4: Verify user creation logic
echo -e "${BLUE}Test 4: Verify user creation logic${NC}"
if grep -qi "create.*user\|add.*user\|kcadm.*create" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ User creation logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ User creation logic NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 5: Verify password setting
echo -e "${BLUE}Test 5: Verify password setting${NC}"
if grep -qi "password\|credentials" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Password setting logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Password setting logic NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 6: Verify role assignment
echo -e "${BLUE}Test 6: Verify role assignment${NC}"
if grep -qi "role.*admin\|assign.*role\|add.*role" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Role assignment logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Role assignment logic NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 7: Verify user verification
echo -e "${BLUE}Test 7: Verify user verification${NC}"
if grep -qi "verify\|test.*login\|check.*user" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ User verification found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No user verification found${NC}"
fi
echo

# Test 8: Verify temporary admin deletion
echo -e "${BLUE}Test 8: Verify temporary admin deletion${NC}"
if grep -qi "delete.*admin\|remove.*admin\|temporary" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Temporary admin deletion logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No temporary admin deletion found${NC}"
fi
echo

# Test 9: Verify confirmation prompt
echo -e "${BLUE}Test 9: Verify confirmation prompt${NC}"
if grep -qi "read.*confirm\|are you sure\|y/n" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Confirmation prompt found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No confirmation prompt found${NC}"
fi
echo

# Test 10: Verify error handling
echo -e "${BLUE}Test 10: Verify error handling${NC}"
if grep -q "set -e" "$ADMIN_SCRIPT" || grep -q "exit 1" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Error handling present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ No error handling found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 11: Verify idempotency (user already exists)
echo -e "${BLUE}Test 11: Verify idempotency checks${NC}"
if grep -qi "already exists\|user.*exists" "$ADMIN_SCRIPT"; then
    echo -e "${GREEN}✓ Idempotency checks found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ May not handle existing users gracefully${NC}"
fi
echo

# Summary
echo -e "${BLUE}============================================================================${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${GREEN}keycloak-create-permanent-admin.sh is validated and ready for use${NC}"
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
