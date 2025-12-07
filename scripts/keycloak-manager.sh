#!/bin/bash

# =============================================================================
# Script Maestro: Gestión Completa de Keycloak
# =============================================================================
# Este script consolida todas las operaciones relacionadas con Keycloak
# Reemplaza: setup-keycloak.sh, show-keycloak-credentials.sh, create-keycloak-user.sh
# Referencia: init-keycloak-db.sql
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

# Función de ayuda
show_help() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}Gestor de Keycloak - My Self-Hosted AI Kit${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
    echo "USO:"
    echo "    ./scripts/keycloak-manager.sh [COMANDO] [OPCIONES]"
    echo ""
    echo "COMANDOS:"
    echo "    setup [servicio]      Configurar cliente Keycloak para un servicio"
    echo "                          Servicios: grafana, n8n, openwebui"
    echo ""
    echo "    verify [servicio]     Verificar configuración (solo Grafana por ahora)"
    echo ""
    echo "    fix [servicio]        Diagnosticar y solucionar problemas (solo Grafana por ahora)"
    echo ""
    echo "    credentials           Mostrar credenciales de Keycloak"
    echo ""
    echo "    create-user           Crear un nuevo usuario en Keycloak vía API"
    echo ""
    echo "    init-db               Inicializar base de datos de Keycloak (si no existe)"
    echo ""
    echo "    status                Verificar estado de Keycloak y servicios relacionados"
    echo ""
    echo "    help                  Mostrar esta ayuda"
    echo ""
    echo "EJEMPLOS:"
    echo "    ./scripts/keycloak-manager.sh setup grafana"
    echo "    ./scripts/keycloak-manager.sh setup n8n"
    echo "    ./scripts/keycloak-manager.sh setup openwebui"
    echo "    ./scripts/keycloak-manager.sh verify grafana"
    echo "    ./scripts/keycloak-manager.sh fix grafana"
    echo "    ./scripts/keycloak-manager.sh credentials"
    echo "    ./scripts/keycloak-manager.sh create-user"
    echo "    ./scripts/keycloak-manager.sh init-db"
    echo "    ./scripts/keycloak-manager.sh status"
    echo ""
}

# Detectar Docker
detect_docker() {
    DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then
        if sudo docker ps > /dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
        else
            echo -e "${RED}❌ Docker no está disponible${NC}"
            exit 1
        fi
    fi
    echo "$DOCKER_CMD"
}

# Verificar que Keycloak está corriendo
check_keycloak_running() {
    local DOCKER_CMD=$1
    if ! $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
        echo -e "${RED}❌ Keycloak NO está corriendo${NC}"
        echo "   Levántalo con: docker compose --profile security up -d keycloak"
        return 1
    fi
    echo -e "${GREEN}✅ Keycloak está corriendo${NC}"
    return 0
}

# Configuración de servicios
declare -A SERVICE_CONFIG
SERVICE_CONFIG[grafana_client_id]="grafana"
SERVICE_CONFIG[grafana_redirect_uri]="http://localhost:3001/login/generic_oauth"
SERVICE_CONFIG[grafana_web_origins]="http://localhost:3001"
SERVICE_CONFIG[grafana_url]="http://localhost:3001"
SERVICE_CONFIG[grafana_env_var]="GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET"
SERVICE_CONFIG[grafana_profile]="monitoring"
SERVICE_CONFIG[grafana_service_name]="grafana"
SERVICE_CONFIG[grafana_direct_access]="true"

SERVICE_CONFIG[n8n_client_id]="n8n"
SERVICE_CONFIG[n8n_redirect_uri]="http://localhost:5678/rest/oauth2-credential/callback"
SERVICE_CONFIG[n8n_web_origins]="http://localhost:5678"
SERVICE_CONFIG[n8n_url]="http://localhost:5678"
SERVICE_CONFIG[n8n_env_var]="N8N_OIDC_CLIENT_SECRET"
SERVICE_CONFIG[n8n_profile]=""
SERVICE_CONFIG[n8n_service_name]="n8n"
SERVICE_CONFIG[n8n_direct_access]="false"

