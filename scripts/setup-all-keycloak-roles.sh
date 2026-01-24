#!/bin/bash

# ============================================================================
# Script: setup-all-keycloak-roles.sh
# Description: Configure all Keycloak roles and groups in one command
# Usage: ./scripts/setup-all-keycloak-roles.sh
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Keycloak Complete RBAC Setup${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo
echo -e "${BLUE}This script will configure:${NC}"
echo -e "  - Groups (super-admins, admins, users, viewers)"
echo -e "  - Grafana roles (admin, editor, viewer)"
echo -e "  - Open WebUI roles (admin, user)"
echo -e "  - n8n roles (admin, user)"
echo -e "  - Jenkins roles (admin, user)"
echo
echo -e "${YELLOW}Note: Existing roles/groups will be skipped (safe to re-run)${NC}"
echo

# Check if Keycloak is running
if ! docker ps | grep -q keycloak; then
    echo -e "${RED}Error: Keycloak is not running${NC}"
    echo -e "${YELLOW}Start Keycloak with: ./scripts/stack-manager.sh start security${NC}"
    exit 1
fi

# Wait for Keycloak to be ready
echo -e "${BLUE}Checking Keycloak availability...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080/health/ready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Keycloak is ready${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}Waiting for Keycloak... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}Error: Keycloak did not become ready in time${NC}"
    exit 1
fi

echo

# Execute setup scripts in order
FAILED=0

echo -e "${BLUE}[1/5] Setting up Groups...${NC}"
if "$SCRIPT_DIR/keycloak-setup-roles-cli.sh" groups; then
    echo -e "${GREEN}✓ Groups setup completed${NC}"
else
    echo -e "${RED}✗ Groups setup failed${NC}"
    FAILED=1
fi
echo

echo -e "${BLUE}[2/5] Setting up Grafana roles...${NC}"
if "$SCRIPT_DIR/keycloak-setup-roles-cli.sh" grafana; then
    echo -e "${GREEN}✓ Grafana roles setup completed${NC}"
else
    echo -e "${RED}✗ Grafana roles setup failed${NC}"
    FAILED=1
fi
echo

echo -e "${BLUE}[3/5] Setting up Open WebUI roles...${NC}"
if "$SCRIPT_DIR/keycloak-setup-openwebui-roles.sh"; then
    echo -e "${GREEN}✓ Open WebUI roles setup completed${NC}"
else
    echo -e "${RED}✗ Open WebUI roles setup failed${NC}"
    FAILED=1
fi
echo

echo -e "${BLUE}[4/5] Setting up n8n roles...${NC}"
if "$SCRIPT_DIR/keycloak-setup-n8n-roles.sh"; then
    echo -e "${GREEN}✓ n8n roles setup completed${NC}"
else
    echo -e "${RED}✗ n8n roles setup failed${NC}"
    FAILED=1
fi
echo

echo -e "${BLUE}[5/5] Setting up Jenkins roles...${NC}"
if "$SCRIPT_DIR/keycloak-setup-jenkins-roles.sh"; then
    echo -e "${GREEN}✓ Jenkins roles setup completed${NC}"
else
    echo -e "${YELLOW}⚠ Jenkins roles setup failed (Jenkins client may not exist yet)${NC}"
    # Don't fail on Jenkins as it might not be configured yet
fi
echo

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
    exit 0
else
    echo -e "${RED}✗ Keycloak RBAC setup completed with errors${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo
    echo -e "${YELLOW}Please check the errors above and retry${NC}"
    exit 1
fi
