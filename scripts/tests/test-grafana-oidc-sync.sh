#!/bin/bash
# scripts/tests/test-grafana-oidc-sync.sh

# =============================================================================
# Grafana OIDC Sync Verification Test
# -----------------------------------------------------------------------------
# Checks for potential email conflicts between Grafana local users and Keycloak
# users that could cause 'User sync failed' errors during login.
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load Utils & Env
source "${PROJECT_DIR}/.env"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to run Keycloak command
kcadm() {
    docker exec keycloak /opt/keycloak/bin/kcadm.sh "$@"
}

# =============================================================================
# Main Verification Logic
# =============================================================================

print_header "TEST: Grafana OIDC User Sync Safety"

# 1. Check Grafana Admin Email via API
print_info "Checking Grafana internal users..."
GRAFANA_USERS=$(curl -s "http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3001/api/users")

if echo "$GRAFANA_USERS" | grep -q "Invalid username or password"; then
    print_error "Failed to authenticate with Grafana API. Check GRAFANA_ADMIN_PASSWORD."
    exit 1
fi

# Extract Admin Email from Grafana
GRAFANA_ADMIN_EMAIL=$(echo "$GRAFANA_USERS" | jq -r '.[] | select(.isAdmin==true) | .email')
print_info "Grafana internal admin email: $GRAFANA_ADMIN_EMAIL"

# 2. Check Keycloak Users
print_info "Checking Keycloak users..."
# Authenticate kcadm
kcadm config credentials --server http://localhost:8080 --realm master --user "${KEYCLOAK_ADMIN_USER:-admin}" --password "${KEYCLOAK_ADMIN_PASSWORD}" >/dev/null 2>&1

KEYCLOAK_USERS=$(kcadm get users -r master --fields username,email,enabled)
KEYCLOAK_ADMIN_EMAIL_KC=$(echo "$KEYCLOAK_USERS" | jq -r '.[] | select(.username=="'"${KEYCLOAK_ADMIN_USER:-admin}"'") | .email')

if [ -z "$KEYCLOAK_ADMIN_EMAIL_KC" ] || [ "$KEYCLOAK_ADMIN_EMAIL_KC" == "null" ]; then
    # Fallback: check if we are using a custom admin
    KEYCLOAK_ADMIN_EMAIL_KC=$(echo "$KEYCLOAK_USERS" | jq -r '.[] | select(.username=="'"${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-emujicad}"'") | .email')
fi
print_info "Keycloak admin email: $KEYCLOAK_ADMIN_EMAIL_KC"

# 3. Conflict Analysis
print_info "Analyzing synchronization safety..."

if [ "$GRAFANA_ADMIN_EMAIL" == "$KEYCLOAK_ADMIN_EMAIL_KC" ]; then
    # If users match, check if they are linked
    # We can check via Grafana API /api/user/auth-tokens but generic oauth ID varies.
    # The safest state is if they match.
    
    # Check if Grafana OIDC is configured to allow lookup
    ALLOW_LOOKUP=$(grep "GF_AUTH_GENERIC_OAUTH_ALLOW_OAUTH_SIGNIN_WITH_EMAIL_LOOKUP" "${PROJECT_DIR}/docker-compose.yml" || echo "Not Found")
    
    if [[ "$ALLOW_LOOKUP" == *"true"* ]]; then
        print_success "EMAILS MATCH and Lookup is ENABLED. This is the correct configuration."
        print_success "Grafana will find the existing user by email and log them in."
    else
        print_warning "EMAILS MATCH but 'email lookup' might be DISABLED or MISSING in docker-compose.yml."
        print_warning "Current config setting: $ALLOW_LOOKUP"
        print_warning "If lookup is false, this login WILL FAIL with 'User sync failed'."
        exit 1
    fi
else
    print_warning "EMAILS DO NOT MATCH ($GRAFANA_ADMIN_EMAIL vs $KEYCLOAK_ADMIN_EMAIL_KC)"
    print_info "This is generally SAFE as long as the accounts are intended to be separate."
    print_info "However, if you intend for the Keycloak user to BE the Grafana admin, they must match."
fi

print_success "OIDC Sync verification passed (No immediate blocker detected)."
