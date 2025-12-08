#!/bin/bash

# =============================================================================
# Script para recrear automáticamente los clientes de Keycloak
# =============================================================================
# Este script recrea los clientes de Grafana, n8n, Open WebUI y Jenkins en Keycloak
# usando la API de administración (kcadm.sh)
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
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
HOSTNAME_PUBLIC="${HOSTNAME_PUBLIC:-localhost}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"

# URLs de servicios
GRAFANA_URL="${GRAFANA_URL_PUBLIC:-http://localhost:3001}"
N8N_URL="${N8N_URL_PUBLIC:-http://localhost:5678}"
OPEN_WEBUI_URL="${OPEN_WEBUI_URL_PUBLIC:-http://localhost:3000}"
JENKINS_URL="${JENKINS_URL_PUBLIC:-http://localhost:8081}"
JENKINS_URL="${JENKINS_URL_PUBLIC:-http://localhost:8081}"

echo -e "${BLUE}=============================================================================${NC}"
echo -e "${BLUE}Recrear Clientes de Keycloak - My Self-Hosted AI Kit${NC}"
echo -e "${BLUE}=============================================================================${NC}"
echo ""

# Verificar que Keycloak está corriendo
if ! docker ps | grep -q keycloak; then
    echo -e "${RED}❌ Keycloak NO está corriendo${NC}"
    echo "   Levántalo con: docker compose --profile security up -d keycloak"
    exit 1
fi

echo -e "${GREEN}✅ Keycloak está corriendo${NC}"
echo ""

# Configurar credenciales de administrador
echo "🔐 Configurando credenciales de administrador..."
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user "$KEYCLOAK_ADMIN_USER" \
    --password "$KEYCLOAK_ADMIN_PASSWORD" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  No se pudo configurar credenciales automáticamente${NC}"
    echo "   Verifica que las credenciales en .env sean correctas"
    exit 1
fi

echo -e "${GREEN}✅ Credenciales configuradas${NC}"
echo ""

# Función para crear cliente Grafana
create_grafana_client() {
    echo "📋 Creando cliente 'grafana'..."
    
    # Verificar si el cliente ya existe
    if docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KEYCLOAK_REALM" \
        -q clientId=grafana 2>/dev/null | grep -q "grafana"; then
        echo -e "${YELLOW}   ⚠️  Cliente 'grafana' ya existe, eliminándolo primero...${NC}"
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=grafana 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CLIENT_ID" ]; then
            docker exec keycloak /opt/keycloak/bin/kcadm.sh delete clients/"$CLIENT_ID" \
                -r "$KEYCLOAK_REALM" > /dev/null 2>&1 || true
        fi
    fi
    
    # Crear cliente Grafana
    docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
        -r "$KEYCLOAK_REALM" \
        -s clientId=grafana \
        -s name=grafana \
        -s protocol=openid-connect \
        -s publicClient=false \
        -s standardFlowEnabled=true \
        -s directAccessGrantsEnabled=false \
        -s fullScopeAllowed=false \
        -s "redirectUris=[\"${GRAFANA_URL}/login/generic_oauth\"]" \
        -s "webOrigins=[\"${GRAFANA_URL}\"]" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ Cliente 'grafana' creado${NC}"
        
        # Obtener Client ID
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=grafana 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$CLIENT_ID" ]; then
            # Mover 'roles' de Default a Optional Client Scopes
            # Esto evita que Keycloak devuelva roles automáticamente
            # y previene el error "cannot remove last organization admin" en Grafana
            echo "   🔧 Configurando Client Scopes (moviendo 'roles' a Optional)..."
            ROLES_SCOPE_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get client-scopes -r "$KEYCLOAK_REALM" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); [print(s['id']) for s in data if s.get('name') == 'roles']" 2>/dev/null | head -1)
            if [ -n "$ROLES_SCOPE_ID" ]; then
                # Remover de Default
                docker exec keycloak /opt/keycloak/bin/kcadm.sh delete clients/"$CLIENT_ID"/default-client-scopes/"$ROLES_SCOPE_ID" \
                    -r "$KEYCLOAK_REALM" > /dev/null 2>&1 || true
                # Agregar a Optional
                docker exec keycloak /opt/keycloak/bin/kcadm.sh update clients/"$CLIENT_ID"/optional-client-scopes/"$ROLES_SCOPE_ID" \
                    -r "$KEYCLOAK_REALM" > /dev/null 2>&1 || true
            fi
            
            # Obtener Client Secret
            CLIENT_SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/"$CLIENT_ID"/client-secret \
                -r "$KEYCLOAK_REALM" 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
            
            if [ -n "$CLIENT_SECRET" ]; then
                echo "   🔑 Client Secret: $CLIENT_SECRET"
                echo "   💡 Actualiza GRAFANA_OAUTH_CLIENT_SECRET en .env con este valor"
            fi
        fi
    else
        echo -e "${RED}   ❌ Error al crear cliente 'grafana'${NC}"
        return 1
    fi
    echo ""
}

