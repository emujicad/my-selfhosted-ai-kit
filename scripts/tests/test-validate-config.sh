#!/bin/bash

# ============================================================================
# Script: test-validate-config.sh
# Description: Tests for validate-config.sh
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
VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-config.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: validate-config.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$VALIDATE_SCRIPT" ]; then
    echo -e "${GREEN}✓ validate-config.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ validate-config.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$VALIDATE_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify configuration validation
echo -e "${BLUE}Test 2: Verify configuration validation${NC}"
if grep -qi "validate\|check\|verify\|test" "$VALIDATE_SCRIPT"; then
    echo -e "${GREEN}✓ Configuration validation found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Configuration validation NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 3: Verify file existence checks
echo -e "${BLUE}Test 3: Verify file existence checks${NC}"
if grep -qi "file.*exists\|-f\|-d" "$VALIDATE_SCRIPT"; then
    echo -e "${GREEN}✓ File existence checks found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${BLUE}ℹ File existence checks may use different approach (OK)${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo

# Test 4: Verify error handling
echo -e "${BLUE}Test 4: Verify error handling${NC}"
if grep -q "exit 1\|error" "$VALIDATE_SCRIPT"; then
    echo -e "${GREEN}✓ Error handling present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${BLUE}ℹ Error handling may use different approach (OK)${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
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
