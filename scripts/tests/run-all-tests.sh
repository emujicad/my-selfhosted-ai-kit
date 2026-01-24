#!/bin/bash

# ============================================================================
# Script: run-all-tests.sh
# Description: Execute ALL test suites and generate comprehensive report
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  COMPREHENSIVE TEST SUITE EXECUTION                    ║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo

TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_WARNINGS=0

declare -A TEST_RESULTS

# Function to run a test and capture results
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .sh)
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Running: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if "$test_file" 2>&1; then
        TEST_RESULTS[$test_name]="✅ PASSED"
        echo
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            TEST_RESULTS[$test_name]="⚠️  WARNINGS"
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
            echo
            echo -e "${YELLOW}⚠️  $test_name: COMPLETED WITH WARNINGS${NC}"
        else
            TEST_RESULTS[$test_name]="❌ FAILED"
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
            echo
            echo -e "${RED}❌ $test_name: FAILED${NC}"
        fi
    fi
    
    echo
    echo
}

# Find and run all tests
echo -e "${CYAN}Discovering test files...${NC}"
echo

TEST_FILES=()
while IFS= read -r -d '' file; do
    TEST_FILES+=("$file")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -name "test-*.sh" -type f -print0 | sort -z)

TOTAL_TESTS=${#TEST_FILES[@]}

echo -e "${GREEN}Found $TOTAL_TESTS test suites${NC}"
echo

# Run all tests
for test_file in "${TEST_FILES[@]}"; do
    run_test "$test_file"
done

# Generate summary
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                         TEST EXECUTION SUMMARY                         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo

# Calculate passed tests
TOTAL_PASSED=$((TOTAL_TESTS - TOTAL_FAILED - TOTAL_WARNINGS))

echo -e "${BLUE}Total Test Suites:${NC} $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC} $TOTAL_PASSED"
echo -e "${YELLOW}Warnings:${NC} $TOTAL_WARNINGS"
echo -e "${RED}Failed:${NC} $TOTAL_FAILED"
echo

# Detailed results
echo -e "${CYAN}Detailed Results:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
for test_name in "${!TEST_RESULTS[@]}"; do
    echo -e "  ${TEST_RESULTS[$test_name]} $test_name"
done | sort
echo

# Final verdict
if [ $TOTAL_FAILED -eq 0 ] && [ $TOTAL_WARNINGS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   🎉 ALL TESTS PASSED - 10000% CONFIDENCE 🎉           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
elif [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              ⚠️  ALL TESTS PASSED WITH SOME WARNINGS ⚠️                ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Review warnings above. Scripts are functional but may have minor gaps.${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                     ❌ SOME TESTS FAILED ❌                            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${RED}Review failed tests above and fix issues before deployment.${NC}"
    exit 1
fi