# Función para crear cliente n8n
create_n8n_client() {
    echo "📋 Creando cliente 'n8n'..."
    
    # Verificar si el cliente ya existe
    if docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KEYCLOAK_REALM" \
        -q clientId=n8n 2>/dev/null | grep -q "n8n"; then
        echo -e "${YELLOW}   ⚠️  Cliente 'n8n' ya existe, eliminándolo primero...${NC}"
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=n8n 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CLIENT_ID" ]; then
            docker exec keycloak /opt/keycloak/bin/kcadm.sh delete clients/"$CLIENT_ID" \
                -r "$KEYCLOAK_REALM" > /dev/null 2>&1 || true
        fi
    fi
    
    # Crear cliente n8n
    docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
        -r "$KEYCLOAK_REALM" \
        -s clientId=n8n \
        -s name=n8n \
        -s protocol=openid-connect \
        -s publicClient=false \
        -s standardFlowEnabled=true \
        -s directAccessGrantsEnabled=false \
        -s "redirectUris=[\"${N8N_URL}/rest/oauth2-credential/callback\"]" \
        -s "webOrigins=[\"${N8N_URL}\"]" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ Cliente 'n8n' creado${NC}"
        
        # Obtener Client ID
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=n8n 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$CLIENT_ID" ]; then
            # Obtener Client Secret
            CLIENT_SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/"$CLIENT_ID"/client-secret \
                -r "$KEYCLOAK_REALM" 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
            
            if [ -n "$CLIENT_SECRET" ]; then
                echo "   🔑 Client Secret: $CLIENT_SECRET"
                echo "   💡 Actualiza N8N_OIDC_CLIENT_SECRET en .env con este valor"
            fi
        fi
    else
        echo -e "${RED}   ❌ Error al crear cliente 'n8n'${NC}"
        return 1
    fi
    echo ""
}

