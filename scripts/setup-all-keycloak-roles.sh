#!/bin/bash
# Wrapper script for backward compatibility
# This script calls the unified keycloak-roles-manager.sh
exec "$(dirname "$0")/keycloak-roles-manager.sh" all "$@"
