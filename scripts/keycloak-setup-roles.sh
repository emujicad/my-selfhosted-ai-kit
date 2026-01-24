#!/bin/bash

# ============================================================================
# Script: keycloak-setup-roles.sh
# Description: Configure roles and groups in Keycloak (GRADUAL APPROACH)
# Author: AI Stack Management
# Date: 2026-01-24
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Keycloak configuration
KEYCLOAK_URL="${KEYCLOAK_URL_INTERNAL:-http://keycloak:8080}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"
ADMIN_USER="${KEYCLOAK_ADMIN:-emujicad}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"

# Validation
if [ -z "$ADMIN_PASS" ]; then
    echo -e "${RED}Error: KEYCLOAK_ADMIN_PASSWORD not set in .env${NC}"
    exit 1
fi

# Function to get access token
get_access_token() {
    local response=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${ADMIN_USER}" \
        -d "password=${ADMIN_PASS}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli")
    
    echo "$response" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//'
}

# Function to check if group exists
group_exists() {
    local group_name=$1
    local token=$2
    
    local response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/groups" \
        -H "Authorization: Bearer ${token}")
    
    if echo "$response" | grep -q "\"name\":\"${group_name}\""; then
        return 0
    else
        return 1
    fi
}

# Function to check if realm role exists
realm_role_exists() {
    local role_name=$1
    local token=$2
    
    local response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/roles/${role_name}" \
        -H "Authorization: Bearer ${token}")
    
    if echo "$response" | grep -q "\"name\":\"${role_name}\""; then
        return 0
    else
        return 1
    fi
}