# Función para crear cliente Open WebUI
create_openwebui_client() {
    echo "📋 Creando cliente 'open-webui'..."
    
    # Verificar si el cliente ya existe
    if docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KEYCLOAK_REALM" \
        -q clientId=open-webui 2>/dev/null | grep -q "open-webui"; then
        echo -e "${YELLOW}   ⚠️  Cliente 'open-webui' ya existe, eliminándolo primero...${NC}"
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=open-webui 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CLIENT_ID" ]; then
            docker exec keycloak /opt/keycloak/bin/kcadm.sh delete clients/"$CLIENT_ID" \
                -r "$KEYCLOAK_REALM" > /dev/null 2>&1 || true
        fi
    fi
    
    # Crear cliente Open WebUI
    docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
        -r "$KEYCLOAK_REALM" \
        -s clientId=open-webui \
        -s name=open-webui \
        -s protocol=openid-connect \
        -s publicClient=false \
        -s standardFlowEnabled=true \
        -s directAccessGrantsEnabled=false \
        -s "redirectUris=[\"${OPEN_WEBUI_URL}/oauth/oidc/callback\"]" \
        -s "webOrigins=[\"${OPEN_WEBUI_URL}\"]" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ Cliente 'open-webui' creado${NC}"
        
        # Obtener Client ID
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=open-webui 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$CLIENT_ID" ]; then
            # Obtener Client Secret
            CLIENT_SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/"$CLIENT_ID"/client-secret \
                -r "$KEYCLOAK_REALM" 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
            
            if [ -n "$CLIENT_SECRET" ]; then
                echo "   🔑 Client Secret: $CLIENT_SECRET"
                echo "   💡 Actualiza OPEN_WEBUI_OPENID_CLIENT_SECRET en .env con este valor"
            fi
        fi
    else
        echo -e "${RED}   ❌ Error al crear cliente 'open-webui'${NC}"
        return 1
    fi
    echo ""
}

# Función para crear cliente Jenkins
create_jenkins_client() {
    echo "📋 Creando cliente 'jenkins'..."
    
    # Verificar si el cliente ya existe
    if docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KEYCLOAK_REALM" \
        -q clientId=jenkins 2>/dev/null | grep -q "jenkins"; then
        echo -e "${YELLOW}   ⚠️  Cliente 'jenkins' ya existe, eliminándolo primero...${NC}"
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=jenkins 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CLIENT_ID" ]; then
            docker exec keycloak /opt/keycloak/bin/kcadm.sh delete clients/"$CLIENT_ID" \
                -r "$KEYCLOAK_REALM" > /dev/null 2>&1 || true
        fi
    fi
    
    # Crear cliente Jenkins
    docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
        -r "$KEYCLOAK_REALM" \
        -s clientId=jenkins \
        -s name=jenkins \
        -s protocol=openid-connect \
        -s publicClient=false \
        -s standardFlowEnabled=true \
        -s directAccessGrantsEnabled=false \
        -s fullScopeAllowed=false \
        -s "redirectUris=[\"${JENKINS_URL}/securityRealm/finishLogin\"]" \
        -s "webOrigins=[\"${JENKINS_URL}\"]" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✅ Cliente 'jenkins' creado${NC}"
        
        # Obtener Client ID
        CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KEYCLOAK_REALM" \
            -q clientId=jenkins 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$CLIENT_ID" ]; then
            # Obtener Client Secret
            CLIENT_SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/"$CLIENT_ID"/client-secret \
                -r "$KEYCLOAK_REALM" 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
            
            if [ -n "$CLIENT_SECRET" ]; then
                echo "   🔑 Client Secret: $CLIENT_SECRET"
                echo "   💡 Actualiza JENKINS_OIDC_CLIENT_SECRET en .env con este valor"
            fi
        fi
    else
        echo -e "${RED}   ❌ Error al crear cliente 'jenkins'${NC}"
        return 1
    fi
    echo ""
}

# Ejecutar creación de clientes
echo "🔄 Recreando clientes de Keycloak..."
echo ""

create_grafana_client
create_n8n_client
create_openwebui_client
create_jenkins_client

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✅ Clientes recreados exitosamente${NC}"
echo ""
echo "📋 Próximos pasos:"
echo "   1. Actualiza los Client Secrets en .env con los valores mostrados arriba"
echo "   2. Reinicia los servicios si es necesario:"
echo "      docker compose restart grafana n8n open-webui jenkins"
echo "   3. Prueba el login en cada servicio"
echo ""
echo "🌐 URLs de servicios:"
echo "   - Grafana: $GRAFANA_URL"
echo "   - n8n: $N8N_URL"
echo "   - Open WebUI: $OPEN_WEBUI_URL"
echo "   - Jenkins: $JENKINS_URL"
echo ""

