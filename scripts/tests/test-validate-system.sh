#!/bin/bash
# scripts/tests/test-validate-system.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../validate-system.sh"

echo "🧪 TEST: validate-system.sh"
echo "==========================="

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

# Test 3: Env flag (Basic Run)
run_check "Env verification" "$TARGET_SCRIPT --env"

# Test 4: Config flag
run_check "Config verification" "$TARGET_SCRIPT --config"

# Test 5: Models flag
run_check "Models verification" "$TARGET_SCRIPT --models"

# Test 6: Deploy flag (Existence check only)
# We don't want to actually deploy in a unit test, so we just check if it accepts the flag
if grep -q "deploy-check" "$TARGET_SCRIPT"; then
     echo "Test: Deploy flag definition... ✅ PASSED"
else
     echo "Test: Deploy flag definition... ❌ FAILED"
     FAILURES=$((FAILURES + 1))
fi

if [ $FAILURES -eq 0 ]; then
    exit 0
else
    exit 1
fi
