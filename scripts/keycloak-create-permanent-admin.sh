#!/bin/bash

# ============================================================================
# Script: keycloak-create-permanent-admin.sh
# Description: Create permanent admin user in Keycloak and delete temporary one
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
TEMP_ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
TEMP_ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"

# New permanent admin configuration
NEW_ADMIN_USERNAME="${KEYCLOAK_PERMANENT_ADMIN_USERNAME:-emujicad}"
NEW_ADMIN_EMAIL="${KEYCLOAK_PERMANENT_ADMIN_EMAIL:-emujicad@gmail.com}"
NEW_ADMIN_PASSWORD="${KEYCLOAK_PERMANENT_ADMIN_PASSWORD}"

# Validation
if [ -z "$TEMP_ADMIN_PASS" ]; then
    echo -e "${RED}Error: KEYCLOAK_ADMIN_PASSWORD not set in .env${NC}"
    exit 1
fi

if [ -z "$NEW_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: KEYCLOAK_PERMANENT_ADMIN_PASSWORD not set in .env${NC}"
    echo -e "${YELLOW}Please enter password for new permanent admin user:${NC}"
    read -s NEW_ADMIN_PASSWORD
    echo
    echo -e "${YELLOW}Confirm password:${NC}"
    read -s NEW_ADMIN_PASSWORD_CONFIRM
    echo
    
    if [ "$NEW_ADMIN_PASSWORD" != "$NEW_ADMIN_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Error: Passwords do not match${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Keycloak Permanent Admin User Creation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Keycloak URL: ${KEYCLOAK_URL}"
echo -e "  Realm: ${KEYCLOAK_REALM}"
echo -e "  Temporary Admin: ${TEMP_ADMIN_USER}"
echo -e "  New Admin Username: ${NEW_ADMIN_USERNAME}"
echo -e "  New Admin Email: ${NEW_ADMIN_EMAIL}"
echo

# Function to get access token
get_access_token() {
    local username=$1
    local password=$2
    
    local response=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${username}" \
        -d "password=${password}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli")
    
    echo "$response" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//'
}

# Function to check if user exists
user_exists() {
    local username=$1
    local token=$2
    
    local response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?username=${username}" \
        -H "Authorization: Bearer ${token}")
    
    if echo "$response" | grep -q "\"username\":\"${username}\""; then
        return 0
    else
        return 1
    fi
}

# Function to get user ID
get_user_id() {
    local username=$1
    local token=$2
    
    local response=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users?username=${username}" \
        -H "Authorization: Bearer ${token}")
    
    echo "$response" | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//'
}

# Function to create user
create_user() {
    local username=$1
    local email=$2
    local token=$3
    
    local payload=$(cat <<EOF
{
    "username": "${username}",
    "email": "${email}",
    "emailVerified": true,
    "enabled": true,
    "firstName": "Admin",
    "lastName": "User"
}
EOF
)
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Function to set user password
set_user_password() {
    local user_id=$1
    local password=$2
    local token=$3
    
    local payload=$(cat <<EOF
{
    "type": "password",
    "value": "${password}",
    "temporary": false
}
EOF
)
    
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${user_id}/reset-password" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Function to assign admin role
assign_admin_role() {
    local user_id=$1
    local token=$2
    
    # Get admin role
    local admin_role=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/roles/admin" \
        -H "Authorization: Bearer ${token}")
    
    local role_id=$(echo "$admin_role" | grep -o '"id":"[^"]*' | sed 's/"id":"//')
    local role_name=$(echo "$admin_role" | grep -o '"name":"[^"]*' | sed 's/"name":"//')
    
    local payload="[{\"id\":\"${role_id}\",\"name\":\"${role_name}\"}]"
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${user_id}/role-mappings/realm" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Function to delete user
delete_user() {
    local user_id=$1
    local token=$2
    
    curl -s -X DELETE "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${user_id}" \
        -H "Authorization: Bearer ${token}"
}

# Main execution
echo -e "${BLUE}Step 1: Getting access token for temporary admin...${NC}"
ACCESS_TOKEN=$(get_access_token "$TEMP_ADMIN_USER" "$TEMP_ADMIN_PASS")

if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Error: Failed to get access token. Check credentials.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Access token obtained${NC}"
echo

# Check if new admin user already exists
echo -e "${BLUE}Step 2: Checking if permanent admin user already exists...${NC}"
if user_exists "$NEW_ADMIN_USERNAME" "$ACCESS_TOKEN"; then
    echo -e "${YELLOW}⚠ User '${NEW_ADMIN_USERNAME}' already exists${NC}"
    echo -e "${YELLOW}Do you want to update the password? (y/n)${NC}"
    read -r UPDATE_PASSWORD
    
    if [ "$UPDATE_PASSWORD" = "y" ] || [ "$UPDATE_PASSWORD" = "Y" ]; then
        USER_ID=$(get_user_id "$NEW_ADMIN_USERNAME" "$ACCESS_TOKEN")
        echo -e "${BLUE}Updating password for existing user...${NC}"
        set_user_password "$USER_ID" "$NEW_ADMIN_PASSWORD" "$ACCESS_TOKEN"
        echo -e "${GREEN}✓ Password updated${NC}"
    fi
else
    echo -e "${GREEN}✓ User does not exist, proceeding with creation${NC}"
    echo
    
    # Create new permanent admin user
    echo -e "${BLUE}Step 3: Creating permanent admin user '${NEW_ADMIN_USERNAME}'...${NC}"
    create_user "$NEW_ADMIN_USERNAME" "$NEW_ADMIN_EMAIL" "$ACCESS_TOKEN"
    
    # Wait a bit for user creation to complete
    sleep 2
    
    # Get new user ID
    NEW_USER_ID=$(get_user_id "$NEW_ADMIN_USERNAME" "$ACCESS_TOKEN")
    
    if [ -z "$NEW_USER_ID" ]; then
        echo -e "${RED}Error: Failed to create user or get user ID${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ User created with ID: ${NEW_USER_ID}${NC}"
    echo
    
    # Set password
    echo -e "${BLUE}Step 4: Setting password for new admin user...${NC}"
    set_user_password "$NEW_USER_ID" "$NEW_ADMIN_PASSWORD" "$ACCESS_TOKEN"
    echo -e "${GREEN}✓ Password set${NC}"
    echo
    
    # Assign admin role
    echo -e "${BLUE}Step 5: Assigning admin role to new user...${NC}"
    assign_admin_role "$NEW_USER_ID" "$ACCESS_TOKEN"
    echo -e "${GREEN}✓ Admin role assigned${NC}"
    echo
fi

# Verify new admin can login
echo -e "${BLUE}Step 6: Verifying new admin user can login...${NC}"
NEW_ACCESS_TOKEN=$(get_access_token "$NEW_ADMIN_USERNAME" "$NEW_ADMIN_PASSWORD")

if [ -z "$NEW_ACCESS_TOKEN" ]; then
    echo -e "${RED}Error: New admin user cannot login. Aborting.${NC}"
    echo -e "${RED}Temporary admin user NOT deleted for safety.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ New admin user can login successfully${NC}"
echo

# Ask before deleting temporary admin
echo -e "${YELLOW}============================================================================${NC}"
echo -e "${YELLOW}WARNING: About to delete temporary admin user '${TEMP_ADMIN_USER}'${NC}"
echo -e "${YELLOW}============================================================================${NC}"
echo -e "${YELLOW}Make sure you can login with the new admin user before proceeding!${NC}"
echo -e "${YELLOW}New admin credentials:${NC}"
echo -e "  Username: ${NEW_ADMIN_USERNAME}"
echo -e "  Email: ${NEW_ADMIN_EMAIL}"
echo
echo -e "${YELLOW}Do you want to delete the temporary admin user now? (y/n)${NC}"
read -r DELETE_TEMP

if [ "$DELETE_TEMP" = "y" ] || [ "$DELETE_TEMP" = "Y" ]; then
    echo -e "${BLUE}Step 7: Deleting temporary admin user...${NC}"
    
    TEMP_USER_ID=$(get_user_id "$TEMP_ADMIN_USER" "$NEW_ACCESS_TOKEN")
    
    if [ -z "$TEMP_USER_ID" ]; then
        echo -e "${RED}Error: Could not find temporary admin user ID${NC}"
        exit 1
    fi
    
    delete_user "$TEMP_USER_ID" "$NEW_ACCESS_TOKEN"
    echo -e "${GREEN}✓ Temporary admin user deleted${NC}"
    echo
    
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}SUCCESS: Permanent admin user created and temporary user deleted${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo
    echo -e "${GREEN}You can now login to Keycloak with:${NC}"
    echo -e "  URL: http://localhost:8080"
    echo -e "  Username: ${NEW_ADMIN_USERNAME}"
    echo -e "  Email: ${NEW_ADMIN_EMAIL}"
    echo
    echo -e "${YELLOW}IMPORTANT: Update your .env file with the new credentials:${NC}"
    echo -e "  KEYCLOAK_ADMIN=${NEW_ADMIN_USERNAME}"
    echo -e "  KEYCLOAK_ADMIN_PASSWORD=<your_new_password>"
else
    echo -e "${YELLOW}Temporary admin user NOT deleted.${NC}"
    echo -e "${YELLOW}You can delete it manually later from Keycloak Admin Console.${NC}"
fi

echo
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}Script completed${NC}"
echo -e "${BLUE}============================================================================${NC}"
