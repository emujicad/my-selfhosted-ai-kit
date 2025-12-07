#!/bin/bash

# =============================================================================
# Script de Ayuda para Configurar Keycloak con Grafana
# =============================================================================
# Este script te guía paso a paso para configurar Keycloak con Grafana
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "🔐 CONFIGURACIÓN DE KEYCLOAK CON GRAFANA"
echo "========================================="
echo ""
echo "⚠️  IMPORTANTE: Grafana usa OAuth con Keycloak, NO credenciales directas"
echo ""
echo "Para usar Grafana necesitas:"
echo "  1. Un usuario creado en Keycloak"
echo "  2. El cliente 'grafana' configurado en Keycloak"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar que Keycloak está corriendo
if command -v docker > /dev/null 2>&1; then
    DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then
        if sudo docker ps > /dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
        fi
    fi
    
    if $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
        echo "✅ Keycloak está corriendo"
    else
        echo "❌ Keycloak NO está corriendo"
        echo "   Levántalo con: docker compose --profile security up -d keycloak"
        exit 1
    fi
fi

echo ""
echo "📋 PASO 1: CREAR USUARIO EN KEYCLOAK"
echo "------------------------------------"
echo ""
echo "1. Abre en tu navegador: http://localhost:8080/admin"
echo "2. Login con:"
echo "   Usuario: admin"
echo "   Contraseña: admin"
echo ""
echo "3. Ve a: Users → Add user"
echo "4. Completa:"
echo "   - Username: (ej: grafana-user)"
echo "   - Email: (opcional)"
echo "5. Haz clic en Create"
echo "6. Ve a la pestaña Credentials"
echo "7. Haz clic en Set Password"
echo "8. Ingresa la contraseña"
echo "9. ⚠️  DESMARCA 'Temporary'"
echo "10. Haz clic en Save"
echo ""
read -p "Presiona Enter cuando hayas creado el usuario..."

echo ""
echo "📋 PASO 2: CONFIGURAR CLIENTE 'grafana' EN KEYCLOAK"
echo "---------------------------------------------------"
echo ""
echo "1. En Keycloak Admin Console, ve a: Clients"
echo ""
echo "2. Si el cliente 'grafana' NO existe:"
echo "   - Haz clic en Create client"
echo "   - Client ID: grafana"
echo "   - Client Protocol: openid-connect"
echo "   - Haz clic en Next"
echo ""
echo "3. Configura el cliente:"
echo "   - Access Type: confidential"
echo "   - Standard Flow Enabled: ✅ (activado)"
echo "   - Direct Access Grants Enabled: ✅ (activado)"
echo "   - Valid Redirect URIs: http://localhost:3001/login/generic_oauth"
echo "   - Web Origins: http://localhost:3001"
echo "   - Haz clic en Save"
echo ""
echo "4. Ve a la pestaña Credentials"
echo "5. Copia el valor de Secret"
echo ""
read -p "Presiona Enter cuando hayas configurado el cliente..."

echo ""
echo "📋 PASO 3: ACTUALIZAR CLIENT SECRET EN docker-compose.yml"
echo "--------------------------------------------------------"
echo ""
echo "El Client Secret actual en docker-compose.yml es:"
grep "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET" docker-compose.yml | head -1
echo ""
echo "Si copiaste un Secret diferente de Keycloak, actualiza docker-compose.yml:"
echo "   Busca: GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"
echo "   Reemplaza el valor con el Secret que copiaste"
echo ""
read -p "¿Quieres actualizar el Client Secret ahora? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    read -p "Pega el Client Secret de Keycloak: " CLIENT_SECRET
    if [ -n "$CLIENT_SECRET" ]; then
        # Actualizar docker-compose.yml
        sed -i "s|GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=.*|GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$CLIENT_SECRET|" docker-compose.yml
        echo "✅ Client Secret actualizado en docker-compose.yml"
        echo ""
        echo "🔄 Reiniciando Grafana..."
        $DOCKER_CMD compose --profile monitoring restart grafana 2>&1 | tail -3
    fi
fi

echo ""
echo "📋 PASO 4: PROBAR LOGIN EN GRAFANA"
echo "----------------------------------"
echo ""
echo "1. Abre en tu navegador: http://localhost:3001"
echo "2. Haz clic en 'Sign in with Keycloak'"
echo "3. Ingresa las credenciales del usuario que creaste en Keycloak"
echo "   (NO uses admin/admin a menos que quieras usar el admin)"
echo ""
echo "✅ Si todo está bien, serás redirigido a Grafana después del login"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Documentación completa: docs/GRAFANA_KEYCLOAK_SETUP.md"
echo ""