SERVICE_CONFIG[openwebui_client_id]="open-webui"
SERVICE_CONFIG[openwebui_redirect_uri]="http://localhost:3000/oauth/oidc/callback"
SERVICE_CONFIG[openwebui_web_origins]="http://localhost:3000"
SERVICE_CONFIG[openwebui_url]="http://localhost:3000"
SERVICE_CONFIG[openwebui_env_var]="OPEN_WEBUI_OPENID_CLIENT_SECRET"
SERVICE_CONFIG[openwebui_profile]=""
SERVICE_CONFIG[openwebui_service_name]="open-webui"
SERVICE_CONFIG[openwebui_direct_access]="false"

# =============================================================================
# COMANDO: Mostrar Credenciales
# =============================================================================
cmd_credentials() {
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
    local DOCKER_CMD=$(detect_docker)
    if $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
        echo -e "${GREEN}✅ Keycloak está corriendo${NC}"
        echo ""
        echo "🌐 Acceso:"
        echo "   Admin Console: http://localhost:8080/admin"
        echo "   Página principal: http://localhost:8080"
    else
        echo -e "${YELLOW}⚠️ Keycloak no está corriendo${NC}"
        echo "   Para levantarlo: docker compose --profile security up -d keycloak"
    fi
    
    echo ""
}

