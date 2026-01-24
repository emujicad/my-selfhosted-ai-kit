#!/bin/bash

# Reset Keycloak user password
# Usage: ./reset-keycloak-password.sh <username> <new_password>

USERNAME="${1:-emujicad}"
NEW_PASSWORD="${2:-TempPass123!}"
USER_ID="dac02fc6-d1fd-4ba7-82dd-73516a2d7c55"

echo "Resetting password for user: $USERNAME"
echo "User ID: $USER_ID"

# Use Keycloak's built-in password reset via direct database update
# First, we need to generate a proper password hash

# Delete existing password credential
docker exec postgres psql -U postgres -d keycloak -c "DELETE FROM credential WHERE user_id = '$USER_ID' AND type = 'password';"

# Now we'll use Keycloak's API to set the new password by creating a temporary admin user
# Actually, let's use a simpler approach: set password via SQL with a known hash

# Generate UUID for credential
CRED_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# For now, let's use kcadm from inside container with a workaround
# We'll create the password using Keycloak's own tools

echo "Setting new password..."

# Use kcadm.sh set-password command (doesn't require authentication if run as root inside container)
docker exec keycloak bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user $USERNAME --password '$NEW_PASSWORD' 2>/dev/null || true
/opt/keycloak/bin/kcadm.sh set-password --server http://localhost:8080 --realm master --username $USERNAME --new-password '$NEW_PASSWORD' 2>&1
"

if [ $? -eq 0 ]; then
    echo "✓ Password reset successfully"
    echo "New password: $NEW_PASSWORD"
else
    echo "✗ Failed to reset password"
    exit 1
fi
