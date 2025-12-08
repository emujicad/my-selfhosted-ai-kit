#!/bin/bash

# =============================================================================
# Script de Inicialización: Configurar Jenkins OIDC con Keycloak
# =============================================================================
# Este script configura automáticamente Jenkins para usar Keycloak como
# proveedor OIDC mediante el plugin "OpenId Connect Authentication"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Cargar variables de entorno
if [ -f .env ]; then
    source .env || true
fi

# Valores por defecto
JENKINS_URL="${JENKINS_URL_PUBLIC:-http://localhost:8081}"
JENKINS_ADMIN_USER="${JENKINS_ADMIN_USER:-admin}"
JENKINS_ADMIN_PASSWORD="${JENKINS_ADMIN_PASSWORD:-admin}"
KEYCLOAK_URL="${KEYCLOAK_URL_PUBLIC:-http://localhost:8080}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"
JENKINS_OIDC_CLIENT_ID="${JENKINS_OIDC_CLIENT_ID:-jenkins}"
JENKINS_OIDC_CLIENT_SECRET="${JENKINS_OIDC_CLIENT_SECRET:-}"
JENKINS_OIDC_SCOPES="${JENKINS_OIDC_SCOPES:-openid email profile}"

echo -e "${BLUE}=============================================================================${NC}"
echo -e "${BLUE}Configurar Jenkins OIDC con Keycloak${NC}"
echo -e "${BLUE}=============================================================================${NC}"
echo ""

# Verificar que Jenkins está corriendo
if ! docker ps | grep -q jenkins; then
    echo -e "${RED}❌ Jenkins NO está corriendo${NC}"
    echo "   Levántalo con: docker compose --profile ci-cd up -d jenkins"
    exit 1
fi

# Verificar que Keycloak está corriendo
if ! docker ps | grep -q keycloak; then
    echo -e "${RED}❌ Keycloak NO está corriendo${NC}"
    echo "   Levántalo con: docker compose --profile security up -d keycloak"
    exit 1
fi

# Verificar que el Client Secret está configurado
if [ -z "$JENKINS_OIDC_CLIENT_SECRET" ] || [ "$JENKINS_OIDC_CLIENT_SECRET" = "change_me_jenkins_client_secret" ]; then
    echo -e "${YELLOW}⚠️  JENKINS_OIDC_CLIENT_SECRET no está configurado${NC}"
    echo "   Ejecuta primero: ./scripts/recreate-keycloak-clients.sh"
    echo "   Luego actualiza JENKINS_OIDC_CLIENT_SECRET en .env"
    exit 1
fi

echo "⏳ Esperando a que Jenkins esté listo..."
MAX_WAIT=120
WAIT_COUNT=0
while ! curl -s -f "${JENKINS_URL}/login" > /dev/null 2>&1; do
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo -e "${RED}❌ Jenkins no respondió después de ${MAX_WAIT} segundos${NC}"
        exit 1
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo -n "."
done
echo ""
echo -e "${GREEN}✅ Jenkins está listo${NC}"
echo ""

# Obtener token CSRF de Jenkins
echo "🔑 Obteniendo token CSRF de Jenkins..."
CSRF_CRUMB=$(curl -s -u "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
    "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" \
    2>/dev/null | cut -d: -f2)

if [ -z "$CSRF_CRUMB" ]; then
    echo -e "${YELLOW}⚠️  No se pudo obtener CSRF crumb, intentando sin él...${NC}"
    CSRF_CRUMB=""
fi

# Verificar si el plugin OIDC está instalado
echo "🔍 Verificando plugin 'OpenId Connect Authentication'..."
PLUGIN_INSTALLED=$(curl -s -u "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
    "${JENKINS_URL}/pluginManager/api/json?depth=1" \
    2>/dev/null | grep -o '"shortName":"oidc-provider"' || true)

if [ -z "$PLUGIN_INSTALLED" ]; then
    echo "📦 Instalando plugin 'OpenId Connect Authentication'..."
    
    # Instalar plugin
    INSTALL_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        -u "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
        ${CSRF_CRUMB:+-H "Jenkins-Crumb: ${CSRF_CRUMB}"} \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "plugin=oidc-provider" \
        "${JENKINS_URL}/pluginManager/installNecessaryPlugins" \
        2>/dev/null)
    
    HTTP_CODE="${INSTALL_RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        echo -e "${GREEN}✅ Plugin instalado, esperando a que Jenkins reinicie...${NC}"
        echo "   Esto puede tomar 1-2 minutos..."
        
        # Esperar a que Jenkins reinicie
        sleep 10
        MAX_WAIT=180
        WAIT_COUNT=0
        while ! curl -s -f "${JENKINS_URL}/login" > /dev/null 2>&1; do
            if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
                echo -e "${RED}❌ Jenkins no reinició después de ${MAX_WAIT} segundos${NC}"
                exit 1
            fi
            sleep 5
            WAIT_COUNT=$((WAIT_COUNT + 5))
            echo -n "."
        done
        echo ""
        echo -e "${GREEN}✅ Jenkins reinició correctamente${NC}"
        
        # Re-obtener CSRF crumb después del reinicio
        CSRF_CRUMB=$(curl -s -u "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
            "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" \
            2>/dev/null | cut -d: -f2)
    else
        echo -e "${RED}❌ Error al instalar plugin (HTTP $HTTP_CODE)${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Plugin ya está instalado${NC}"