# =============================================================================
# COMANDO: Crear Usuario
# =============================================================================
cmd_create_user() {
    local DOCKER_CMD=$(detect_docker)
    
    echo "👤 CREAR USUARIO EN KEYCLOAK"
    echo "============================"
    echo ""
    
    if ! check_keycloak_running "$DOCKER_CMD"; then
        exit 1
    fi
    
    echo ""
    echo "1. Obteniendo token de administrador..."
    
    # Intentar obtener token (puede fallar si no está configurado)
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
        echo -e "${RED}❌ Username es requerido${NC}"
        exit 1
    fi
    
    if [ -z "$PASSWORD" ]; then
        echo -e "${RED}❌ Contraseña es requerida${NC}"
        exit 1
    fi
    
    echo ""
    echo "2. Creando usuario..."
    
    # Crear usuario vía API de Keycloak
    CREATE_RESULT=$($DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh create users -r master -s username="$USERNAME" -s email="$EMAIL" -s enabled=true 2>&1)
    
    if echo "$CREATE_RESULT" | grep -q "Created\|created"; then
        echo -e "${GREEN}   ✅ Usuario creado${NC}"
        
        # Obtener ID del usuario
        USER_ID=$($DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh get users -r master -q username="$USERNAME" 2>&1 | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$USER_ID" ]; then
            echo "3. Estableciendo contraseña..."
            $DOCKER_CMD exec keycloak /opt/keycloak/bin/kcadm.sh set-password -r master --username "$USERNAME" --new-password "$PASSWORD" --temporary false 2>&1 | grep -q "success\|Set" && echo -e "${GREEN}   ✅ Contraseña establecida${NC}" || echo -e "${YELLOW}   ⚠️ Verifica la contraseña manualmente${NC}"
            
            echo ""
            echo -e "${GREEN}✅ Usuario creado exitosamente${NC}"
            echo ""
            echo "📋 Credenciales:"
            echo "   Usuario: $USERNAME"
            echo "   Contraseña: (la que ingresaste)"
            echo ""
            echo "🌐 Ahora puedes usar este usuario para login en Grafana, n8n, etc."
        else
            echo -e "${YELLOW}   ⚠️ Usuario creado pero no se pudo establecer contraseña automáticamente${NC}"
            echo "   Establece la contraseña manualmente en Keycloak Admin"
        fi
    else
        echo -e "${RED}   ❌ Error al crear usuario${NC}"
        echo "$CREATE_RESULT"
        echo ""
        echo "📋 Crea el usuario manualmente:"
        echo "   1. http://localhost:8080/admin"
        echo "   2. Users → Add user"
        exit 1
    fi
    
    echo ""
}

# =============================================================================
# COMANDO: Inicializar Base de Datos
# =============================================================================
cmd_init_db() {
    local DOCKER_CMD=$(detect_docker)
    
    echo "🗄️  INICIALIZACIÓN DE BASE DE DATOS KEYCLOAK"
    echo "============================================="
    echo ""
    
    # Verificar que PostgreSQL está corriendo
    if ! $DOCKER_CMD ps 2>/dev/null | grep -q postgres; then
        echo -e "${RED}❌ PostgreSQL NO está corriendo${NC}"
        echo "   Levántalo con: docker compose up -d postgres"
        exit 1
    fi
    
    echo -e "${GREEN}✅ PostgreSQL está corriendo${NC}"
    echo ""
    
    # Verificar si existe el script SQL
    local SQL_SCRIPT="${SCRIPT_DIR}/init-keycloak-db.sql"
    if [ ! -f "$SQL_SCRIPT" ]; then
        echo -e "${YELLOW}⚠️ Script SQL no encontrado: $SQL_SCRIPT${NC}"
        exit 1
    fi
    
    echo "📋 Ejecutando script de inicialización..."
    echo ""
    
    # Cargar variables de entorno si existen
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env" || true
    fi
    
    # Ejecutar script SQL
    $DOCKER_CMD exec -i postgres psql -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" < "$SQL_SCRIPT" || {
        echo -e "${RED}❌ Error al ejecutar script SQL${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✅ Base de datos inicializada${NC}"
    echo ""
    echo "📋 La base de datos 'keycloak' ha sido creada si no existía"
    echo "   Keycloak creará automáticamente todas las tablas necesarias"
    echo "   cuando se inicie por primera vez"
    echo ""
}

# =============================================================================
# COMANDO: Estado de Keycloak
# =============================================================================
cmd_status() {
    local DOCKER_CMD=$(detect_docker)
    
    echo "📊 ESTADO DE KEYCLOAK Y SERVICIOS RELACIONADOS"
    echo "==============================================="
    echo ""
    
    # Verificar Keycloak
    echo "🔐 Keycloak:"
    if check_keycloak_running "$DOCKER_CMD"; then
        echo "   URL: http://localhost:8080"
        echo "   Admin Console: http://localhost:8080/admin"
    fi
    echo ""
    
    # Verificar servicios relacionados
    echo "🔗 Servicios relacionados:"
    
    # Grafana
    if $DOCKER_CMD ps 2>/dev/null | grep -q grafana; then
        echo -e "   ${GREEN}✅ Grafana${NC} - http://localhost:3001"
    else
        echo -e "   ${YELLOW}⚠️  Grafana${NC} - No está corriendo"
    fi
    
    # n8n
    if $DOCKER_CMD ps 2>/dev/null | grep -q n8n; then
        echo -e "   ${GREEN}✅ n8n${NC} - http://localhost:5678"
    else
        echo -e "   ${YELLOW}⚠️  n8n${NC} - No está corriendo"
    fi
    
    # Open WebUI
    if $DOCKER_CMD ps 2>/dev/null | grep -q open-webui; then
        echo -e "   ${GREEN}✅ Open WebUI${NC} - http://localhost:3000"
    else
        echo -e "   ${YELLOW}⚠️  Open WebUI${NC} - No está corriendo"
    fi
    
    echo ""
    
    # Mostrar credenciales si Keycloak está corriendo
    if $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
        echo "🔑 Credenciales:"
        cmd_credentials | grep -A 5 "Desde"
    fi
    
    echo ""
}

# =============================================================================
# FUNCIONES DE SETUP (importadas de setup-keycloak.sh)
# =============================================================================

# Función para configurar cliente Grafana
setup_grafana() {
    local DOCKER_CMD=$1
    
    echo -e "${BLUE}🔐 CONFIGURACIÓN DE KEYCLOAK CON GRAFANA${NC}"
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
    
    if ! check_keycloak_running "$DOCKER_CMD"; then
        exit 1
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
    echo "💡 TIP: Puedes usar './scripts/keycloak-manager.sh create-user' para crear usuarios automáticamente"
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
    echo "   - Valid Redirect URIs: ${SERVICE_CONFIG[grafana_redirect_uri]}"
    echo "   - Web Origins: ${SERVICE_CONFIG[grafana_web_origins]}"
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
    grep "${SERVICE_CONFIG[grafana_env_var]}" docker-compose.yml | head -1 || echo "   No encontrado"
    echo ""
    echo "Si copiaste un Secret diferente de Keycloak, actualiza docker-compose.yml:"
    echo "   Busca: ${SERVICE_CONFIG[grafana_env_var]}"
    echo "   Reemplaza el valor con el Secret que copiaste"
    echo ""
    read -p "¿Quieres actualizar el Client Secret ahora? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        read -p "Pega el Client Secret de Keycloak: " CLIENT_SECRET
        if [ -n "$CLIENT_SECRET" ]; then
            # Actualizar docker-compose.yml
            sed -i "s|${SERVICE_CONFIG[grafana_env_var]}=.*|${SERVICE_CONFIG[grafana_env_var]}=$CLIENT_SECRET|" docker-compose.yml
            echo -e "${GREEN}✅ Client Secret actualizado en docker-compose.yml${NC}"
            echo ""
            echo "🔄 Reiniciando Grafana..."
            $DOCKER_CMD compose --profile ${SERVICE_CONFIG[grafana_profile]} restart ${SERVICE_CONFIG[grafana_service_name]} 2>&1 | tail -3
        fi
    fi
    
    echo ""
    echo "📋 PASO 4: PROBAR LOGIN EN GRAFANA"
    echo "----------------------------------"
    echo ""
    echo "1. Abre en tu navegador: ${SERVICE_CONFIG[grafana_url]}"
    echo "2. Haz clic en 'Sign in with Keycloak'"
    echo "3. Ingresa las credenciales del usuario que creaste en Keycloak"
    echo "   (NO uses admin/admin a menos que quieras usar el admin)"
    echo ""
    echo "✅ Si todo está bien, serás redirigido a Grafana después del login"
    echo ""
}

# Función para configurar cliente n8n
setup_n8n() {
    local DOCKER_CMD=$1
    
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}Configuración de cliente 'n8n' en Keycloak${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
    
    if ! check_keycloak_running "$DOCKER_CMD"; then
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Información del cliente n8n:${NC}"
    echo "  Client ID: ${SERVICE_CONFIG[n8n_client_id]}"
    echo "  Redirect URI: ${SERVICE_CONFIG[n8n_redirect_uri]}"
    echo "  Web Origins: ${SERVICE_CONFIG[n8n_web_origins]}"
    echo ""
    
    echo -e "${YELLOW}Pasos para configurar el cliente en Keycloak:${NC}"
    echo ""
    echo "1. Abre Keycloak Admin Console:"
    echo "   http://localhost:8080/admin"
    echo ""
    echo "2. Inicia sesión con:"
    echo "   Usuario: admin"
    echo "   Contraseña: admin"
    echo ""
    echo "3. Ve a: Clients → Create client"
    echo ""
    echo "4. Configuración básica:"
    echo "   - Client ID: ${SERVICE_CONFIG[n8n_client_id]}"
    echo "   - Client authentication: On (confidential client)"
    echo "   - Authorization: Off"
    echo "   - Click 'Next'"
    echo ""
    echo "5. Configuración de login:"
    echo "   - Standard flow: ✅ Enabled"
    echo "   - Direct access grants: ❌ Disabled (no necesario para n8n)"
    echo "   - Valid redirect URIs: ${SERVICE_CONFIG[n8n_redirect_uri]}"
    echo "   - Web origins: ${SERVICE_CONFIG[n8n_web_origins]}"
    echo "   - Click 'Save'"
    echo ""
    echo "6. Ve a la pestaña 'Credentials' y copia el 'Client secret'"
    echo ""
    echo "7. Actualiza el archivo .env con:"
    echo "   ${SERVICE_CONFIG[n8n_env_var]}=<el_secret_copiado>"
    echo ""
    echo "8. Reinicia n8n:"
    echo "   docker compose up -d --force-recreate n8n"
    echo ""
    
    # Generar secret aleatorio si no existe
    if [ -f .env ] && grep -q "${SERVICE_CONFIG[n8n_env_var]}" .env; then
        echo -e "${GREEN}✅ ${SERVICE_CONFIG[n8n_env_var]} ya está en .env${NC}"
    else
        echo -e "${YELLOW}Generando secret aleatorio para .env.example...${NC}"
        RANDOM_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 32)
        echo ""
        echo -e "${BLUE}Agrega esto a tu archivo .env:${NC}"
        echo "${SERVICE_CONFIG[n8n_env_var]}=${RANDOM_SECRET}"
        echo ""
    fi
    
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN}Configuración completada${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
    echo "Después de configurar el cliente en Keycloak y actualizar .env,"
    echo "recrea el contenedor de n8n para aplicar los cambios."
    echo ""
}

