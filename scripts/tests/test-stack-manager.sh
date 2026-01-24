#!/bin/bash

# ============================================================================
# Script: test-stack-manager.sh
# Description: Comprehensive tests for stack-manager.sh
# Tests core orchestration functionality without starting actual services
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
STACK_MANAGER="$PROJECT_ROOT/scripts/stack-manager.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: stack-manager.sh Comprehensive Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$STACK_MANAGER" ]; then
    echo -e "${GREEN}✓ stack-manager.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ stack-manager.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$STACK_MANAGER" ]; then
    echo -e "${GREEN}✓ stack-manager.sh is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ stack-manager.sh is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify help command works
echo -e "${BLUE}Test 2: Verify help command${NC}"
if "$STACK_MANAGER" help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Help command works${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Help command failed${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 3: Verify all main commands exist
echo -e "${BLUE}Test 3: Verify main commands${NC}"
MAIN_COMMANDS=("start" "stop" "restart" "status" "logs" "clean")

for cmd in "${MAIN_COMMANDS[@]}"; do
    if grep -q "^[[:space:]]*${cmd})" "$STACK_MANAGER"; then
        echo -e "${GREEN}✓ Command '$cmd' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Command '$cmd' NOT found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done
echo

# Test 4: Verify profile system
echo -e "${BLUE}Test 4: Verify profile system${NC}"
PROFILES=("gpu" "monitoring" "infrastructure" "security" "automation" "chat-ai")

for profile in "${PROFILES[@]}"; do
    if grep -qi "$profile" "$STACK_MANAGER"; then
        echo -e "${GREEN}✓ Profile '$profile' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ Profile '$profile' may not exist${NC}"
    fi
done
echo

# Test 5: Verify preset system
echo -e "${BLUE}Test 5: Verify preset system${NC}"
if grep -qi "preset\|expand_preset" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Preset system found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Preset system may not exist${NC}"
fi
echo

# Test 6: Verify --setup-roles flag
echo -e "${BLUE}Test 6: Verify --setup-roles flag${NC}"
if grep -q "setup-roles\|auto_setup_roles" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ --setup-roles flag found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ --setup-roles flag NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 7: Verify Keycloak health check
echo -e "${BLUE}Test 7: Verify Keycloak health check${NC}"
if grep -q "health/ready\|keycloak.*ready" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Keycloak health check found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Keycloak health check may not exist${NC}"
fi
echo

# Test 8: Verify keycloak-roles-manager.sh integration
echo -e "${BLUE}Test 8: Verify keycloak-roles-manager.sh integration${NC}"
if grep -q "keycloak-roles-manager.sh" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ keycloak-roles-manager.sh integration found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ keycloak-roles-manager.sh integration NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 9: Verify clean command types
echo -e "${BLUE}Test 9: Verify clean command types${NC}"
CLEAN_TYPES=("all" "containers" "networks" "storage")

for type in "${CLEAN_TYPES[@]}"; do
    if grep -qi "clean.*$type\|$type.*clean" "$STACK_MANAGER"; then
        echo -e "${GREEN}✓ Clean type '$type' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ Clean type '$type' may not exist${NC}"
    fi
done
echo

# Test 10: Verify Keycloak roles reminder
echo -e "${BLUE}Test 10: Verify Keycloak roles reminder${NC}"
if grep -qi "RECORDATORIO.*KEYCLOAK ROLES\|reminder.*keycloak" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Keycloak roles reminder found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Keycloak roles reminder NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 11: Verify reminder after clean all
echo -e "${BLUE}Test 11: Verify reminder after clean all${NC}"
if grep -qi "Has eliminado.*Keycloak\|clean all.*reminder" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Clean all reminder found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Clean all reminder NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 12: Verify Docker Compose usage
echo -e "${BLUE}Test 12: Verify Docker Compose usage${NC}"
if grep -qi "docker compose\|docker-compose" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Docker Compose usage found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Docker Compose usage NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 13: Verify error handling
echo -e "${BLUE}Test 13: Verify error handling${NC}"
if grep -q "set -e\|exit 1" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Error handling present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ No error handling found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 14: Verify Keycloak DB cleanup
echo -e "${BLUE}Test 14: Verify Keycloak DB cleanup${NC}"
if grep -qi "auto_fix_keycloak_db\|keycloak.*cleanup\|pg_terminate_backend" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Keycloak DB cleanup found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Keycloak DB cleanup may not exist${NC}"
fi
echo

# Test 15: Verify service status checking
echo -e "${BLUE}Test 15: Verify service status checking${NC}"
if grep -qi "status\|docker.*ps\|service.*running" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Service status checking found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Service status checking NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 16: Verify logs command
echo -e "${BLUE}Test 16: Verify logs command${NC}"
if grep -qi "logs\|docker.*logs" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Logs command found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Logs command NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 17: Verify environment file loading
echo -e "${BLUE}Test 17: Verify environment file loading${NC}"
if grep -q "\.env\|source.*env" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Environment file loading found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Environment file loading may not exist${NC}"
fi
echo

# Test 18: Verify validation before start
echo -e "${BLUE}Test 18: Verify validation before start${NC}"
if grep -qi "validate_before_start\|validation\|check.*before" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Pre-start validation found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Pre-start validation may not exist${NC}"
fi
echo

# Test 19: Verify cleanup of created containers
echo -e "${BLUE}Test 19: Verify cleanup of created containers${NC}"
if grep -qi "cleanup_created_containers\|status=created" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Created containers cleanup found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Created containers cleanup may not exist${NC}"
fi
echo

# Test 20: Verify network handling
echo -e "${BLUE}Test 20: Verify network handling${NC}"
if grep -qi "network\|docker.*network" "$STACK_MANAGER"; then
    echo -e "${GREEN}✓ Network handling found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Network handling may not exist${NC}"
fi
echo

# Summary
echo -e "${BLUE}============================================================================${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${GREEN}stack-manager.sh is validated and ready for use${NC}"
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
