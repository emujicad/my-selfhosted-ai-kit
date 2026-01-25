#!/bin/bash
# scripts/auth-manager.sh

# =============================================================================
# MY SELF-HOSTED AI KIT - Unified Auth Manager
# =============================================================================
# Master script for all Identity & Authentication tasks (Keycloak):
# - Setup Roles (--setup-roles)
# - Create Admin (--create-admin)
# - Fix Clients (--fix-clients)
# - Jenkins Setup (--setup-jenkins)
# - General Health & Status
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# =============================================================================
# Configuration & Helpers
# =============================================================================

ENV_FILE="${PROJECT_DIR}/.env"
if [ -f "$ENV_FILE" ]; then source "$ENV_FILE"; fi

KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"
# Support both KEYCLOAK_ADMIN (standard) and KEYCLOAK_ADMIN_USER (.env variance)
ADMIN_USER="${KEYCLOAK_ADMIN:-${KEYCLOAK_ADMIN_USER:-admin}}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:-}"

# Function to run kcadm.sh command
kcadm() {
    local DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then DOCKER_CMD="sudo docker"; fi
    $DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh "$@"
}

# Function to authenticate with Keycloak
authenticate() {
    print_info "Authenticating with Keycloak..."
    if [ -z "$ADMIN_PASS" ]; then
        print_error "KEYCLOAK_ADMIN_PASSWORD not set in environment or .env"
        return 1
    fi
    
    if kcadm config credentials --server http://localhost:8080 --realm "$KEYCLOAK_REALM" --user "$ADMIN_USER" --password "$ADMIN_PASS" > /dev/null 2>&1; then
        print_success "Authenticated successfully"
        return 0
    else
        print_error "Failed to authenticate (User: $ADMIN_USER)"
        return 1
    fi
}

check_keycloak_running() {
    local DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then DOCKER_CMD="sudo docker"; fi

    if ! $DOCKER_CMD ps | grep -q "keycloak"; then
        print_error "Keycloak container is NOT running."
        echo "   Please start the stack first: ./scripts/stack-manager.sh start"
        exit 1
    fi
    
    # Wait for health
    print_info "Checking Keycloak health..."
    local MAX_RETRIES=30
    local RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s -f http://localhost:8080/health/ready > /dev/null 2>&1; then
            print_success "Keycloak is running and ready"
            return 0
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   Waiting for Keycloak... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
    done
    
    print_error "Keycloak did not become ready in time"
    exit 1
}

# =============================================================================
# Logic: Setup Roles (--setup-roles)
# =============================================================================

create_client_role() {
    local client_id=$1
    local role_name=$2
    local role_description=$3
    
    if kcadm get clients/$client_id/roles/$role_name -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
        echo "   - Role '$role_name' already exists"
    else
        if kcadm create clients/$client_id/roles -r "$KEYCLOAK_REALM" -s name=$role_name -s "description=$role_description" 2>/dev/null; then
            echo "   + Role '$role_name' created"
        else
            print_error "Failed to create role '$role_name'"
        fi
    fi
}

create_role_mapper() {
    local client_id=$1
    local service_name=$2
    local mapper_name="${service_name}-roles"
    
    if kcadm get clients/$client_id/protocol-mappers/models -r "$KEYCLOAK_REALM" 2>/dev/null | grep -q "$mapper_name"; then
        echo "   - Mapper '$mapper_name' already exists"
    else
        if kcadm create clients/$client_id/protocol-mappers/models -r "$KEYCLOAK_REALM" \
            -s name=$mapper_name \
            -s protocol=openid-connect \
            -s protocolMapper=oidc-usermodel-client-role-mapper \
            -s 'config."claim.name"=roles' \
            -s 'config."jsonType.label"=String' \
            -s 'config."multivalued"=true' \
            -s "config.\"client.id\"=$service_name" > /dev/null 2>&1; then
            echo "   + Mapper '$mapper_name' created"
        else
            print_error "Failed to create mapper '$mapper_name'"
        fi
    fi
}

setup_service_roles() {
    local name=$1
    local client_key=$2
    local roles=("${!3}") # Array ref
    
    print_info "Configuring $name roles..."
    local CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=$client_key --fields id --format csv --noquotes 2>/dev/null | head -1)
    
    if [ -z "$CLIENT_ID" ]; then
        print_warning "$name client not found - Skipping"
        return 0
    fi
    
    for role in "${roles[@]}"; do
        create_client_role "$CLIENT_ID" "$role" "$name Role"
    done
    
    create_role_mapper "$CLIENT_ID" "$client_key"
}

