#!/bin/bash

# =============================================================================
# Script Simple: Verificar Configuración Keycloak-Grafana
# =============================================================================

set -euo pipefail

echo "🔍 VERIFICACIÓN SIMPLE: Keycloak + Grafana"
echo "=========================================="
echo ""

# Verificar que Docker está corriendo
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker no está corriendo"
    exit 1
fi

# Verificar servicios
echo "📋 1. Verificando servicios..."
echo ""

KEYCLOAK_STATUS=$(docker compose --profile security ps keycloak 2>/dev/null | grep -c "Up" || echo "0")
GRAFANA_STATUS=$(docker compose --profile monitoring ps grafana 2>/dev/null | grep -c "Up" || echo "0")

if [ "$KEYCLOAK_STATUS" -eq "0" ]; then
    echo "❌ Keycloak NO está corriendo"
    echo "   Ejecuta: docker compose --profile security up -d keycloak"
else
    echo "✅ Keycloak está corriendo"
fi

if [ "$GRAFANA_STATUS" -eq "0" ]; then
    echo "❌ Grafana NO está corriendo"
    echo "   Ejecuta: docker compose --profile monitoring up -d grafana"
else
    echo "✅ Grafana está corriendo"
fi

echo ""
echo "📋 2. Configuración en docker-compose.yml:"
echo ""

CLIENT_SECRET=$(grep "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET" docker-compose.yml | head -1 | cut -d'=' -f2 | tr -d ' ' || echo "NO_ENCONTRADO")
CLIENT_ID=$(grep "GF_AUTH_GENERIC_OAUTH_CLIENT_ID" docker-compose.yml | head -1 | cut -d'=' -f2 | tr -d ' ' || echo "NO_ENCONTRADO")
REDIRECT_URI=$(grep "GF_AUTH_GENERIC_OAUTH_AUTH_URL" docker-compose.yml | head -1 | grep -o "localhost:[0-9]*" || echo "NO_ENCONTRADO")

echo "   Client ID: $CLIENT_ID"
echo "   Client Secret: ${CLIENT_SECRET:0:20}... (primeros 20 caracteres)"
echo "   Keycloak URL: http://$REDIRECT_URI"
echo ""

echo "📋 3. QUÉ VERIFICAR EN KEYCLOAK:"
echo ""
echo "   🔹 Abre: http://localhost:8080/admin"
echo "   🔹 Login: admin / admin"
echo "   🔹 Ve a: Clients → grafana → Settings"
echo "   🔹 Busca 'Direct access grants' (usa Ctrl+F si no la ves)"
echo "   🔹 Márcala ✅ y haz clic en Save"
echo "   🔹 Verifica Redirect URI: http://localhost:3001/login/generic_oauth"
echo ""

echo "📋 4. PROBAR LOGIN:"
echo ""
echo "   🔹 Abre: http://localhost:3001"
echo "   🔹 Click 'Sign in with Keycloak'"
echo "   🔹 Usa: admin / admin (credenciales de Keycloak)"
echo ""

echo "📄 Guías disponibles:"
echo "   - docs/DONDE_ESTA_DIRECT_ACCESS_GRANTS.md"
echo "   - docs/SOLUCION_SIMPLE_GRAFANA_KEYCLOAK.md"
echo ""

