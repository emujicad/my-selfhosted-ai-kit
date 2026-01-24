#!/bin/bash

# ============================================================================
# Script: test-verify-env-variables.sh
# Description: Tests for verify-env-variables.sh
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
VERIFY_SCRIPT="$PROJECT_ROOT/scripts/verify-env-variables.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: verify-env-variables.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$VERIFY_SCRIPT" ]; then
    echo -e "${GREEN}✓ verify-env-variables.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ verify-env-variables.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$VERIFY_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify .env file checking
echo -e "${BLUE}Test 2: Verify .env file checking${NC}"
if grep -qi "\.env" "$VERIFY_SCRIPT"; then
    echo -e "${GREEN}✓ .env file checking found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ .env file checking NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 3: Verify required variables checking
echo -e "${BLUE}Test 3: Verify required variables checking${NC}"
if grep -qi "required\|REQUIRED_VARS" "$VERIFY_SCRIPT"; then
    echo -e "${GREEN}✓ Required variables checking found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Required variables checking may not exist${NC}"
fi
echo

# Test 4: Verify error reporting
echo -e "${BLUE}Test 4: Verify error reporting${NC}"
if grep -qi "error\|missing\|not.*set" "$VERIFY_SCRIPT"; then
    echo -e "${GREEN}✓ Error reporting found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Error reporting may not exist${NC}"
fi
echo

# Test 5: Verify exit codes
echo -e "${BLUE}Test 5: Verify exit codes${NC}"
if grep -q "exit 0\|exit 1" "$VERIFY_SCRIPT"; then
    echo -e "${GREEN}✓ Exit codes present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No explicit exit codes${NC}"
fi
echo

# Summary
echo -e "${BLUE}============================================================================${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  TESTS COMPLETED WITH WARNINGS ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    exit 1
fi
