#!/bin/bash

# =============================================================================
# Script para configurar cliente n8n en Keycloak
# =============================================================================
# Este script guía al usuario para configurar el cliente 'n8n' en Keycloak
# para habilitar autenticación OIDC/OAuth

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================================================${NC}"
echo -e "${BLUE}Configuración de cliente 'n8n' en Keycloak${NC}"
echo -e "${BLUE}=============================================================================${NC}"
echo ""

# Verificar que Keycloak esté corriendo
echo -e "${YELLOW}Verificando que Keycloak esté corriendo...${NC}"
if ! docker compose --profile security ps keycloak | grep -q "Up"; then
    echo -e "${RED}❌ Keycloak no está corriendo. Inícialo primero:${NC}"
    echo "   docker compose --profile security up -d keycloak"
    exit 1
fi
echo -e "${GREEN}✅ Keycloak está corriendo${NC}"
echo ""

# Información del cliente
CLIENT_ID="n8n"
REDIRECT_URI="http://localhost:5678/rest/oauth2-credential/callback"
WEB_ORIGINS="http://localhost:5678"

echo -e "${BLUE}Información del cliente n8n:${NC}"
echo "  Client ID: ${CLIENT_ID}"
echo "  Redirect URI: ${REDIRECT_URI}"
echo "  Web Origins: ${WEB_ORIGINS}"
echo ""

echo -e "${YELLOW}Pasos para configurar el cliente en Keycloak:${NC}"
echo ""
echo "1. Abre Keycloak Admin Console:"
echo "   http://localhost:8080"
echo ""
echo "2. Inicia sesión con:"
echo "   Usuario: admin"
echo "   Contraseña: admin"
echo ""
echo "3. Ve a: Clients → Create client"
echo ""
echo "4. Configuración básica:"
echo "   - Client ID: ${CLIENT_ID}"
echo "   - Client authentication: On (confidential client)"
echo "   - Authorization: Off"
echo "   - Click 'Next'"
echo ""
echo "5. Configuración de login:"
echo "   - Standard flow: ✅ Enabled"
echo "   - Direct access grants: ❌ Disabled (no necesario para n8n)"
echo "   - Valid redirect URIs: ${REDIRECT_URI}"
echo "   - Web origins: ${WEB_ORIGINS}"
echo "   - Click 'Save'"
echo ""
echo "6. Ve a la pestaña 'Credentials' y copia el 'Client secret'"
echo ""
echo "7. Actualiza el archivo .env con:"
echo "   N8N_OIDC_CLIENT_SECRET=<el_secret_copiado>"
echo ""
echo "8. Reinicia n8n:"
echo "   docker compose up -d --force-recreate n8n"
echo ""

# Generar secret aleatorio si no existe
if [ -f .env ] && grep -q "N8N_OIDC_CLIENT_SECRET" .env; then
    echo -e "${GREEN}✅ N8N_OIDC_CLIENT_SECRET ya está en .env${NC}"
else
    echo -e "${YELLOW}Generando secret aleatorio para .env.example...${NC}"
    RANDOM_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 32)
    echo ""
    echo -e "${BLUE}Agrega esto a tu archivo .env:${NC}"
    echo "N8N_OIDC_CLIENT_SECRET=${RANDOM_SECRET}"
    echo ""
fi

echo -e "${GREEN}=============================================================================${NC}"
echo -e "${GREEN}Configuración completada${NC}"
echo -e "${GREEN}=============================================================================${NC}"
echo ""
echo "Después de configurar el cliente en Keycloak y actualizar .env,"
echo "recrea el contenedor de n8n para aplicar los cambios."