fi
echo ""

# Configurar OIDC
echo "⚙️  Configurando OIDC con Keycloak..."

# Construir URL del well-known endpoint
WELL_KNOWN_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration"

# Configurar OIDC mediante API REST de Jenkins
CONFIG_XML=$(cat <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<hudson>
  <securityRealm class="org.jenkinsci.plugins.oic.OicSecurityRealm" plugin="oidc-provider@1.0">
    <id>keycloak</id>
    <wellKnownOpenIDConfigurationUrl>${WELL_KNOWN_URL}</wellKnownOpenIDConfigurationUrl>
    <clientId>${JENKINS_OIDC_CLIENT_ID}</clientId>
    <clientSecret>${JENKINS_OIDC_CLIENT_SECRET}</clientSecret>
    <scopes>${JENKINS_OIDC_SCOPES}</scopes>
    <userNameField>preferred_username</userNameField>
    <fullNameField>name</fullNameField>
    <emailField>email</emailField>
    <groupsField>groups</groupsField>
    <disableSslVerification>false</disableSslVerification>
    <logoutUrl>${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout</logoutUrl>
    <endSessionUrl>${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout</endSessionUrl>
    <escapeHatchEnabled>false</escapeHatchEnabled>
    <escapeHatchUsername></escapeHatchUsername>
    <escapeHatchSecret></escapeHatchSecret>
    <escapeHatchGroup></escapeHatchGroup>
    <automaticRefresh>true</automaticRefresh>
    <tokenFieldToCheckKey>exp</tokenFieldToCheckKey>
  </securityRealm>
</hudson>
EOF
)

# Obtener configuración actual de Jenkins
echo "📥 Obteniendo configuración actual de Jenkins..."
CURRENT_CONFIG=$(curl -s -u "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
    "${JENKINS_URL}/config.xml" \
    2>/dev/null)

# Verificar si OIDC ya está configurado
if echo "$CURRENT_CONFIG" | grep -q "OicSecurityRealm"; then
    echo -e "${YELLOW}⚠️  OIDC ya está configurado en Jenkins${NC}"
    echo "   ¿Deseas actualizarlo? (s/n)"
    read -r RESPONSE
    if [ "$RESPONSE" != "s" ] && [ "$RESPONSE" != "S" ]; then
        echo "   Configuración no modificada"
        exit 0
    fi
fi

# Actualizar configuración de seguridad
echo "💾 Actualizando configuración de seguridad..."

# Crear archivo temporal con la configuración
TEMP_CONFIG=$(mktemp)
echo "$CONFIG_XML" > "$TEMP_CONFIG"

# Subir configuración
UPDATE_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    -u "${JENKINS_ADMIN_USER}:${JENKINS_ADMIN_PASSWORD}" \
    ${CSRF_CRUMB:+-H "Jenkins-Crumb: ${CSRF_CRUMB}"} \
    -H "Content-Type: application/xml" \
    --data-binary "@${TEMP_CONFIG}" \
    "${JENKINS_URL}/config.xml" \
    2>/dev/null)

HTTP_CODE="${UPDATE_RESPONSE: -3}"

# Limpiar archivo temporal
rm -f "$TEMP_CONFIG"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo -e "${GREEN}✅ Configuración OIDC actualizada${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${GREEN}✅ Jenkins configurado exitosamente con Keycloak OIDC${NC}"
    echo ""
    echo "📋 Próximos pasos:"
    echo "   1. Reinicia Jenkins si es necesario:"
    echo "      docker compose --profile ci-cd restart jenkins"
    echo "   2. Accede a Jenkins: ${JENKINS_URL}"
    echo "   3. Deberías ser redirigido a Keycloak para autenticarte"
    echo ""
    echo "🌐 URLs:"
    echo "   - Jenkins: ${JENKINS_URL}"
    echo "   - Keycloak: ${KEYCLOAK_URL}"
    echo ""
else
    echo -e "${RED}❌ Error al actualizar configuración (HTTP $HTTP_CODE)${NC}"
    echo "   Respuesta: ${UPDATE_RESPONSE%???}"
    exit 1
fi