action_setup_roles() {
    print_header "SETTING UP KEYCLOAK ROLES & GROUPS"
    check_keycloak_running
    authenticate || exit 1
    
    # Groups
    print_info "Setting up Groups..."
    for group in "super-admins" "admins" "users" "viewers"; do
        if kcadm get groups -r "$KEYCLOAK_REALM" -q name="$group" 2>/dev/null | grep -q "\"name\" : \"$group\""; then
            echo "   - Group '$group' already exists"
        else
            kcadm create groups -r "$KEYCLOAK_REALM" -s name="$group"
            echo "   + Group '$group' created"
        fi
    done
    
    # Grafana
    GRAFANA_ROLES=("grafana-admin" "grafana-editor" "grafana-viewer")
    setup_service_roles "Grafana" "grafana" GRAFANA_ROLES[@]
    
    # Open WebUI
    WEBUI_ROLES=("openwebui-admin" "openwebui-user")
    setup_service_roles "Open WebUI" "open-webui" WEBUI_ROLES[@]
    
    # n8n
    N8N_ROLES=("n8n-admin" "n8n-user")
    setup_service_roles "n8n" "n8n" N8N_ROLES[@]
    
    # Jenkins
    JENKINS_ROLES=("jenkins-admin" "jenkins-user")
    setup_service_roles "Jenkins" "jenkins" JENKINS_ROLES[@]
    
    print_success "Role setup completed"
}

# =============================================================================
# Logic: Create Admin (--create-admin)
# =============================================================================

