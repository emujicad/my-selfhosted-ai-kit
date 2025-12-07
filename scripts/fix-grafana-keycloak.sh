#!/bin/bash

# =============================================================================
# Script para diagnosticar y solucionar problemas de login Grafana-Keycloak
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Detectar Docker
DOCKER_CMD="docker"
if ! docker ps > /dev/null 2>&1; then
    if sudo docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        echo "❌ Docker no está disponible"
        exit 1
    fi
fi

echo "🔧 DIAGNÓSTICO Y SOLUCIÓN: Grafana-Keycloak Login"
echo "=================================================="
echo ""

ERRORS=0

# 1. Verificar servicios corriendo
echo "1️⃣  Verificando servicios..."
if $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
    echo "   ✅ Keycloak está corriendo"
else
    echo "   ❌ Keycloak NO está corriendo"
    echo "      Levántalo: docker compose --profile security up -d keycloak"
    ((ERRORS++))
fi

if $DOCKER_CMD ps 2>/dev/null | grep -q grafana; then
    echo "   ✅ Grafana está corriendo"
else
    echo "   ❌ Grafana NO está corriendo"
    echo "      Levántalo: docker compose --profile monitoring up -d grafana"
    ((ERRORS++))
fi

echo ""

# 2. Verificar configuración en docker-compose.yml
echo "2️⃣  Verificando configuración en docker-compose.yml..."

CLIENT_SECRET=$(grep "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=" docker-compose.yml | head -1 | sed 's/.*=\([^ ]*\).*/\1/')
AUTH_URL=$(grep "GF_AUTH_GENERIC_OAUTH_AUTH_URL=" docker-compose.yml | head -1 | sed 's/.*=\([^ ]*\).*/\1/')

if [ -n "$CLIENT_SECRET" ]; then
    echo "   ✅ Client Secret configurado: ${CLIENT_SECRET:0:20}..."
else
    echo "   ❌ Client Secret NO encontrado"
    ((ERRORS++))
fi

if echo "$AUTH_URL" | grep -q "localhost:8080"; then
    echo "   ✅ AUTH_URL usa localhost:8080 (correcto)"
else
    echo "   ⚠️  AUTH_URL puede tener problemas: $AUTH_URL"
fi

echo ""

# 3. Verificar logs recientes
echo "3️⃣  Revisando logs recientes..."
echo ""
echo "   Logs de Grafana (últimos errores OAuth):"
GRAFANA_LOGS=$($DOCKER_CMD compose --profile monitoring logs grafana 2>&1 | grep -i "oauth\|keycloak\|error\|denied" | tail -5)
if [ -n "$GRAFANA_LOGS" ]; then
    echo "$GRAFANA_LOGS"
else
    echo "   ℹ️  No se encontraron errores recientes en logs"
fi

echo ""
echo "   Logs de Keycloak (últimos errores):"
KEYCLOAK_LOGS=$($DOCKER_CMD compose --profile security logs keycloak 2>&1 | grep -i "error\|denied\|client\|grafana" | tail -5)
if [ -n "$KEYCLOAK_LOGS" ]; then
    echo "$KEYCLOAK_LOGS"
else
    echo "   ℹ️  No se encontraron errores recientes en logs"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 4. Soluciones comunes
echo "🔧 SOLUCIONES COMUNES PARA 'Login provider denied login request'"
echo "================================================================="
echo ""

echo "Solución 1: Verificar Redirect URI en Keycloak"
echo "   1. Accede a: http://localhost:8080/admin"
echo "   2. Login: admin / admin"
echo "   3. Ve a: Clients → grafana → Settings"
echo "   4. Verifica que 'Valid Redirect URIs' contenga EXACTAMENTE:"
echo "      http://localhost:3001/login/generic_oauth"
echo "   5. Haz clic en Save"
echo ""

echo "Solución 2: Verificar Client Secret"
echo "   1. En Keycloak Admin: Clients → grafana → Credentials"
echo "   2. Copia el Client Secret"
echo "   3. Verifica que coincida con docker-compose.yml:"
echo "      grep GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET docker-compose.yml"
echo "   4. Si no coincide, actualiza docker-compose.yml y reinicia Grafana:"
echo "      docker compose --profile monitoring restart grafana"
echo ""

echo "Solución 3: Crear un nuevo usuario en Keycloak"
echo "   1. En Keycloak Admin: Users → Add user"
echo "   2. Username: grafana-user (o el que prefieras)"
echo "   3. Email: (opcional)"
echo "   4. Haz clic en Create"
echo "   5. Ve a la pestaña Credentials"
echo "   6. Haz clic en Set Password"
echo "   7. Ingresa contraseña"
echo "   8. ⚠️  DESMARCA 'Temporary'"
echo "   9. Haz clic en Save"
echo "   10. Usa este usuario para login en Grafana"
echo ""

echo "Solución 4: Verificar que el cliente está habilitado"
echo "   1. En Keycloak Admin: Clients → grafana → Settings"
echo "   2. Verifica que 'Client authentication' esté en 'On'"
echo "   3. Verifica que 'Standard flow' esté marcado"
echo "   4. Haz clic en Save"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ Servicios corriendo correctamente"
    echo ""
    echo "📋 Próximos pasos:"
    echo "   1. Verifica la configuración en Keycloak (Solución 1 y 2)"
    echo "   2. Crea un usuario nuevo si es necesario (Solución 3)"
    echo "   3. Intenta login nuevamente en Grafana"
else
    echo "⚠️  Se encontraron $ERRORS problema(s)"
    echo "   Corrige los problemas antes de continuar"
fi

echo ""
echo "📚 Documentación: docs/HOW_TO_LOGIN_GRAFANA.md"

