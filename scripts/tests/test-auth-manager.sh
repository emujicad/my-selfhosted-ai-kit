#!/bin/bash
# scripts/tests/test-auth-manager.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../auth-manager.sh"

echo "🧪 TEST: auth-manager.sh"
echo "========================"

FAILURES=0

run_check() {
    local test_name=$1
    local cmd=$2
    echo -n "Test: $test_name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "✅ PASSED"
    else
        echo "❌ FAILED"
        FAILURES=$((FAILURES + 1))
    fi
}

# Test 1: Existence
run_check "Script existence" "[ -f '$TARGET_SCRIPT' ]"

# Test 2: Help flag
run_check "Help flag" "$TARGET_SCRIPT --help"

# Test 3: Flag Definitions Check
run_check "Flag --setup-roles defined" "grep -q 'setup-roles)' $TARGET_SCRIPT"
run_check "Flag --create-admin defined" "grep -q 'create-admin)' $TARGET_SCRIPT"
run_check "Flag --fix-clients defined" "grep -q 'fix-clients)' $TARGET_SCRIPT"

if [ $FAILURES -eq 0 ]; then
    exit 0
else
    exit 1
fi
