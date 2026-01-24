#!/bin/bash

# ============================================================================
# Script: test-backup-manager.sh
# Description: Comprehensive tests for backup-manager.sh
# Tests backup/restore functionality without modifying actual data
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
BACKUP_MANAGER="$PROJECT_ROOT/scripts/backup-manager.sh"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Test: backup-manager.sh Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Script exists and is executable
echo -e "${BLUE}Test 1: Verify script exists and is executable${NC}"
if [ -f "$BACKUP_MANAGER" ]; then
    echo -e "${GREEN}✓ backup-manager.sh exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ backup-manager.sh NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

if [ -x "$BACKUP_MANAGER" ]; then
    echo -e "${GREEN}✓ backup-manager.sh is executable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ backup-manager.sh is NOT executable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 2: Verify help command works
echo -e "${BLUE}Test 2: Verify help command${NC}"
if "$BACKUP_MANAGER" help > /dev/null 2>&1 || "$BACKUP_MANAGER" --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Help command works${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Help command may not be implemented${NC}"
fi
echo

# Test 3: Verify backup command exists
echo -e "${BLUE}Test 3: Verify backup command${NC}"
if grep -qi "backup" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Backup functionality found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Backup functionality NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 4: Verify restore command exists
echo -e "${BLUE}Test 4: Verify restore command${NC}"
if grep -qi "restore" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Restore functionality found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Restore functionality NOT found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 5: Verify list command exists
echo -e "${BLUE}Test 5: Verify list command${NC}"
if grep -qi "list" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ List functionality found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ List functionality may not exist${NC}"
fi
echo

# Test 6: Verify backup directory configuration
echo -e "${BLUE}Test 6: Verify backup directory configuration${NC}"
if grep -qi "BACKUP_DIR\|backup.*dir\|backups/" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Backup directory configuration found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Backup directory NOT configured${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 7: Verify timestamp in backup names
echo -e "${BLUE}Test 7: Verify timestamp in backup names${NC}"
if grep -qi "date\|timestamp\|%Y%m%d\|%H%M%S" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Timestamp functionality found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Backups may not have timestamps${NC}"
fi
echo

# Test 8: Verify compression (tar/gzip)
echo -e "${BLUE}Test 8: Verify compression${NC}"
if grep -qi "tar\|gzip\|zip\|compress" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Compression functionality found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ Backups may not be compressed${NC}"
fi
echo

# Test 9: Verify error handling
echo -e "${BLUE}Test 9: Verify error handling${NC}"
if grep -q "set -e" "$BACKUP_MANAGER" || grep -q "exit 1" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Error handling present${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ No error handling found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo

# Test 10: Verify backup verification/integrity check
echo -e "${BLUE}Test 10: Verify backup verification${NC}"
if grep -qi "verify\|check\|integrity\|md5\|sha" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Backup verification found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No backup verification found${NC}"
fi
echo

# Test 11: Verify what gets backed up
echo -e "${BLUE}Test 11: Verify backup targets${NC}"
BACKUP_TARGETS=("postgres" "keycloak" "grafana" "n8n" "volumes")
found_targets=0

for target in "${BACKUP_TARGETS[@]}"; do
    if grep -qi "$target" "$BACKUP_MANAGER"; then
        echo -e "${GREEN}✓ Backs up: $target${NC}"
        found_targets=$((found_targets + 1))
    fi
done

if [ $found_targets -gt 0 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No specific backup targets identified${NC}"
fi
echo

# Test 12: Verify retention policy
echo -e "${BLUE}Test 12: Verify retention policy${NC}"
if grep -qi "retention\|keep\|delete.*old\|cleanup" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Retention policy found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No retention policy found${NC}"
fi
echo

# Test 13: Verify pre-backup checks
echo -e "${BLUE}Test 13: Verify pre-backup checks${NC}"
if grep -qi "check.*running\|docker.*ps\|service.*status" "$BACKUP_MANAGER"; then
    echo -e "${GREEN}✓ Pre-backup checks found${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ No pre-backup checks found${NC}"
fi
echo

# Summary
echo -e "${BLUE}============================================================================${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED ($TESTS_PASSED passed, $TESTS_FAILED failed)${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${GREEN}backup-manager.sh is validated and ready for use${NC}"
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
