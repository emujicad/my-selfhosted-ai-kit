#!/bin/bash

# ============================================================================
# Script: keycloak-setup-jenkins-roles.sh
# Description: Configure Jenkins roles in Keycloak
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
echo -e "${BLUE}Keycloak Jenkins Roles Configuration${NC}"
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

# Get Jenkins client ID
echo -e "${BLUE}Step 2: Getting Jenkins client ID...${NC}"
CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=jenkins --fields id --format csv --noquotes 2>/dev/null | head -1)

if [ -z "$CLIENT_ID" ]; then
    echo -e "${YELLOW}⚠ Jenkins client not found - skipping (Jenkins may not be configured yet)${NC}"
    echo -e "${BLUE}Note: Run keycloak-manager.sh setup jenkins when Jenkins is ready${NC}"
    exit 0
fi
echo -e "${GREEN}✓ Jenkins client ID: $CLIENT_ID${NC}"
echo

# Create roles
echo -e "${BLUE}Step 3: Creating Jenkins roles...${NC}"

# jenkins-admin
if kcadm get clients/$CLIENT_ID/roles/jenkins-admin -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Role 'jenkins-admin' already exists${NC}"
else
    echo -e "${BLUE}Creating role 'jenkins-admin'...${NC}"
    kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=jenkins-admin -s 'description=Full Jenkins administrator'
    echo -e "${GREEN}✓ Role 'jenkins-admin' created${NC}"
fi

# jenkins-user
if kcadm get clients/$CLIENT_ID/roles/jenkins-user -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Role 'jenkins-user' already exists${NC}"
else
    echo -e "${BLUE}Creating role 'jenkins-user'...${NC}"
    kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=jenkins-user -s 'description=Regular Jenkins user'
    echo -e "${GREEN}✓ Role 'jenkins-user' created${NC}"
fi

echo
echo -e "${BLUE}Step 4: Configuring role mapper for Jenkins...${NC}"

# Check if mapper already exists
MAPPER_EXISTS=$(kcadm get clients/$CLIENT_ID/protocol-mappers/models -r "$KEYCLOAK_REALM" 2>/dev/null | grep -c "jenkins-roles" || true)

if [ "$MAPPER_EXISTS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Role mapper 'jenkins-roles' already exists${NC}"
else
    # Create role mapper
    kcadm create clients/$CLIENT_ID/protocol-mappers/models -r "$KEYCLOAK_REALM" \
        -s name=jenkins-roles \
        -s protocol=openid-connect \
        -s protocolMapper=oidc-usermodel-client-role-mapper \
        -s 'config."claim.name"=roles' \
        -s 'config."jsonType.label"=String' \
        -s 'config."multivalued"=true' \
        -s 'config."userinfo.token.claim"=true' \
        -s 'config."id.token.claim"=true' \
        -s 'config."access.token.claim"=true' \
        -s 'config."client.id"=jenkins'
    echo -e "${GREEN}✓ Role mapper configured${NC}"
fi

echo
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Jenkins roles configuration completed${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo
echo -e "${BLUE}Created roles:${NC}"
echo -e "  - jenkins-admin (Full administrator)"
echo -e "  - jenkins-user (Regular user)"
echo

echo -e "${BLUE}Script completed${NC}"
