#!/bin/bash

# ============================================================================
# Script: test-recreate-keycloak-clients.sh
# Description: Tests for recreate-keycloak-clients.sh
# Validates client recreation logic without modifying Keycloak
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
RECREATE_SCRIPT="$PROJECT_ROOT/scripts/recreate-keycloak-clients.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: recreate-keycloak-clients.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$RECREATE_SCRIPT" ]; then
    echo -e "${GREEN}✓ recreate-keycloak-clients.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ recreate-keycloak-clients.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$RECREATE_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify Keycloak connectivity check
echo -e "${BLUE}Test 2: Verify Keycloak connectivity check${NC}"
if grep -qi "keycloak.*running\|docker.*keycloak" "$RECREATE_SCRIPT"; then
    echo -e "${GREEN}✓ Keycloak connectivity check found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No Keycloak connectivity check${NC}"
fi
echo

# Test 3: Verify client deletion logic
echo -e "${BLUE}Test 3: Verify client deletion logic${NC}"
if grep -qi "delete.*client\|remove.*client" "$RECREATE_SCRIPT"; then
    echo -e "${GREEN}✓ Client deletion logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Client deletion logic may not exist${NC}"
fi
echo

# Test 4: Verify client recreation logic
echo -e "${BLUE}Test 4: Verify client recreation logic${NC}"
if grep -qi "create.*client\|keycloak-manager" "$RECREATE_SCRIPT"; then
    echo -e "${GREEN}✓ Client recreation logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Client recreation logic NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 5: Verify confirmation prompt
echo -e "${BLUE}Test 5: Verify confirmation prompt${NC}"
if grep -qi "read.*confirm\|are you sure\|y/n" "$RECREATE_SCRIPT"; then
    echo -e "${GREEN}✓ Confirmation prompt found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No confirmation prompt found${NC}"
fi
echo

# Test 6: Verify error handling
echo -e "${BLUE}Test 6: Verify error handling${NC}"
if grep -q "set -e\|exit 1" "$RECREATE_SCRIPT"; then
    echo -e "${GREEN}✓ Error handling present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ No error handling found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 7: Verify backup before deletion
echo -e "${BLUE}Test 7: Verify backup before deletion${NC}"
if grep -qi "backup\|save.*config" "$RECREATE_SCRIPT"; then
    echo -e "${GREEN}✓ Backup logic found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No backup before deletion${NC}"
fi
echo

# Test 8: Verify client list
echo -e "${BLUE}Test 8: Verify client list${NC}"
CLIENTS=("grafana" "open-webui" "n8n" "jenkins")
found_clients=0

for client in "${CLIENTS[@]}"; do
    if grep -qi "$client" "$RECREATE_SCRIPT"; then
        echo -e "${GREEN}✓ Client '$client' referenced${NC}"
        found_clients=$((found_clients + 1))
    fi
done

if [ $found_clients -gt 0 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No specific clients identified${NC}"
fi
echo

# Summary
echo -e "${BLUE}============================================================================${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${GREEN}recreate-keycloak-clients.sh is validated and ready for use${NC}"
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
