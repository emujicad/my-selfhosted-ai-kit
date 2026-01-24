#!/bin/bash

# ============================================================================
# Script: keycloak-roles-manager.sh
# Description: Unified script to manage all Keycloak roles and groups
# Usage: ./scripts/keycloak-roles-manager.sh [COMMAND] [OPTIONS]
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Keycloak configuration
KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"
ADMIN_USER="${KEYCLOAK_ADMIN_USER:-emujicad}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"

if [ -z "$ADMIN_PASS" ]; then
    echo -e "${RED}Error: KEYCLOAK_ADMIN_PASSWORD not set in .env${NC}"
    exit 1
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to run kcadm.sh command
kcadm() {
    docker exec keycloak /opt/keycloak/bin/kcadm.sh "$@"
}

# Function to authenticate with Keycloak
authenticate() {
    echo -e "${BLUE}Authenticating with Keycloak...${NC}"
    if kcadm config credentials --server http://localhost:8080 --realm "$KEYCLOAK_REALM" --user "$ADMIN_USER" --password "$ADMIN_PASS" 2>&1; then
        echo -e "${GREEN}✓ Authenticated successfully${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to authenticate${NC}"
        return 1
    fi
}

# Function to wait for Keycloak to be ready
wait_for_keycloak() {
    echo -e "${BLUE}Checking Keycloak availability...${NC}"
    local MAX_RETRIES=30
    local RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s http://localhost:8080/health/ready > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Keycloak is ready${NC}"
            return 0
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -e "${YELLOW}Waiting for Keycloak... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
        sleep 2
    done

    echo -e "${RED}Error: Keycloak did not become ready in time${NC}"
    return 1
}

# Function to create a client role
create_client_role() {
    local client_id=$1
    local role_name=$2
    local role_description=$3
    
    if kcadm get clients/$client_id/roles/$role_name -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Role '$role_name' already exists${NC}"
        return 0
    else
        echo -e "${BLUE}Creating role '$role_name'...${NC}"
        if kcadm create clients/$client_id/roles -r "$KEYCLOAK_REALM" -s name=$role_name -s "description=$role_description"; then
            echo -e "${GREEN}✓ Role '$role_name' created${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to create role '$role_name'${NC}"
            return 1
        fi
    fi
}

# Function to create role mapper
create_role_mapper() {
    local client_id=$1
    local service_name=$2
    
    local mapper_name="${service_name}-roles"
    
    # Check if mapper already exists
    local MAPPER_EXISTS=$(kcadm get clients/$client_id/protocol-mappers/models -r "$KEYCLOAK_REALM" 2>/dev/null | grep -c "$mapper_name" || true)
    
    if [ "$MAPPER_EXISTS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Role mapper '$mapper_name' already exists${NC}"
        return 0
    else
        echo -e "${BLUE}Creating role mapper '$mapper_name'...${NC}"
        if kcadm create clients/$client_id/protocol-mappers/models -r "$KEYCLOAK_REALM" \
            -s name=$mapper_name \
            -s protocol=openid-connect \
            -s protocolMapper=oidc-usermodel-client-role-mapper \
            -s 'config."claim.name"=roles' \
            -s 'config."jsonType.label"=String' \
            -s 'config."multivalued"=true' \
            -s 'config."userinfo.token.claim"=true' \
            -s 'config."id.token.claim"=true' \
            -s 'config."access.token.claim"=true' \
            -s "config.\"client.id\"=$service_name"; then
            echo -e "${GREEN}✓ Role mapper configured${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to create role mapper${NC}"
            return 1
        fi
    fi
}

# ============================================================================
# SERVICE CONFIGURATION FUNCTIONS
# ============================================================================

# Configure Grafana roles
setup_grafana() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}Configuring Grafana Roles${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    
    # Get Grafana client ID
    echo -e "${BLUE}Getting Grafana client ID...${NC}"
    local CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=grafana --fields id --format csv --noquotes 2>/dev/null | head -1)
    
    if [ -z "$CLIENT_ID" ]; then
        echo -e "${RED}Error: Grafana client not found${NC}"
        echo -e "${YELLOW}Make sure Grafana client is configured in Keycloak${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Grafana client ID: $CLIENT_ID${NC}"
    echo
    
    # Create roles
    echo -e "${BLUE}Creating Grafana roles...${NC}"
    create_client_role "$CLIENT_ID" "grafana-admin" "Full Grafana administrator"
    create_client_role "$CLIENT_ID" "grafana-editor" "Can edit dashboards"
    create_client_role "$CLIENT_ID" "grafana-viewer" "Read-only access"
    echo
    
    # Configure role mapper
    echo -e "${BLUE}Configuring role mapper for Grafana...${NC}"
    create_role_mapper "$CLIENT_ID" "grafana"
    echo
    
    echo -e "${GREEN}✓ Grafana roles configuration completed${NC}"
    return 0
}

