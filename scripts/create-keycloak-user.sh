#!/bin/bash

# =============================================================================
# Script para crear un usuario en Keycloak vía API
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

echo "👤 CREAR USUARIO EN KEYCLOAK"
echo "============================"
echo ""

# Obtener token de admin
echo "1. Obteniendo token de administrador..."
ADMIN_TOKEN=$($DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password admin 2>&1 | grep -i "logged\|success" || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
    echo "   ⚠️ No se pudo obtener token automáticamente"
    echo ""
    echo "📋 INSTRUCCIONES MANUALES:"
    echo "   1. Accede a Keycloak Admin: http://localhost:8080/admin"
    echo "   2. Login: admin / admin"
    echo "   3. Ve a: Users → Add user"
    echo "   4. Completa el formulario"
    echo "   5. Ve a Credentials → Set Password"
    echo "   6. Desmarca 'Temporary'"
    echo ""
    exit 0
fi

# Solicitar datos del usuario
read -p "Username del nuevo usuario: " USERNAME
read -p "Email (opcional): " EMAIL
read -sp "Contraseña: " PASSWORD
echo ""

if [ -z "$USERNAME" ]; then
    echo "❌ Username es requerido"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo "❌ Contraseña es requerida"
    exit 1
fi

echo ""
echo "2. Creando usuario..."

# Crear usuario vía API de Keycloak
CREATE_RESULT=$($DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh create users -r master -s username="$USERNAME" -s email="$EMAIL" -s enabled=true 2>&1)

if echo "$CREATE_RESULT" | grep -q "Created\|created"; then
    echo "   ✅ Usuario creado"
    
    # Obtener ID del usuario
    USER_ID=$($DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh get users -r master -q username="$USERNAME" 2>&1 | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$USER_ID" ]; then
        echo "3. Estableciendo contraseña..."
        $DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh set-password -r master --username "$USERNAME" --new-password "$PASSWORD" --temporary false 2>&1 | grep -q "success\|Set" && echo "   ✅ Contraseña establecida" || echo "   ⚠️ Verifica la contraseña manualmente"
        
        echo ""
        echo "✅ Usuario creado exitosamente"
        echo ""
        echo "📋 Credenciales:"
        echo "   Usuario: $USERNAME"
        echo "   Contraseña: (la que ingresaste)"
        echo ""
        echo "🌐 Ahora puedes usar este usuario para login en Grafana"
    else
        echo "   ⚠️ Usuario creado pero no se pudo establecer contraseña automáticamente"
        echo "   Establece la contraseña manualmente en Keycloak Admin"
    fi
else
    echo "   ❌ Error al crear usuario"
    echo "$CREATE_RESULT"
    echo ""
    echo "📋 Crea el usuario manualmente:"
    echo "   1. http://localhost:8080/admin"
    echo "   2. Users → Add user"
    exit 1
fi