action_create_admin() {
    print_header "CREATING PERMANENT ADMIN USER"
    check_keycloak_running
    
    local NEW_USER="${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-emujicad}"
    local NEW_PASS="${KEYCLOAK_PERMANENT_ADMIN_PASSWORD:-}"
    local NEW_EMAIL="${KEYCLOAK_PERMANENT_ADMIN_EMAIL:-emujicad@gmail.com}"
    
    if [ -z "$NEW_PASS" ]; then
        print_error "KEYCLOAK_PERMANENT_ADMIN_PASSWORD not set in .env"
        exit 1
    fi

    # 1. Get Token (Temporary Admin)
    local TEMP_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
        -d "username=$ADMIN_USER" -d "password=$ADMIN_PASS" -d "grant_type=password" -d "client_id=admin-cli" | \
        grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')

    if [ -z "$TEMP_TOKEN" ]; then
        print_error "Failed to get token for current admin ($ADMIN_USER)"
        exit 1
    fi

    # 2. Check if exists
    local USER_CHECK=$(curl -s -X GET "http://localhost:8080/admin/realms/master/users?username=$NEW_USER" \
        -H "Authorization: Bearer $TEMP_TOKEN")
    
    if echo "$USER_CHECK" | grep -q "\"username\":\"$NEW_USER\""; then
        print_info "User '$NEW_USER' already exists. Updating password..."
        local USER_ID=$(echo "$USER_CHECK" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
        
        # Reset Password
        curl -s -X PUT "http://localhost:8080/admin/realms/master/users/$USER_ID/reset-password" \
            -H "Authorization: Bearer $TEMP_TOKEN" -H "Content-Type: application/json" \
            -d "{\"type\":\"password\",\"value\":\"$NEW_PASS\",\"temporary\":false}"
        
        print_success "Password updated for '$NEW_USER'"
        return 0
    fi
    
    # 3. Create User
    print_info "Creating user '$NEW_USER'..."
    curl -s -X POST "http://localhost:8080/admin/realms/master/users" \
        -H "Authorization: Bearer $TEMP_TOKEN" -H "Content-Type: application/json" \
        -d "{\"username\":\"$NEW_USER\",\"email\":\"$NEW_EMAIL\",\"enabled\":true,\"firstName\":\"Admin\",\"lastName\":\"User\"}"
        
    # 4. Get New ID & Set Password
    local NEW_ID_CHECK=$(curl -s "http://localhost:8080/admin/realms/master/users?username=$NEW_USER" -H "Authorization: Bearer $TEMP_TOKEN")
    local NEW_ID=$(echo "$NEW_ID_CHECK" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
    
    curl -s -X PUT "http://localhost:8080/admin/realms/master/users/$NEW_ID/reset-password" \
        -H "Authorization: Bearer $TEMP_TOKEN" -H "Content-Type: application/json" \
        -d "{\"type\":\"password\",\"value\":\"$NEW_PASS\",\"temporary\":false}"
        
    # 5. Assign Admin Role
    local ROLE_INFO=$(curl -s "http://localhost:8080/admin/realms/master/roles/admin" -H "Authorization: Bearer $TEMP_TOKEN")
    local ROLE_ID=$(echo "$ROLE_INFO" | grep -o '"id":"[^"]*' | sed 's/"id":"//')
    
    curl -s -X POST "http://localhost:8080/admin/realms/master/users/$NEW_ID/role-mappings/realm" \
        -H "Authorization: Bearer $TEMP_TOKEN" -H "Content-Type: application/json" \
        -d "[{\"id\":\"$ROLE_ID\",\"name\":\"admin\"}]"
        
    print_success "User '$NEW_USER' created and promoted to Admin"
    
    print_warning "NOTE: To delete the temporary admin '$ADMIN_USER', do it manually or verify new login first."
}

# =============================================================================
# Logic: Fix Clients (--fix-clients)
# =============================================================================

action_fix_clients() {
    print_header "RECREATING OIDC CLIENTS"
    check_keycloak_running
    authenticate || exit 1
    
    # Simple recreation logic for known clients
    # Grafana
    if ! kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=grafana >/dev/null 2>&1; then
        print_info "Recreating Grafana Client..."
        kcadm create clients -r "$KEYCLOAK_REALM" -s clientId=grafana -s enabled=true -s protocol=openid-connect -s publicClient=false -s bearerOnly=false -s "redirectUris=[\"*\"]"
        print_success "Grafana Client Created"
    else
        print_info "Grafana client exists."
    fi
    
    print_success "Client check completed (Use UI for detailed config)"
}

# =============================================================================
# Logic: Jenkins Setup (--setup-jenkins)
# =============================================================================

action_setup_jenkins() {
    print_header "SETTING UP JENKINS OIDC"
    
    if ! docker ps | grep -q "jenkins"; then
        print_error "Jenkins container is NOT running."
        echo "   Please start the stack first: ./scripts/stack-manager.sh start"
        exit 1
    fi

    # 1. Install Plugins
    print_info "Installing/Verifying 'oic-auth' plugin..."
    if docker exec jenkins jenkins-plugin-cli --plugins oic-auth configuration-as-code; then
        print_success "Plugins installed/verified."
    else
        print_error "Failed to install plugins."
        exit 1
    fi

    # 2. Configure OIDC via Groovy Init Script
    print_info "Configuring OIDC Security Realm..."
    
    # Create temporary groovy script
    cat <<EOF > /tmp/jenkins_oidc_setup.groovy
import hudson.security.*
import org.jenkinsci.plugins.oic.*
import jenkins.model.*

def env = System.getenv()
def clientId = env['JENKINS_OIDC_CLIENT_ID']
def clientSecret = env['JENKINS_OIDC_CLIENT_SECRET']
def keycloakUrl = env['KEYCLOAK_URL_PUBLIC'] ?: "http://localhost:8080"
def realmName = env['KEYCLOAK_REALM'] ?: "master"

println "Configuring OIDC for Client ID: \${clientId}"

def tokenServerUrl = "\${keycloakUrl}/realms/\${realmName}/protocol/openid-connect/token"
def authServerUrl = "\${keycloakUrl}/realms/\${realmName}/protocol/openid-connect/auth"
def userInfoUrl = "\${keycloakUrl}/realms/\${realmName}/protocol/openid-connect/userinfo"
def jwksUrl = "\${keycloakUrl}/realms/\${realmName}/protocol/openid-connect/certs"

def oicRealm = new OicSecurityRealm(
    clientId,
    clientSecret,
    tokenServerUrl,
    authServerUrl,
    userInfoUrl,
    jwksUrl,
    "openid email profile", // scopes
    false, // disable ssl verification
    "preferred_username", // user name field
    "name", // full name field
    "email", // email field
    null  // groups field
)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
Jenkins.instance.setSecurityRealm(oicRealm)
Jenkins.instance.setAuthorizationStrategy(strategy)
Jenkins.instance.save()
println "OIDC Security Realm Configured Successfully"
EOF

    # Copy script to container
    docker cp /tmp/jenkins_oidc_setup.groovy jenkins:/var/jenkins_home/init.groovy.d/auth-oidc.groovy
    
    # 3. Restart to apply
    print_info "Restarting Jenkins to apply changes..."
    if docker restart jenkins; then
        print_success "Jenkins restarted."
        print_info "Please check logs: docker logs -f jenkins"
    else
        print_error "Failed to restart Jenkins."
    fi
     
    # Cleanup
    rm -f /tmp/jenkins_oidc_setup.groovy
}

# =============================================================================
# Main Router
# =============================================================================

show_help() {
    echo "Usage: ./auth-manager.sh [FLAG]"
    echo ""
    echo "Flags:"
    echo "  --setup-roles     Create Realms, Roles, and Groups structure"
    echo "  --create-admin    Create permanent admin user and secure account"
    echo "  --fix-clients     Recreate OIDC clients (Grafana, n8n, etc.) if broken"
    echo "  --setup-jenkins   Install plugins and configure OIDC for Jenkins"
    echo "  --status          Check Keycloak health and status"
    echo "  --help            Show this help"
    echo ""
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    --setup-roles)
        action_setup_roles
        ;;
    --create-admin)
        action_create_admin
        ;;
    --fix-clients)
        action_fix_clients
        ;;
    --setup-jenkins)
        action_setup_jenkins
        ;;
    --status)
        check_keycloak_running
        ;;
    --help)
        show_help
        ;;
    *)
        print_error "Unknown flag: $1"
        show_help
        exit 1
        ;;
esac
