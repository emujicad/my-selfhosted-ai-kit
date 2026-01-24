#!/bin/bash
# scripts/tests/test-auto-validate.sh

set -u

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/auto-validate.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: auto-validate.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Existencia
echo -e "${BLUE}Test 1: Verify script exists${NC}"
if [ -f "$TARGET_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

# Test 2: Permisos de ejecución
echo -e "${BLUE}Test 2: Verify execution permissions${NC}"
if [ -x "$TARGET_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Análisis estático de funciones clave
echo -e "${BLUE}Test 3: Verify core functions${NC}"
REQUIRED_FUNCTIONS=("detect_docker" "print_success" "print_error")

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "$func" "$TARGET_SCRIPT"; then
        echo -e "${GREEN}✓ Function '$func' found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Function '$func' NOT found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done

# Resumen
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    exit 1
fi
