#!/bin/bash
# scripts/tests/test-verifica-modelos.sh

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/verifica_modelos.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: verifica_modelos.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Existencia
if [ -f "$TARGET_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Script NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

# Test 2: Validación de lógica Ollama
echo -e "${BLUE}Test 2: Verify Ollama interaction logic${NC}"
if grep -q "ollama list" "$TARGET_SCRIPT" || grep -q "curl.*ollama" "$TARGET_SCRIPT"; then
    echo -e "${GREEN}✓ Ollama listing command found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Ollama listing command NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Resumen
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    exit 1
fi
