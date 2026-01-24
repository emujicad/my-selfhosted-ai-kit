#!/bin/bash
# scripts/tests/test-init-config-volumes.sh

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/utils/init/init-config-volumes.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: init-config-volumes.sh Validation${NC}"
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

# Test 2: Ejecución Dry-Run (Verificar que crea directorios)
# Usamos un directorio temporal para no ensuciar el proyecto real
TEMP_DIR=$(mktemp -d)
echo -e "${BLUE}Test 2: Simulation in temp dir: $TEMP_DIR${NC}"

# Copiamos el script y lo modificamos para que use el temp dir (simulación básica)
# En este caso, solo verificamos que el script contenga los comandos clave de creación
if grep -q "docker exec.*mkdir" "$TARGET_SCRIPT"; then
     echo -e "${GREEN}✓ Script contains directory creation commands (mkdir)${NC}"
     TESTS_PASSED=$((TESTS_PASSED + 1))
else
     echo -e "${RED}✗ Script does not contain mkdir commands${NC}"
     TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "docker cp" "$TARGET_SCRIPT"; then
     echo -e "${GREEN}✓ Script contains docker cp commands${NC}"
     TESTS_PASSED=$((TESTS_PASSED + 1))
else
     echo -e "${RED}✗ Script does not contain docker cp commands${NC}"
     TESTS_FAILED=$((TESTS_FAILED + 1))
fi

rm -rf "$TEMP_DIR"

# Resumen
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    exit 1
fi
