#!/bin/bash

# =============================================================================
# Script para mostrar las credenciales de Keycloak
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "🔑 CREDENCIALES DE KEYCLOAK"
echo "============================"
echo ""

# Buscar en docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "📋 Desde docker-compose.yml:"
    KEYCLOAK_USER=$(grep "KEYCLOAK_ADMIN=" docker-compose.yml | head -1 | sed 's/.*KEYCLOAK_ADMIN=\([^ ]*\).*/\1/' | tr -d '[:space:]')
    KEYCLOAK_PASS=$(grep "KEYCLOAK_ADMIN_PASSWORD=" docker-compose.yml | head -1 | sed 's/.*KEYCLOAK_ADMIN_PASSWORD=\([^ ]*\).*/\1/' | tr -d '[:space:]')
    
    if [ -n "$KEYCLOAK_USER" ] && [ -n "$KEYCLOAK_PASS" ]; then
        echo "   Usuario: $KEYCLOAK_USER"
        echo "   Contraseña: $KEYCLOAK_PASS"
    else
        echo "   ⚠️ No se encontraron credenciales en docker-compose.yml"
    fi
fi

echo ""

# Buscar en .env si existe
if [ -f ".env" ]; then
    echo "📋 Desde .env:"
    if grep -q "KEYCLOAK_ADMIN" .env; then
        grep "KEYCLOAK_ADMIN" .env | head -2
    else
        echo "   ⚠️ No se encontraron credenciales en .env"
    fi
    echo ""
fi

# Verificar si Keycloak está corriendo
if command -v docker > /dev/null 2>&1; then
    DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then
        if sudo docker ps > /dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
        fi
    fi
    
    if $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
        echo "✅ Keycloak está corriendo"
        echo ""
        echo "🌐 Acceso:"
        echo "   Admin Console: http://localhost:8080/admin"
        echo "   Página principal: http://localhost:8080"
    else
        echo "⚠️ Keycloak no está corriendo"
        echo "   Para levantarlo: docker compose --profile security up -d keycloak"
    fi
fi

echo ""
echo "📚 Para más información, consulta: docs/KEYCLOAK_CREDENTIALS.md"