# Función para configurar cliente Open WebUI
setup_openwebui() {
    local DOCKER_CMD=$1
    
    echo -e "${BLUE}🔐 Configuración de Open WebUI con Keycloak${NC}"
    echo "=========================================="
    echo ""
    
    if ! check_keycloak_running "$DOCKER_CMD"; then
        exit 1
    fi
    
    echo "📋 PASO 1: CREAR CLIENTE 'open-webui' EN KEYCLOAK"
    echo "-------------------------------------------------"
    echo ""
    echo "1. Abre Keycloak Admin: http://localhost:8080/admin"
    echo "2. Login: admin / admin"
    echo "3. Ve a: Clients → Create client"
    echo ""
    echo "4. Configuración inicial:"
    echo "   - Client type: OpenID Connect (ya está seleccionado)"
    echo "   - Client ID: ${SERVICE_CONFIG[openwebui_client_id]}"
    echo "   - Name: ${SERVICE_CONFIG[openwebui_client_id]}"
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
    echo "  ${SERVICE_CONFIG[openwebui_web_origins]}"
    echo ""
    echo "Valid redirect URIs:"
    echo "  ${SERVICE_CONFIG[openwebui_redirect_uri]}"
    echo ""
    echo "Web Origins:"
    echo "  ${SERVICE_CONFIG[openwebui_web_origins]}"
    echo ""
    echo "Haz clic en Save"
    echo ""
    read -p "Presiona Enter cuando hayas configurado Login settings y guardado..."
    
    echo ""
    echo "📋 PASO 4: COPIAR CLIENT SECRET"
    echo "--------------------------------"
    echo ""
    echo "1. Ve a la pestaña 'Credentials' del cliente '${SERVICE_CONFIG[openwebui_client_id]}'"
    echo "2. Copia el valor de 'Secret'"
    echo ""
    read -p "Pega el Client Secret aquí: " CLIENT_SECRET
    
    if [ -z "$CLIENT_SECRET" ]; then
        echo -e "${YELLOW}⚠️  No se proporcionó Client Secret${NC}"
        exit 1
    fi
    
    echo ""
    echo "📋 PASO 5: ACTUALIZAR docker-compose.yml"
    echo "----------------------------------------"
    echo ""
    echo "El Client Secret debe actualizarse en docker-compose.yml"
    echo ""
    echo "Opción 1: Actualizar .env (recomendado)"
    echo "  Agrega esta línea a tu archivo .env:"
    echo "  ${SERVICE_CONFIG[openwebui_env_var]}=$CLIENT_SECRET"
    echo ""
    echo "Opción 2: Actualizar docker-compose.yml directamente"
    echo "  Busca: OPENID_CLIENT_SECRET=\${OPEN_WEBUI_OPENID_CLIENT_SECRET:-change_me_client_secret}"
    echo "  Reemplaza 'change_me_client_secret' con: $CLIENT_SECRET"
    echo ""
    
    read -p "¿Quieres que actualice docker-compose.yml ahora? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Buscar y reemplazar en docker-compose.yml
        if grep -q "OPENID_CLIENT_SECRET" docker-compose.yml; then
            # Usar sed para reemplazar (requiere escape de caracteres especiales)
            ESCAPED_SECRET=$(echo "$CLIENT_SECRET" | sed 's/[[\.*^$()+?{|]/\\&/g')
            sed -i "s/OPENID_CLIENT_SECRET=\${OPEN_WEBUI_OPENID_CLIENT_SECRET:-change_me_client_secret}/OPENID_CLIENT_SECRET=$ESCAPED_SECRET/" docker-compose.yml
            echo -e "${GREEN}✅ docker-compose.yml actualizado${NC}"
        else
            echo -e "${YELLOW}⚠️  No se encontró OPENID_CLIENT_SECRET en docker-compose.yml${NC}"
        fi
    fi
    
    echo ""
    echo "📋 PASO 6: REINICIAR OPEN WEBUI"
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
        $DOCKER_CMD compose restart open-webui 2>/dev/null || $DOCKER_CMD compose up -d --force-recreate open-webui
        echo ""
        echo "⏳ Espera 20 segundos para que Open WebUI reinicie..."
        sleep 20
        echo -e "${GREEN}✅ Open WebUI reiniciado${NC}"
    fi
    
    echo ""
    echo "✅ CONFIGURACIÓN COMPLETADA"
    echo "==========================="
    echo ""
    echo "Prueba el login en: ${SERVICE_CONFIG[openwebui_url]}"
    echo "Deberías ver la opción de login con Keycloak"
    echo ""
}

