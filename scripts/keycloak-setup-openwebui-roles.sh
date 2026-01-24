#!/bin/bash

# ============================================================================
# Script: keycloak-setup-openwebui-roles.sh
# Description: Configure Open WebUI roles in Keycloak
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

# Function to run kcadm.sh command
kcadm() {
    docker exec keycloak /opt/keycloak/bin/kcadm.sh "$@"
}

# Main execution
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Keycloak Open WebUI Roles Configuration${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

# Login to Keycloak
echo -e "${BLUE}Step 1: Authenticating with Keycloak...${NC}"
kcadm config credentials --server http://localhost:8080 --realm "$KEYCLOAK_REALM" --user "$ADMIN_USER" --password "$ADMIN_PASS" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to authenticate${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Authenticated successfully${NC}"
echo

# Get Open WebUI client ID
echo -e "${BLUE}Step 2: Getting Open WebUI client ID...${NC}"
CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=open-webui --fields id --format csv --noquotes 2>/dev/null | head -1)

if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}Error: Open WebUI client not found${NC}"
    echo -e "${YELLOW}Make sure Open WebUI client is configured in Keycloak${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Open WebUI client ID: $CLIENT_ID${NC}"
echo

# Create roles
echo -e "${BLUE}Step 3: Creating Open WebUI roles...${NC}"

# openwebui-admin
if kcadm get clients/$CLIENT_ID/roles/openwebui-admin -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Role 'openwebui-admin' already exists${NC}"
else
    echo -e "${BLUE}Creating role 'openwebui-admin'...${NC}"
    kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=openwebui-admin -s 'description=Full Open WebUI administrator'
    echo -e "${GREEN}✓ Role 'openwebui-admin' created${NC}"
fi

# openwebui-user
if kcadm get clients/$CLIENT_ID/roles/openwebui-user -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Role 'openwebui-user' already exists${NC}"
else
    echo -e "${BLUE}Creating role 'openwebui-user'...${NC}"
    kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=openwebui-user -s 'description=Regular Open WebUI user'
    echo -e "${GREEN}✓ Role 'openwebui-user' created${NC}"
fi

echo
echo -e "${BLUE}Step 4: Configuring role mapper for Open WebUI...${NC}"

# Check if mapper already exists
MAPPER_EXISTS=$(kcadm get clients/$CLIENT_ID/protocol-mappers/models -r "$KEYCLOAK_REALM" 2>/dev/null | grep -c "openwebui-roles" || true)

if [ "$MAPPER_EXISTS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Role mapper 'openwebui-roles' already exists${NC}"
else
    # Create role mapper
    kcadm create clients/$CLIENT_ID/protocol-mappers/models -r "$KEYCLOAK_REALM" \
        -s name=openwebui-roles \
        -s protocol=openid-connect \
        -s protocolMapper=oidc-usermodel-client-role-mapper \
        -s 'config."claim.name"=roles' \
        -s 'config."jsonType.label"=String' \
        -s 'config."multivalued"=true' \
        -s 'config."userinfo.token.claim"=true' \
        -s 'config."id.token.claim"=true' \
        -s 'config."access.token.claim"=true' \
        -s 'config."client.id"=open-webui'
    echo -e "${GREEN}✓ Role mapper configured${NC}"
fi

echo
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Open WebUI roles configuration completed${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo
echo -e "${BLUE}Created roles:${NC}"
echo -e "  - openwebui-admin (Full administrator)"
echo -e "  - openwebui-user (Regular user)"
echo

echo -e "${BLUE}Script completed${NC}"
