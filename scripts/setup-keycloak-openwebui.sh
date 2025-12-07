#!/bin/bash

# =============================================================================
# Script: Configurar Cliente Open WebUI en Keycloak
# =============================================================================
# Guía paso a paso para configurar el cliente "open-webui" en Keycloak
# =============================================================================

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔐 Configuración de Open WebUI con Keycloak${NC}"
echo "=========================================="
echo ""

echo "📋 PASO 1: CREAR CLIENTE 'open-webui' EN KEYCLOAK"
echo "-------------------------------------------------"
echo ""
echo "1. Abre Keycloak Admin: http://localhost:8080/admin"
echo "2. Login: admin / admin"
echo "3. Ve a: Clients → Create client"
echo ""
echo "4. Configuración inicial:"
echo "   - Client type: OpenID Connect (ya está seleccionado)"
echo "   - Client ID: open-webui"
echo "   - Name: open-webui"
echo "   - Haz clic en Next"
echo ""
read -p "Presiona Enter cuando hayas completado General settings..."

echo ""
echo "📋 PASO 2: CONFIGURAR CAPABILITY CONFIG"
echo "---------------------------------------"
echo ""
echo "En la sección 'Capability config':"
echo ""
echo "Client authentication:"
echo "  - Debe estar en 'On' (esto es equivalente a 'confidential')"
echo "  - Si está en 'Off', cámbialo a 'On'"
echo ""
echo "Authentication flow:"
echo "  - Standard flow: ✅ (debe estar marcado)"
echo "  - Direct access grants: ⬜ (NO es necesario, puede estar desmarcado)"
echo ""
echo "⚠️  ACLARACIÓN:"
echo "  - 'Direct access grants' NO es necesario para Open WebUI"
echo "  - Solo se usa para aplicaciones que necesitan obtener tokens directamente"
echo "  - Open WebUI usa el flujo estándar OAuth (Standard flow)"
echo ""
read -p "Presiona Enter cuando hayas configurado Capability config..."

echo ""
echo "📋 PASO 3: CONFIGURAR LOGIN SETTINGS"
echo "-------------------------------------"
echo ""
echo "En la sección 'Login settings':"
echo ""
echo "Root URL:"
echo "  http://localhost:3000"
echo ""
echo "Valid redirect URIs:"
echo "  http://localhost:3000/auth/oidc/callback"
echo ""
echo "Web Origins:"
echo "  http://localhost:3000"
echo ""
echo "Haz clic en Save"
echo ""
read -p "Presiona Enter cuando hayas configurado Login settings y guardado..."

echo ""
echo "📋 PASO 3: COPIAR CLIENT SECRET"
echo "--------------------------------"
echo ""
echo "1. Ve a la pestaña 'Credentials' del cliente 'open-webui'"
echo "2. Copia el valor de 'Secret'"
echo ""
read -p "Pega el Client Secret aquí: " CLIENT_SECRET

if [ -z "$CLIENT_SECRET" ]; then
    echo "⚠️  No se proporcionó Client Secret"
    exit 1
fi

echo ""
echo "📋 PASO 4: ACTUALIZAR docker-compose.yml"
echo "----------------------------------------"
echo ""
echo "El Client Secret debe actualizarse en docker-compose.yml"
echo ""
echo "Opción 1: Actualizar .env (recomendado)"
echo "  Agrega esta línea a tu archivo .env:"
echo "  OPEN_WEBUI_KEYCLOAK_SECRET=$CLIENT_SECRET"
echo ""
echo "Opción 2: Actualizar docker-compose.yml directamente"
echo "  Busca: OPENID_CLIENT_SECRET=\${OPEN_WEBUI_KEYCLOAK_SECRET:-change_me_client_secret}"
echo "  Reemplaza 'change_me_client_secret' con: $CLIENT_SECRET"
echo ""

read -p "¿Quieres que actualice docker-compose.yml ahora? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Buscar y reemplazar en docker-compose.yml
    if grep -q "OPENID_CLIENT_SECRET" docker-compose.yml; then
        # Usar sed para reemplazar (requiere escape de caracteres especiales)
        ESCAPED_SECRET=$(echo "$CLIENT_SECRET" | sed 's/[[\.*^$()+?{|]/\\&/g')
        sed -i "s/OPENID_CLIENT_SECRET=\${OPEN_WEBUI_KEYCLOAK_SECRET:-change_me_client_secret}/OPENID_CLIENT_SECRET=$ESCAPED_SECRET/" docker-compose.yml
        echo -e "${GREEN}✅ docker-compose.yml actualizado${NC}"
    else
        echo "⚠️  No se encontró OPENID_CLIENT_SECRET en docker-compose.yml"
    fi
fi

echo ""
echo "📋 PASO 5: REINICIAR OPEN WEBUI"
echo "-------------------------------"
echo ""
echo "Después de actualizar la configuración, reinicia Open WebUI:"
echo ""
echo "  docker compose restart open-webui"
echo ""
echo "O recrea el contenedor:"
echo ""
echo "  docker compose up -d --force-recreate open-webui"
echo ""
read -p "¿Quieres que reinicie Open WebUI ahora? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    docker compose restart open-webui 2>/dev/null || docker compose up -d --force-recreate open-webui
    echo ""
    echo "⏳ Espera 20 segundos para que Open WebUI reinicie..."
    sleep 20
    echo -e "${GREEN}✅ Open WebUI reiniciado${NC}"
fi

echo ""
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "==========================="
echo ""
echo "Prueba el login en: http://localhost:3000"
echo "Deberías ver la opción de login con Keycloak"
echo ""