# Función para verificar configuración Grafana
verify_grafana() {
    echo "🔍 VERIFICACIÓN SIMPLE: Keycloak + Grafana"
    echo "=========================================="
    echo ""
    
    # Verificar que Docker está corriendo
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker no está corriendo${NC}"
        exit 1
    fi
    
    # Verificar servicios
    echo "📋 1. Verificando servicios..."
    echo ""
    
    KEYCLOAK_STATUS=$(docker compose --profile security ps keycloak 2>/dev/null | grep -c "Up" || echo "0")
    GRAFANA_STATUS=$(docker compose --profile monitoring ps grafana 2>/dev/null | grep -c "Up" || echo "0")
    
    if [ "$KEYCLOAK_STATUS" -eq "0" ]; then
        echo -e "${RED}❌ Keycloak NO está corriendo${NC}"
        echo "   Ejecuta: docker compose --profile security up -d keycloak"
    else
        echo -e "${GREEN}✅ Keycloak está corriendo${NC}"
    fi
    
    if [ "$GRAFANA_STATUS" -eq "0" ]; then
        echo -e "${RED}❌ Grafana NO está corriendo${NC}"
        echo "   Ejecuta: docker compose --profile monitoring up -d grafana"
    else
        echo -e "${GREEN}✅ Grafana está corriendo${NC}"
    fi
    
    echo ""
    echo "📋 2. Configuración en docker-compose.yml:"
    echo ""
    
    CLIENT_SECRET=$(grep "${SERVICE_CONFIG[grafana_env_var]}" docker-compose.yml | head -1 | cut -d'=' -f2 | tr -d ' ' || echo "NO_ENCONTRADO")
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
    echo "   🔹 Verifica Redirect URI: ${SERVICE_CONFIG[grafana_redirect_uri]}"
    echo ""
    
    echo "📋 4. PROBAR LOGIN:"
    echo ""
    echo "   🔹 Abre: ${SERVICE_CONFIG[grafana_url]}"
    echo "   🔹 Click 'Sign in with Keycloak'"
    echo "   🔹 Usa: admin / admin (credenciales de Keycloak)"
    echo ""
}

