#!/bin/bash

# ============================================================================
# Script: keycloak-setup-roles-cli.sh
# Description: Configure roles and groups using Keycloak CLI (kcadm.sh)
# This version uses kcadm.sh instead of curl to avoid password encoding issues
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
echo -e "${BLUE}Keycloak Roles Configuration (Using CLI)${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo

SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
    echo -e "${YELLOW}Usage: $0 <service>${NC}"
    echo -e "${YELLOW}Services: grafana, openwebui, n8n, jenkins, groups${NC}"
    exit 1
fi

# Login to Keycloak
echo -e "${BLUE}Step 1: Authenticating with Keycloak...${NC}"
kcadm config credentials --server http://localhost:8080 --realm "$KEYCLOAK_REALM" --user "$ADMIN_USER" --password "$ADMIN_PASS" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to authenticate${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Authenticated successfully${NC}"
echo

case "$SERVICE" in
    grafana)
        echo -e "${BLUE}============================================================================${NC}"
        echo -e "${BLUE}Configuring Grafana Roles${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        echo
        
        # Get Grafana client ID
        echo -e "${BLUE}Step 2: Getting Grafana client ID...${NC}"
        CLIENT_ID=$(kcadm get clients -r "$KEYCLOAK_REALM" -q clientId=grafana --fields id --format csv --noquotes 2>/dev/null | head -1)
        
        if [ -z "$CLIENT_ID" ]; then
            echo -e "${RED}Error: Grafana client not found${NC}"
            echo -e "${YELLOW}Make sure Grafana client is configured in Keycloak${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Grafana client ID: $CLIENT_ID${NC}"
        echo
        
        # Create roles
        echo -e "${BLUE}Step 3: Creating Grafana roles...${NC}"
        
        # grafana-admin
        if kcadm get clients/$CLIENT_ID/roles/grafana-admin -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ Role 'grafana-admin' already exists${NC}"
        else
            echo -e "${BLUE}Creating role 'grafana-admin'...${NC}"
            kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=grafana-admin -s 'description=Full Grafana administrator'
            echo -e "${GREEN}✓ Role 'grafana-admin' created${NC}"
        fi
        
        # grafana-editor
        if kcadm get clients/$CLIENT_ID/roles/grafana-editor -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ Role 'grafana-editor' already exists${NC}"
        else
            echo -e "${BLUE}Creating role 'grafana-editor'...${NC}"
            kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=grafana-editor -s 'description=Can edit dashboards'
            echo -e "${GREEN}✓ Role 'grafana-editor' created${NC}"
        fi
        
        # grafana-viewer
        if kcadm get clients/$CLIENT_ID/roles/grafana-viewer -r "$KEYCLOAK_REALM" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ Role 'grafana-viewer' already exists${NC}"
        else
            echo -e "${BLUE}Creating role 'grafana-viewer'...${NC}"
            kcadm create clients/$CLIENT_ID/roles -r "$KEYCLOAK_REALM" -s name=grafana-viewer -s 'description=Read-only access'
            echo -e "${GREEN}✓ Role 'grafana-viewer' created${NC}"
        fi
        
        echo
        echo -e "${BLUE}Step 4: Configuring role mapper for Grafana...${NC}"
        
        # Check if mapper already exists
        MAPPER_EXISTS=$(kcadm get clients/$CLIENT_ID/protocol-mappers/models -r "$KEYCLOAK_REALM" 2>/dev/null | grep -c "grafana-roles" || true)
        
        if [ "$MAPPER_EXISTS" -gt 0 ]; then
            echo -e "${YELLOW}⚠ Role mapper 'grafana-roles' already exists${NC}"
        else
            # Create role mapper
            kcadm create clients/$CLIENT_ID/protocol-mappers/models -r "$KEYCLOAK_REALM" \
                -s name=grafana-roles \
                -s protocol=openid-connect \
                -s protocolMapper=oidc-usermodel-client-role-mapper \
                -s 'config."claim.name"=roles' \
                -s 'config."jsonType.label"=String' \
                -s 'config."multivalued"=true' \
                -s 'config."userinfo.token.claim"=true' \
                -s 'config."id.token.claim"=true' \
                -s 'config."access.token.claim"=true' \
                -s 'config."client.id"=grafana'
            echo -e "${GREEN}✓ Role mapper configured${NC}"
        fi
        
        echo
        echo -e "${GREEN}============================================================================${NC}"
        echo -e "${GREEN}Grafana roles configuration completed${NC}"
        echo -e "${GREEN}============================================================================${NC}"
        echo
        echo -e "${BLUE}Created roles:${NC}"
        echo -e "  - grafana-admin (Full administrator)"
        echo -e "  - grafana-editor (Can edit dashboards)"
        echo -e "  - grafana-viewer (Read-only access)"
        ;;
        
    groups)
        echo -e "${BLUE}============================================================================${NC}"
        echo -e "${BLUE}Configuring Groups${NC}"
        echo -e "${BLUE}============================================================================${NC}"
        echo
        
        echo -e "${BLUE}Step 2: Creating groups...${NC}"
        
        for group in "super-admins" "admins" "users" "viewers"; do
            if kcadm get groups -r "$KEYCLOAK_REALM" -q name="$group" 2>/dev/null | grep -q "\"name\" : \"$group\""; then
                echo -e "${YELLOW}⚠ Group '$group' already exists${NC}"
            else
                echo -e "${BLUE}Creating group '$group'...${NC}"
                kcadm create groups -r "$KEYCLOAK_REALM" -s name="$group"
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