# Configure Open WebUI roles
setup_openwebui() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}Configuring Open WebUI Roles${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    
    local CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=open-webui --fields id --format csv --noquotes 2>/dev/null | head -1)
    
    if [ -z "$CLIENT_ID" ]; then
        echo -e "${RED}Error: Open WebUI client not found${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Open WebUI client ID: $CLIENT_ID${NC}"
    echo
    
    echo -e "${BLUE}Creating Open WebUI roles...${NC}"
    create_client_role "$CLIENT_ID" "openwebui-admin" "Full Open WebUI administrator"
    create_client_role "$CLIENT_ID" "openwebui-user" "Regular Open WebUI user"
    echo
    
    echo -e "${BLUE}Configuring role mapper for Open WebUI...${NC}"
    create_role_mapper "$CLIENT_ID" "open-webui"
    echo
    
    echo -e "${GREEN}✓ Open WebUI roles configuration completed${NC}"
    return 0
}

# Configure n8n roles
setup_n8n() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}Configuring n8n Roles${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    
    local CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=n8n --fields id --format csv --noquotes 2>/dev/null | head -1)
    
    if [ -z "$CLIENT_ID" ]; then
        echo -e "${RED}Error: n8n client not found${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ n8n client ID: $CLIENT_ID${NC}"
    echo
    
    echo -e "${BLUE}Creating n8n roles...${NC}"
    create_client_role "$CLIENT_ID" "n8n-admin" "Full n8n administrator"
    create_client_role "$CLIENT_ID" "n8n-user" "Regular n8n user"
    echo
    
    echo -e "${BLUE}Configuring role mapper for n8n...${NC}"
    create_role_mapper "$CLIENT_ID" "n8n"
    echo
    
    echo -e "${GREEN}✓ n8n roles configuration completed${NC}"
    return 0
}

# Configure Jenkins roles
setup_jenkins() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}Configuring Jenkins Roles${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    
    local CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=jenkins --fields id --format csv --noquotes 2>/dev/null | head -1)
    
    if [ -z "$CLIENT_ID" ]; then
        echo -e "${YELLOW}⚠ Jenkins client not found - skipping${NC}"
        echo -e "${BLUE}Note: Run this command when Jenkins is configured${NC}"
        return 0
    fi
    echo -e "${GREEN}✓ Jenkins client ID: $CLIENT_ID${NC}"
    echo
    
    echo -e "${BLUE}Creating Jenkins roles...${NC}"
    create_client_role "$CLIENT_ID" "jenkins-admin" "Full Jenkins administrator"
    create_client_role "$CLIENT_ID" "jenkins-user" "Regular Jenkins user"
    echo
    
    echo -e "${BLUE}Configuring role mapper for Jenkins...${NC}"
    create_role_mapper "$CLIENT_ID" "jenkins"
    echo
    
    echo -e "${GREEN}✓ Jenkins roles configuration completed${NC}"
    return 0
}

# Configure groups
setup_groups() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}Configuring Groups${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    
    echo -e "${BLUE}Creating groups...${NC}"
    
    for group in "super-admins" "admins" "users" "viewers"; do
        if kcadm get groups -r "$KEYCLOAK_REALM" -q name="$group" 2>/dev/null | grep -q "\"name\" : \"$group\""; then
            echo -e "${YELLOW}⚠ Group '$group' already exists${NC}"
        else
            echo -e "${BLUE}Creating group '$group'...${NC}"
            if kcadm create groups -r "$KEYCLOAK_REALM" -s name="$group"; then
                echo -e "${GREEN}✓ Group '$group' created${NC}"
            else
                echo -e "${RED}✗ Failed to create group '$group'${NC}"
            fi
        fi
    done
    
    echo
    echo -e "${GREEN}✓ Groups configuration completed${NC}"
    return 0
}