# Función para diagnosticar y solucionar problemas Grafana
fix_grafana() {
    local DOCKER_CMD=$(detect_docker)
    
    echo "🔧 DIAGNÓSTICO Y SOLUCIÓN: Grafana-Keycloak Login"
    echo "=================================================="
    echo ""
    
    ERRORS=0
    
    # 1. Verificar servicios corriendo
    echo "1️⃣  Verificando servicios..."
    if $DOCKER_CMD ps 2>/dev/null | grep -q keycloak; then
        echo -e "${GREEN}   ✅ Keycloak está corriendo${NC}"
    else
        echo -e "${RED}   ❌ Keycloak NO está corriendo${NC}"
        echo "      Levántalo: docker compose --profile security up -d keycloak"
        ((ERRORS++))
    fi
    
    if $DOCKER_CMD ps 2>/dev/null | grep -q grafana; then
        echo -e "${GREEN}   ✅ Grafana está corriendo${NC}"
    else
        echo -e "${RED}   ❌ Grafana NO está corriendo${NC}"
        echo "      Levántalo: docker compose --profile monitoring up -d grafana"
        ((ERRORS++))
    fi
    
    echo ""
    
    # 2. Verificar configuración en docker-compose.yml
    echo "2️⃣  Verificando configuración en docker-compose.yml..."
    
    CLIENT_SECRET=$(grep "${SERVICE_CONFIG[grafana_env_var]}=" docker-compose.yml | head -1 | sed 's/.*=\([^ ]*\).*/\1/')
    AUTH_URL=$(grep "GF_AUTH_GENERIC_OAUTH_AUTH_URL=" docker-compose.yml | head -1 | sed 's/.*=\([^ ]*\).*/\1/')
    
    if [ -n "$CLIENT_SECRET" ]; then
        echo -e "${GREEN}   ✅ Client Secret configurado: ${CLIENT_SECRET:0:20}...${NC}"
    else
        echo -e "${RED}   ❌ Client Secret NO encontrado${NC}"
        ((ERRORS++))
    fi
    
    if echo "$AUTH_URL" | grep -q "localhost:8080"; then
        echo -e "${GREEN}   ✅ AUTH_URL usa localhost:8080 (correcto)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  AUTH_URL puede tener problemas: $AUTH_URL${NC}"
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
    echo "      ${SERVICE_CONFIG[grafana_redirect_uri]}"
    echo "   5. Haz clic en Save"
    echo ""
    
    echo "Solución 2: Verificar Client Secret"
    echo "   1. En Keycloak Admin: Clients → grafana → Credentials"
    echo "   2. Copia el Client Secret"
    echo "   3. Verifica que coincida con docker-compose.yml:"
    echo "      grep ${SERVICE_CONFIG[grafana_env_var]} docker-compose.yml"
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
    echo "   💡 TIP: Usa './scripts/keycloak-manager.sh create-user' para crear usuarios automáticamente"
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
        echo -e "${GREEN}✅ Servicios corriendo correctamente${NC}"
        echo ""
        echo "📋 Próximos pasos:"
        echo "   1. Verifica la configuración en Keycloak (Solución 1 y 2)"
        echo "   2. Crea un usuario nuevo si es necesario (Solución 3)"
        echo "   3. Intenta login nuevamente en Grafana"
    else
        echo -e "${YELLOW}⚠️  Se encontraron $ERRORS problema(s)${NC}"
        echo "   Corrige los problemas antes de continuar"
    fi
    
    echo ""
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

COMMAND=$1
shift

case "$COMMAND" in
    setup)
        DOCKER_CMD=$(detect_docker)
        SERVICE=${1:-}
        case "$SERVICE" in
            grafana)
                setup_grafana "$DOCKER_CMD"
                ;;
            n8n)
                setup_n8n "$DOCKER_CMD"
                ;;
            openwebui)
                setup_openwebui "$DOCKER_CMD"
                ;;
            *)
                echo -e "${RED}❌ Servicio no válido: $SERVICE${NC}"
                echo ""
                show_help
                exit 1
                ;;
        esac
        ;;
    verify)
        SERVICE=${1:-}
        case "$SERVICE" in
            grafana)
                verify_grafana
                ;;
            *)
                echo -e "${YELLOW}⚠️  Verificación solo disponible para Grafana por ahora${NC}"
                echo "   Usa: ./scripts/keycloak-manager.sh verify grafana"
                exit 1
                ;;
        esac
        ;;
    fix)
        SERVICE=${1:-}
        case "$SERVICE" in
            grafana)
                fix_grafana
                ;;
            *)
                echo -e "${YELLOW}⚠️  Diagnóstico solo disponible para Grafana por ahora${NC}"
                echo "   Usa: ./scripts/keycloak-manager.sh fix grafana"
                exit 1
                ;;
        esac
        ;;
    credentials)
        cmd_credentials
        ;;
    create-user)
        cmd_create_user
        ;;
    init-db)
        cmd_init_db
        ;;
    status)
        cmd_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Comando no válido: $COMMAND${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