# Function to check if client role exists
client_role_exists() {
    local client_name=$1
    local role_name=$2
    local token=$3
    
    # Get client ID
    local client_response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${client_name}" \
        -H "Authorization: Bearer ${token}")
    
    local client_id=$(echo "$client_response" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
    
    if [ -z "$client_id" ]; then
        echo -e "${YELLOW}⚠ Client '${client_name}' not found${NC}"
        return 1
    fi
    
    # Check if role exists
    local role_response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${client_id}/roles/${role_name}" \
        -H "Authorization: Bearer ${token}")
    
    if echo "$role_response" | grep -q "\"name\":\"${role_name}\""; then
        return 0
    else
        return 1
    fi
}

# Function to create group
create_group() {
    local group_name=$1
    local token=$2
    
    local payload=$(cat <<EOF
{
    "name": "${group_name}"
}
EOF
)
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/groups" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Function to create realm role
create_realm_role() {
    local role_name=$1
    local description=$2
    local token=$3
    
    local payload=$(cat <<EOF
{
    "name": "${role_name}",
    "description": "${description}"
}
EOF
)
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/roles" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Function to create client role
create_client_role() {
    local client_name=$1
    local role_name=$2
    local description=$3
    local token=$4
    
    # Get client ID
    local client_response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${client_name}" \
        -H "Authorization: Bearer ${token}")
    
    local client_id=$(echo "$client_response" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
    
    if [ -z "$client_id" ]; then
        echo -e "${RED}Error: Client '${client_name}' not found${NC}"
        return 1
    fi
    
    local payload=$(cat <<EOF
{
    "name": "${role_name}",
    "description": "${description}",
    "clientRole": true
}
EOF
)
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${client_id}/roles" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Function to create role mapper for client
create_role_mapper() {
    local client_name=$1
    local token=$2
    
    # Get client ID
    local client_response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${client_name}" \
        -H "Authorization: Bearer ${token}")
    
    local client_id=$(echo "$client_response" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
    
    if [ -z "$client_id" ]; then
        echo -e "${RED}Error: Client '${client_name}' not found${NC}"
        return 1
    fi
    
    # Create client roles mapper
    local payload=$(cat <<EOF
{
    "name": "${client_name}-roles",
    "protocol": "openid-connect",
    "protocolMapper": "oidc-usermodel-client-role-mapper",
    "consentRequired": false,
    "config": {
        "claim.name": "roles",
        "jsonType.label": "String",
        "multivalued": "true",
        "userinfo.token.claim": "true",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "client.id": "${client_name}"
    }
}
EOF
)
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${client_id}/protocol-mappers/models" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Main execution
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Keycloak Roles and Groups Configuration${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

# Get access token
echo -e "${BLUE}Step 1: Getting access token...${NC}"
ACCESS_TOKEN=$(get_access_token)

if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Error: Failed to get access token${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Access token obtained${NC}"
echo

# Parse command line argument for service
SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
    echo -e "${YELLOW}Usage: $0 <service>${NC}"
    echo -e "${YELLOW}Services: grafana, openwebui, n8n, jenkins, groups${NC}"
    exit 1
fi

case "$SERVICE" in
    grafana)
        echo -e "${BLUE}============================================================================${NC}"
        echo -e "${BLUE}Configuring Grafana Roles${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        echo
        
        # Check and create Grafana roles
        echo -e "${BLUE}Step 2: Checking existing Grafana roles...${NC}"
        
        if client_role_exists "grafana" "grafana-admin" "$ACCESS_TOKEN"; then
            echo -e "${YELLOW}⚠ Role 'grafana-admin' already exists${NC}"
        else
            echo -e "${BLUE}Creating role 'grafana-admin'...${NC}"
            create_client_role "grafana" "grafana-admin" "Full Grafana administrator" "$ACCESS_TOKEN"
            echo -e "${GREEN}✓ Role 'grafana-admin' created${NC}"
        fi
        
        if client_role_exists "grafana" "grafana-editor" "$ACCESS_TOKEN"; then
            echo -e "${YELLOW}⚠ Role 'grafana-editor' already exists${NC}"
        else
            echo -e "${BLUE}Creating role 'grafana-editor'...${NC}"
            create_client_role "grafana" "grafana-editor" "Can edit dashboards" "$ACCESS_TOKEN"
            echo -e "${GREEN}✓ Role 'grafana-editor' created${NC}"
        fi
        
        if client_role_exists "grafana" "grafana-viewer" "$ACCESS_TOKEN"; then
            echo -e "${YELLOW}⚠ Role 'grafana-viewer' already exists${NC}"
        else
            echo -e "${BLUE}Creating role 'grafana-viewer'...${NC}"
            create_client_role "grafana" "grafana-viewer" "Read-only access" "$ACCESS_TOKEN"
            echo -e "${GREEN}✓ Role 'grafana-viewer' created${NC}"
        fi
        
        echo
        echo -e "${BLUE}Step 3: Configuring role mapper for Grafana...${NC}"
        create_role_mapper "grafana" "$ACCESS_TOKEN"
        echo -e "${GREEN}✓ Role mapper configured${NC}"
        echo
        echo -e "${GREEN}============================================================================${NC}"
        echo -e "${GREEN}Grafana roles configuration completed${NC}"
        echo -e "${GREEN}============================================================================${NC}"
        ;;
        
    groups)
        echo -e "${BLUE}============================================================================${NC}"
        echo -e "${BLUE}Configuring Groups${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        echo
        
        # Check and create groups
        echo -e "${BLUE}Step 2: Checking existing groups...${NC}"
        
        for group in "super-admins" "admins" "users" "viewers"; do
            if group_exists "$group" "$ACCESS_TOKEN"; then
                echo -e "${YELLOW}⚠ Group '$group' already exists${NC}"
            else
                echo -e "${BLUE}Creating group '$group'...${NC}"
                create_group "$group" "$ACCESS_TOKEN"
                echo -e "${GREEN}✓ Group '$group' created${NC}"
            fi
        done
        
        echo
        echo -e "${GREEN}============================================================================${NC}"
        echo -e "${GREEN}Groups configuration completed${NC}"
        echo -e "${GREEN}============================================================================${NC}"
        ;;
        
    *)
        echo -e "${RED}Unknown service: $SERVICE${NC}"
        echo -e "${YELLOW}Available services: grafana, openwebui, n8n, jenkins, groups${NC}"
        exit 1
        ;;
esac

echo
echo -e "${BLUE}Script completed${NC}"
