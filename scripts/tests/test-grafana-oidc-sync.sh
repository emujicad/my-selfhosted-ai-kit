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

# Function to validate environment variables
check_required_vars() {
    local missing_vars=0
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            print_error "Variable '$var' is required but not set in .env"
            missing_vars=1
        else
            # Placeholder validation
            local value="${!var}"
            if [[ "$value" == *"change_me"* ]] || [[ "$value" == *"your-"* ]]; then
                 print_warning "Variable '$var' seems to use a placeholder value: $value"
            fi
        fi
    done
    if [ $missing_vars -eq 1 ]; then
        print_error "Please configure required variables in your .env file."
        exit 1
    fi
}

# Validate Critical Vars
check_required_vars "GRAFANA_ADMIN_PASSWORD" "KEYCLOAK_ADMIN_USER" "KEYCLOAK_ADMIN_PASSWORD"

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
# Initialize variable to avoid unbound error
KEYCLOAK_ADMIN_USER_ACTUAL="${KEYCLOAK_ADMIN_USER:-admin}"

# Authenticate kcadm
kcadm config credentials --server http://localhost:8080 --realm master --user "${KEYCLOAK_ADMIN_USER:-admin}" --password "${KEYCLOAK_ADMIN_PASSWORD}" >/dev/null 2>&1

KEYCLOAK_USERS=$(kcadm get users -r master --fields username,email,enabled)
KEYCLOAK_ADMIN_EMAIL_KC=$(echo "$KEYCLOAK_USERS" | jq -r '.[] | select(.username=="'"${KEYCLOAK_ADMIN_USER:-admin}"'") | .email')

if [ -z "$KEYCLOAK_ADMIN_EMAIL_KC" ] || [ "$KEYCLOAK_ADMIN_EMAIL_KC" == "null" ]; then
    # Fallback: check if we are using a custom admin
    KEYCLOAK_ADMIN_EMAIL_KC=$(echo "$KEYCLOAK_USERS" | jq -r '.[] | select(.username=="'"${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-emujicad}"'") | .email')
    KEYCLOAK_ADMIN_USER_ACTUAL="${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-emujicad}"
fi
print_info "Keycloak user ($KEYCLOAK_ADMIN_USER_ACTUAL) email: $KEYCLOAK_ADMIN_EMAIL_KC"

# 3. Conflict Analysis
print_info "Analyzing synchronization safety..."

if [ "$GRAFANA_ADMIN_EMAIL" == "$KEYCLOAK_ADMIN_EMAIL_KC" ]; then
    # If users match, check if they are linked
    # We can check via Grafana API /api/user/auth-tokens but generic oauth ID varies.
    # The safest state is if they match.
    
    # Check if Grafana OIDC is configured to allow lookup
    ALLOW_LOOKUP=$(grep "GF_AUTH_GENERIC_OAUTH_ALLOW_OAUTH_SIGNIN_WITH_EMAIL_LOOKUP" "${PROJECT_DIR}/docker-compose.yml" || echo "Not Found")
    
    if [[ "$ALLOW_LOOKUP" == *"true"* ]]; then
        print_success "EMAILS MATCH and Lookup is ENABLED. You will log in as the internal Super Admin."
    else
        print_warning "EMAILS MATCH but 'email lookup' might be DISABLED or MISSING in docker-compose.yml."
        exit 1
    fi
else
    print_info "EMAILS DO NOT MATCH ($GRAFANA_ADMIN_EMAIL vs $KEYCLOAK_ADMIN_EMAIL_KC)"
    
    # Check for Role Mapping (The robust way to handle this)
    ROLE_MAPPING=$(grep "GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH" "${PROJECT_DIR}/docker-compose.yml" || echo "Not Found")
    
    if [[ "$ROLE_MAPPING" == *"grafana-admin"* ]]; then
        print_success "SAFE: Emails differ, but OIDC Role Mapping is DETECTED."
        print_success "User '$KEYCLOAK_ADMIN_USER_ACTUAL' should receive Admin rights via Role Mapping."
    else
        print_warning "⚠️  EMAILS DIFFER and NO Role Mapping detected."
        print_warning "You might log in as a Viewer/Editor without Admin rights."
        # This is a warning, not a hard failure, as maybe they want a viewer account.
    fi
fi

print_success "OIDC Sync verification passed."