# ============================================================================
# MAIN COMMANDS
# ============================================================================

# Setup all roles and groups
setup_all() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}Keycloak Complete RBAC Setup${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    
    # Check if Keycloak is running
    if ! docker ps | grep -q keycloak; then
        echo -e "${RED}Error: Keycloak is not running${NC}"
        echo -e "${YELLOW}Start Keycloak with: ./scripts/stack-manager.sh start security${NC}"
        return 1
    fi
    
    # Wait for Keycloak
    if ! wait_for_keycloak; then
        return 1
    fi
    echo
    
    # Authenticate
    if ! authenticate; then
        return 1
    fi
    echo
    
    # Setup components
    local FAILED=0
    
    echo -e "${BLUE}[1/5] Setting up Groups...${NC}"
    setup_groups || FAILED=1
    echo
    
    echo -e "${BLUE}[2/5] Setting up Grafana roles...${NC}"
    setup_grafana || FAILED=1
    echo
    
    echo -e "${BLUE}[3/5] Setting up Open WebUI roles...${NC}"
    setup_openwebui || FAILED=1
    echo
    
    echo -e "${BLUE}[4/5] Setting up n8n roles...${NC}"
    setup_n8n || FAILED=1
    echo
    
    echo -e "${BLUE}[5/5] Setting up Jenkins roles...${NC}"
    setup_jenkins  # Don't fail on Jenkins
    echo
    
    # Summary
    echo -e "${BLUE}============================================================================${NC}"
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ Keycloak RBAC setup completed successfully${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        echo
        echo -e "${BLUE}Summary:${NC}"
        echo -e "  ✓ 4 groups created"
        echo -e "  ✓ 3 Grafana roles created"
        echo -e "  ✓ 2 Open WebUI roles created"
        echo -e "  ✓ 2 n8n roles created"
        echo -e "  ✓ 2 Jenkins roles created (if Jenkins client exists)"
        echo
        echo -e "${YELLOW}Next steps:${NC}"
        echo -e "  1. Assign roles to groups (manual via Keycloak UI)"
        echo -e "  2. Add users to groups (manual via Keycloak UI)"
        echo -e "  3. Test OAuth integration with services"
        return 0
    else
        echo -e "${RED}✗ Keycloak RBAC setup completed with errors${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        return 1
    fi
}

# Show help
show_help() {
    cat <<'HELP_EOF'
Keycloak Roles Manager
════════════════════════════════════════════════════════

USAGE:
    ./scripts/keycloak-roles-manager.sh [COMMAND]

COMMANDS:
    all             Setup all roles and groups (recommended)
    groups          Setup only groups
    grafana         Setup only Grafana roles
    openwebui       Setup only Open WebUI roles
    n8n             Setup only n8n roles
    jenkins         Setup only Jenkins roles
    help            Show this help message

EXAMPLES:
    # Setup everything (recommended)
    ./scripts/keycloak-roles-manager.sh all

    # Setup only Grafana roles
    ./scripts/keycloak-roles-manager.sh grafana

    # Setup only groups
    ./scripts/keycloak-roles-manager.sh groups

NOTES:
    - Keycloak must be running before executing this script
    - Existing roles/groups will be skipped (safe to re-run)
    - Jenkins setup is optional (skipped if client doesn't exist)

HELP_EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

COMMAND=${1:-help}

case "$COMMAND" in
    all)
        setup_all
        ;;
    groups)
        wait_for_keycloak && authenticate && setup_groups
        ;;
    grafana)
        wait_for_keycloak && authenticate && setup_grafana
        ;;
    openwebui)
        wait_for_keycloak && authenticate && setup_openwebui
        ;;
    n8n)
        wait_for_keycloak && authenticate && setup_n8n
        ;;
    jenkins)
        wait_for_keycloak && authenticate && setup_jenkins
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo
        show_help
        exit 1
        ;;
esac
