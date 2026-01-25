#!/bin/bash

# =============================================================================
# MY SELF-HOSTED AI KIT - Stack Manager
# =============================================================================
# Script maestro para gestionar el stack completo de servicios Docker Compose
# con diferentes perfiles y combinaciones
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
CYAN='\033[0;36m'
NC='\033[0m'

# Detectar Docker
DOCKER_CMD="docker"
if ! docker ps > /dev/null 2>&1; then
    if sudo docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        echo -e "${RED}❌ Docker no está disponible${NC}"
        exit 1
    fi
fi

# Funciones de utilidad
print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Función de ayuda
show_help() {
    cat << 'HELP_EOF'
MY SELF-HOSTED AI KIT - Stack Manager
════════════════════════════════════════════════════════

USO:
    ./scripts/stack-manager.sh [OPCIÓN] [PERFILES...] [FLAGS]

OPCIONES:
    start [perfiles] [--setup-roles]     Levantar servicios con perfiles especificados
                                         --setup-roles: Configurar roles de Keycloak automáticamente
    stop [perfiles]      Detener servicios con perfiles especificados
    stop --clean         Detener servicios y limpiar recursos huérfanos del proyecto
    restart [perfiles]   Reiniciar servicios con perfiles especificados
    status               Mostrar estado de todos los servicios
    info                 Mostrar información de URLs y servicios disponibles
    logs [servicio]      Mostrar logs de servicios
    validate             Validar configuración antes de levantar
    auto-validate        Validación completa automática (variables, config, servicios)
    diagnose [target]    Diagnóstico detallado (keycloak-db)
    test                 Probar cambios recientes (ModSecurity, Prometheus, etc.)
    init-volumes         Inicializar volúmenes con configuraciones por defecto
    monitor              Monitorear descarga de modelos Ollama
    clean [tipo]         Limpiar recursos del proyecto (requiere que todo esté detenido)
                         Tipos: all, containers, networks, storage, (vacío=default)
                         Ejemplos:
                           ./scripts/stack-manager.sh clean          # Default: recursos huérfanos (SEGURO)
                           ./scripts/stack-manager.sh clean all      # Todo: contenedores, redes, almacenamiento, imágenes
                           ./scripts/stack-manager.sh clean containers
                           ./scripts/stack-manager.sh clean networks
                           ./scripts/stack-manager.sh clean storage
    help                 Mostrar esta ayuda

PERFILES DISPONIBLES:
    IA:
        cpu              Ollama con CPU
        gpu-nvidia       Ollama con GPU NVIDIA (recomendado)
        gpu-amd          Ollama con GPU AMD

    SERVICIOS:
        monitoring       Prometheus, Grafana, AlertManager, exporters, backup
        infrastructure   Redis, HAProxy
        security         Keycloak, ModSecurity
        automation       n8n, Watchtower, Sync
        chat-ai          Open WebUI
        ci-cd            Jenkins
        testing          Test Runner
        debug            Debug Tools
        dev              Development Tools

PRESETS (combinaciones predefinidas):
    default              gpu-nvidia + monitoring + infrastructure + security + automation + chat-ai
    minimal              Solo servicios base (sin perfiles)
    dev                  cpu + dev + testing
    production           gpu-nvidia + monitoring + infrastructure + security + automation + chat-ai
    full                 Todos los perfiles (¡cuidado con recursos!)

EJEMPLOS:
    # Levantar con preset por defecto (máximo con NVIDIA)
    ./scripts/stack-manager.sh start

    # Levantar con perfiles específicos
    ./scripts/stack-manager.sh start gpu-nvidia monitoring infrastructure

    # Levantar preset de desarrollo
    ./scripts/stack-manager.sh start dev

    # Validar antes de levantar
    ./scripts/stack-manager.sh validate && ./scripts/stack-manager.sh start

    # Ver estado
    ./scripts/stack-manager.sh status

    # Ver información de servicios
    ./scripts/stack-manager.sh info

    # Ver logs
    ./scripts/stack-manager.sh logs prometheus

NOTAS:
    - Si no especificas perfiles, se usa el preset 'default'
    - Los perfiles se pueden combinar libremente
    - Usa 'validate' antes de 'start' para verificar configuración
    - El preset 'default' incluye: gpu-nvidia + monitoring + infrastructure + security + automation + chat-ai

HELP_EOF
}

# Función para corregir automáticamente variables de .env que necesitan comillas
# Esta función se ejecuta automáticamente antes de validar variables de entorno
auto_fix_env_quotes() {
    local ENV_FILE="${PROJECT_DIR}/.env"
    
    if [ ! -f "$ENV_FILE" ]; then
        return 0  # No hay .env, no hay nada que corregir
    fi
    
    # Verificar directamente si hay variables sin comillas que las necesitan
    local needs_fix=0
    
    # Verificar SCOPES sin comillas
    if grep -qE '^(N8N_OIDC_SCOPES|OPEN_WEBUI_OAUTH_SCOPES|GRAFANA_OAUTH_SCOPES|JENKINS_OIDC_SCOPES)=openid (profile|email)' "$ENV_FILE" 2>/dev/null; then
        needs_fix=1
    fi
    
    # Verificar WATCHTOWER_SCHEDULE sin comillas
    if grep -qE '^WATCHTOWER_SCHEDULE=0 0 2 \* \* \*$' "$ENV_FILE" 2>/dev/null; then
        needs_fix=1
    fi
    
    if [ "$needs_fix" = "0" ]; then
        # No hay problemas, salir silenciosamente
        return 0
    fi
    
    # Hay problemas, corregirlos automáticamente
    local fixes_applied=0
    local fix_messages=()
    
    # Crear backup temporal del .env ANTES de modificarlo (solo para seguridad)
    # NOTA: Este NO es un backup del sistema, solo una copia de seguridad temporal
    # del .env antes de modificarlo, para poder restaurarlo si algo sale mal.
    # Los backups del sistema completo se hacen con: ./scripts/backup-manager.sh
    local ENV_BACKUP="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Crear backup temporal
    cp "$ENV_FILE" "$ENV_BACKUP" 2>/dev/null || true
    
    # Corregir SCOPES (tienen espacios: "openid profile email")
    if grep -q '^N8N_OIDC_SCOPES=openid profile email$' "$ENV_FILE" 2>/dev/null; then
        sed -i.tmp 's/^N8N_OIDC_SCOPES=openid profile email$/N8N_OIDC_SCOPES="openid profile email"/' "$ENV_FILE" 2>/dev/null && {
            fixes_applied=$((fixes_applied + 1))
            fix_messages+=("N8N_OIDC_SCOPES")
        }
    fi
    
    if grep -q '^OPEN_WEBUI_OAUTH_SCOPES=openid profile email$' "$ENV_FILE" 2>/dev/null; then
        sed -i.tmp 's/^OPEN_WEBUI_OAUTH_SCOPES=openid profile email$/OPEN_WEBUI_OAUTH_SCOPES="openid profile email"/' "$ENV_FILE" 2>/dev/null && {
            fixes_applied=$((fixes_applied + 1))
            fix_messages+=("OPEN_WEBUI_OAUTH_SCOPES")
        }
    fi
    
    if grep -q '^GRAFANA_OAUTH_SCOPES=openid profile email$' "$ENV_FILE" 2>/dev/null; then
        sed -i.tmp 's/^GRAFANA_OAUTH_SCOPES=openid profile email$/GRAFANA_OAUTH_SCOPES="openid profile email"/' "$ENV_FILE" 2>/dev/null && {
            fixes_applied=$((fixes_applied + 1))
            fix_messages+=("GRAFANA_OAUTH_SCOPES")
        }
    fi
    
    if grep -qE '^JENKINS_OIDC_SCOPES=openid (email profile|profile email)$' "$ENV_FILE" 2>/dev/null; then
        sed -i.tmp -E 's/^JENKINS_OIDC_SCOPES=openid (email profile|profile email)$/JENKINS_OIDC_SCOPES="openid \1"/' "$ENV_FILE" 2>/dev/null && {
            fixes_applied=$((fixes_applied + 1))
            fix_messages+=("JENKINS_OIDC_SCOPES")
        }
    fi
    
    # Corregir WATCHTOWER_SCHEDULE (tiene espacios: "0 0 2 * * *")
    if grep -q '^WATCHTOWER_SCHEDULE=0 0 2 \* \* \*$' "$ENV_FILE" 2>/dev/null; then
        sed -i.tmp 's/^WATCHTOWER_SCHEDULE=0 0 2 \* \* \*$/WATCHTOWER_SCHEDULE="0 0 2 * * *"/' "$ENV_FILE" 2>/dev/null && {
            fixes_applied=$((fixes_applied + 1))
            fix_messages+=("WATCHTOWER_SCHEDULE")
        }
    fi
    
    # Limpiar archivos temporales
    rm -f "${ENV_FILE}.tmp" 2>/dev/null || true
    
    # Informar qué se corrigió
    if [ $fixes_applied -gt 0 ]; then
        print_success "✅ Archivo .env corregido automáticamente ($fixes_applied variables):"
        for msg in "${fix_messages[@]}"; do
            echo "   • $msg"
        done
        echo ""
        print_info "   Backup temporal guardado en: $(basename "$ENV_BACKUP")"
        print_info "   (Puedes restaurarlo si algo sale mal: cp $(basename "$ENV_BACKUP") .env)"
        echo ""
    fi
    
    return 0
}

# Standardized validation function
check_required_vars() {
    local missing_vars=0
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            print_error "Variable '$var' is required but not set in .env"
            missing_vars=1
        else
            # Placeholder validation
            local value="${!var}"
            if [[ "$value" == *"change_me"* ]] || [[ "$value" == *"your-"* ]]; then
                 print_warning "Variable '$var' seems to use a placeholder value: $value"
            fi
        fi
    done
    return $missing_vars
}

# Función para validar antes de levantar
# Función para generar dinámicamente userinfo.json para Open WebUI
# Esto evita subir información personal (email, nombre) al repositorio de Git
generate_oidc_userinfo() {
    local OIDC_CONFIG_DIR="$PROJECT_DIR/config/open-webui-oidc"
    local USERINFO_FILE="$OIDC_CONFIG_DIR/userinfo.json"
    
    # Valores desde .env (validados previamente en validate_before_start)
    local USER_EMAIL="${OPEN_WEBUI_OIDC_USER_EMAIL}"
    local USER_USERNAME="${OPEN_WEBUI_OIDC_USER_USERNAME}"
    local USER_NAME="${OPEN_WEBUI_OIDC_USER_NAME}"
    local GIVEN_NAME="${OPEN_WEBUI_OIDC_USER_GIVEN_NAME}"
    local FAMILY_NAME="${OPEN_WEBUI_OIDC_USER_FAMILY_NAME}"
    
    print_info "Generando configuración OIDC dinámica..."
    
    mkdir -p "$OIDC_CONFIG_DIR"
    
    cat > "$USERINFO_FILE" <<EOF
{
    "sub": "$USER_USERNAME",
    "email": "$USER_EMAIL",
    "email_verified": true,
    "preferred_username": "$USER_USERNAME",
    "name": "$USER_NAME",
    "given_name": "$GIVEN_NAME",
    "family_name": "$FAMILY_NAME"
}
EOF
    
    print_success "Archivo userinfo.json generado correctamente"
}

validate_before_start() {
    print_header "VALIDACIÓN PREVIA"
    
    local ENV_FILE="${PROJECT_DIR}/.env"
    
    # 1. Check for .env file
    if [ ! -f "$ENV_FILE" ]; then
        print_error "No .env file found!"
        print_info "Please copy .env.example to .env and configure it."
        exit 1
    fi
    
    # Load .env variables
    source "$ENV_FILE"
    
    # 2. Strict Variable Validation
    local REQUIRED_VARS=(
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "POSTGRES_DB"
        "KEYCLOAK_ADMIN_USER"
        "KEYCLOAK_ADMIN_PASSWORD"
        "GRAFANA_ADMIN_EMAIL"
        "GRAFANA_ADMIN_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "N8N_USER_MANAGEMENT_JWT_SECRET"
        "OPEN_WEBUI_OIDC_USER_EMAIL"
        "OPEN_WEBUI_OIDC_USER_USERNAME"
        "OPEN_WEBUI_OIDC_USER_NAME"
        "OPEN_WEBUI_OIDC_USER_GIVEN_NAME"
        "OPEN_WEBUI_OIDC_USER_FAMILY_NAME"
    )
    
    local MISSING_VARS=0
    check_required_vars "${REQUIRED_VARS[@]}" || MISSING_VARS=1
    
    if [ "$MISSING_VARS" -eq 1 ]; then
        print_error "Critical environment variables are missing in .env."
        print_info "Security enforcement does not allow default values for credentials."
        exit 1
    fi
    # Corregir automáticamente variables de .env que necesitan comillas
    auto_fix_env_quotes
    
    # Generar archivos de configuración dinámicos sensibles
    generate_oidc_userinfo
    
    # Verificar variables de entorno
    if [ -f "$SCRIPT_DIR/verify-env-variables.sh" ]; then
        print_info "Verificando variables de entorno..."
        if ! bash "$SCRIPT_DIR/verify-env-variables.sh" > /tmp/stack-validation.log 2>&1; then
            print_error "Errores en variables de entorno"
            cat /tmp/stack-validation.log | grep "❌ ERROR" | head -5
            return 1
        fi
        print_success "Variables de entorno OK"
    fi
    
    # Validar configuración
    if [ -f "$SCRIPT_DIR/validate-config.sh" ]; then
        print_info "Validando configuración..."
        local log_file="/tmp/stack-config-validation.log"
        if ! bash "$SCRIPT_DIR/validate-config.sh" > "$log_file" 2>&1; then
            print_warning "Algunos problemas en configuración"
            print_info "Log de validación: $log_file"
            return 0  # No bloqueamos, solo advertimos
        fi
        print_success "Configuración OK"
    fi
    
    return 0
}

# Función para obtener dependencias de un perfil
# Retorna los perfiles de los que depende un perfil dado
get_profile_dependencies() {
    local profile=$1
    case "$profile" in
        chat-ai)
            # Open WebUI requiere Keycloak (auth), Redis (cache), Ollama (IA)
            echo "security infrastructure gpu-nvidia"
            ;;
        automation)
            # n8n requiere PostgreSQL (ya incluido en base), puede usar Keycloak
            echo "security"
            ;;
        monitoring)
            # Grafana puede usar Keycloak, Prometheus necesita PostgreSQL
            echo "security infrastructure"
            ;;
        ci-cd)
            # Jenkins puede usar Keycloak
            echo "security"
            ;;
        *)
            # Otros perfiles no tienen dependencias externas
            echo ""
            ;;
    esac
}

# Función para resolver dependencias recursivamente
# Toma una lista de perfiles y agrega todas sus dependencias
resolve_dependencies() {
    local -a profiles=("$@")
    local -a resolved=()
    local -a to_process=("${profiles[@]}")
    
    # Usar un array asociativo para evitar duplicados
    declare -A seen
    
    while [ ${#to_process[@]} -gt 0 ]; do
        local current="${to_process[0]}"
        to_process=("${to_process[@]:1}")
        
        # Si ya procesamos este perfil, continuar
        # Usar ${seen[$current]:-} para evitar errores con set -u
        if [ -n "${seen[$current]:-}" ]; then
            continue
        fi
        
        # Marcar como visto
        seen[$current]=1
        resolved+=("$current")
        
        # Obtener dependencias de este perfil
        local deps=$(get_profile_dependencies "$current")
        
        # Agregar dependencias a la cola de procesamiento
        for dep in $deps; do
            if [ -z "${seen[$dep]:-}" ]; then
                to_process+=("$dep")
            fi
        done
    done
    
    # Retornar perfiles únicos en orden
    echo "${resolved[@]}"
}

# Función para expandir presets
expand_preset() {
    local preset=$1
    case "$preset" in
        default)
            echo "gpu-nvidia monitoring infrastructure security automation chat-ai"
            ;;
        minimal)
            echo ""
            ;;
        dev)
            echo "cpu dev testing"
            ;;
        production)
            echo "gpu-nvidia monitoring infrastructure security automation chat-ai"
            ;;
        full)
            echo "gpu-nvidia monitoring infrastructure security automation chat-ai ci-cd testing debug dev"
            ;;
        *)
            echo "$preset"  # Si no es un preset, devolverlo tal cual
            ;;
    esac
}

# Función para construir comando docker compose con perfiles
build_compose_command() {
    local action=$1
    shift
    local input_profiles=("$@")
    
    # Expandir presets y resolver dependencias
    local -a expanded_profiles=()
    for profile in "${input_profiles[@]}"; do
        # Expandir preset si es necesario
        local preset_profiles=$(expand_preset "$profile")
        if [ -n "$preset_profiles" ]; then
            # Si es un preset, agregar sus perfiles
            expanded_profiles+=($preset_profiles)
        else
            # Si es un perfil individual, agregarlo
            expanded_profiles+=("$profile")
        fi
    done
    
    # Resolver dependencias automáticamente
    local resolved_profiles=$(resolve_dependencies "${expanded_profiles[@]}")
    
    # Opcional: mostrar debug de perfiles resueltos
    if [ "${DEBUG_PROFILES:-false}" = "true" ]; then
        print_info "📦 Perfiles solicitados: ${input_profiles[*]}"
        print_info "🔍 Perfiles expandidos: ${expanded_profiles[*]}"
        print_info "✅ Perfiles finales (con dependencias): $resolved_profiles"
    fi
    
    local cmd="$DOCKER_CMD compose"
    
    # Agregar perfiles resueltos
    for profile in $resolved_profiles; do
        cmd="$cmd --profile $profile"
    done
    
    # Agregar acción
    case "$action" in
        up)
            cmd="$cmd up -d"
            ;;
        down)
            cmd="$cmd down"
            ;;
        restart)
            cmd="$cmd restart"
            ;;
        ps)
            cmd="$cmd ps"
            ;;
        logs)
            cmd="$cmd logs -f"
            ;;
        *)
            cmd="$cmd $action"
            ;;
    esac
    
    echo "$cmd"
}

# Función para verificar que todos los contenedores estén detenidos
check_all_containers_stopped() {
    local project_dir=$(pwd)
    local running_containers=$($DOCKER_CMD ps --filter "label=com.docker.compose.project.working_dir=$project_dir" --format "{{.Names}}" 2>/dev/null)
    
    if [ -n "$running_containers" ]; then
        print_error "❌ Hay contenedores corriendo. Debes detenerlos primero."
        print_warning "Contenedores corriendo:"
        while IFS= read -r container; do
            if [ -n "$container" ]; then
                echo "   - $container"
            fi
        done <<< "$running_containers"
        echo ""
        print_info "Ejecuta primero: ./scripts/stack-manager.sh stop"
        return 1
    fi
    
    return 0
}

# Función para limpiar contenedores en estado "Created" (problemáticos)
# Estos contenedores pueden tener referencias a redes corruptas y causan errores
# DIFERENCIA: "Created" = nunca iniciados (problemáticos) vs "exited" = detenidos (del proyecto, se reutilizan)
cleanup_created_containers() {
    local project_dir=$(pwd)
    local created_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=created" --format "{{.Names}}" 2>/dev/null)
    
    if [ -n "$created_containers" ]; then
        print_info "🧹 Limpiando contenedores en estado 'Created' (pueden tener referencias corruptas)..."
        local cleaned=0
        local failed=0
        
        while IFS= read -r container; do
            if [ -n "$container" ]; then
                if $DOCKER_CMD rm -f "$container" >/dev/null 2>&1; then
                    print_success "   Eliminado: $container"
                    cleaned=$((cleaned + 1))
                else
                    print_warning "   ⚠️  No se pudo eliminar: $container"
                    failed=$((failed + 1))
                fi
            fi
        done <<< "$created_containers"
        
        if [ $cleaned -gt 0 ]; then
            print_info "✅ Limpiados $cleaned contenedores en estado 'Created'"
        fi
        
        if [ $failed -gt 0 ]; then
            print_warning "⚠️  No se pudieron limpiar $failed contenedores"
        fi
        
        return 0
    fi
    
    return 0
}

# Función para generar reporte de recursos disponibles después de stop
generate_stop_report() {
    local project_dir=$(pwd)
    print_header "REPORTE DE RECURSOS DISPONIBLES"
    
    echo ""
    print_info "📊 Estado de recursos del proyecto después de detener servicios:"
    echo ""
    
    # Contenedores detenidos (listos para reutilizar)
    local stopped_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
    if [ -n "$stopped_containers" ]; then
        local count=$(echo "$stopped_containers" | grep -v "^$" | wc -l)
        print_success "📦 Contenedores detenidos (listos para reutilizar): $count"
        echo "$stopped_containers" | while IFS= read -r container; do
            if [ -n "$container" ]; then
                local image=$($DOCKER_CMD inspect "$container" --format '{{.Config.Image}}' 2>/dev/null)
                echo "   ✅ $container (imagen: $image)"
            fi
        done
    else
        print_info "📦 Contenedores detenidos: 0"
    fi
    
    echo ""
    
    # Redes del proyecto
    local project_networks=("genai-network" "frontend-network" "backend-network" "security-network" "monitoring-network")
    local existing_networks=()
    for network in "${project_networks[@]}"; do
        if $DOCKER_CMD network inspect "$network" >/dev/null 2>&1; then
            existing_networks+=("$network")
        fi
    done
    
    if [ ${#existing_networks[@]} -gt 0 ]; then
        print_success "🌐 Redes del proyecto (disponibles): ${#existing_networks[@]}"
        for network in "${existing_networks[@]}"; do
            local driver=$($DOCKER_CMD network inspect "$network" --format '{{.Driver}}' 2>/dev/null)
            local containers_count=$($DOCKER_CMD network inspect "$network" --format '{{len .Containers}}' 2>/dev/null)
            echo "   ✅ $network (driver: $driver, contenedores: $containers_count)"
        done
    else
        print_info "🌐 Redes del proyecto: 0"
    fi
    
    echo ""
    
    # Volúmenes del proyecto
    # Docker Compose agrega automáticamente el prefijo del proyecto a los nombres de volúmenes
    # Necesitamos obtener el nombre del proyecto primero
    local project_name=""
    if $DOCKER_CMD compose config >/dev/null 2>&1; then
        # Intentar obtener el nombre del proyecto desde docker compose config
        project_name=$($DOCKER_CMD compose config 2>/dev/null | grep -E "^name:" | head -1 | awk '{print $2}' || echo "")
    fi
    
    # Si no se pudo obtener, usar el nombre del directorio
    if [ -z "$project_name" ]; then
        project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | sed 's/--/-/g')
    fi
    
    local volume_base_names=("n8n_storage" "postgres_storage" "qdrant_storage" "pgvector_data" "open_webui_storage" "n8n_data" "shared_data" "prometheus_data" "grafana_data" "alertmanager_data" "backup_data" "redis_data" "jenkins_data" "haproxy_data" "keycloak_data" "modsecurity_data" "cadvisor_data" "node_exporter_data" "postgres_exporter_data" "config_data" "ssl_certs_data" "logs_data" "grafana_provisioning_data" "prometheus_rules_data" "ollama_storage")
    local existing_volumes=()
    
    print_success "💾 Volúmenes del proyecto (con datos persistentes):"
    for volume_base in "${volume_base_names[@]}"; do
        # Intentar primero con el prefijo del proyecto
        local volume_with_prefix="${project_name}_${volume_base}"
        local volume_found=""
        
        if $DOCKER_CMD volume inspect "$volume_with_prefix" >/dev/null 2>&1; then
            volume_found="$volume_with_prefix"
        elif $DOCKER_CMD volume inspect "$volume_base" >/dev/null 2>&1; then
            # Si no existe con prefijo, intentar sin prefijo (por compatibilidad)
            volume_found="$volume_base"
        fi
        
        if [ -n "$volume_found" ]; then
            existing_volumes+=("$volume_found")
            # Obtener tamaño del volumen (si está disponible)
            local mountpoint=$($DOCKER_CMD volume inspect "$volume_found" --format '{{.Mountpoint}}' 2>/dev/null)
            if [ -n "$mountpoint" ] && [ -d "$mountpoint" ]; then
                local size=$(du -sh "$mountpoint" 2>/dev/null | cut -f1)
                echo "   ✅ $volume_found (tamaño: $size)"
            else
                echo "   ✅ $volume_found"
            fi
        fi
    done
    
    if [ ${#existing_volumes[@]} -eq 0 ]; then
        print_info "   (ningún volumen encontrado)"
    fi
    
    echo ""
    
    # Imágenes del proyecto (usadas por los contenedores reales del proyecto)
    # Obtener imágenes de los contenedores del proyecto (más preciso que docker compose config)
    local project_images=()
    local project_dir=$(pwd)
    
    # Método 1: Intentar obtener imágenes de contenedores usando el label del directorio de trabajo
    local container_images=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --format "{{.Config.Image}}" 2>/dev/null | sort -u)
    
    # Método 2: Si no funciona, obtener de los contenedores detenidos que listamos antes
    if [ -z "$container_images" ] || [ "$(echo "$container_images" | grep -v "^$" | wc -l)" -eq 0 ]; then
        # Usar los contenedores que ya identificamos en stopped_containers
        if [ -n "$stopped_containers" ]; then
            while IFS= read -r container; do
                if [ -n "$container" ]; then
                    local img=$($DOCKER_CMD inspect "$container" --format '{{.Config.Image}}' 2>/dev/null)
                    if [ -n "$img" ]; then
                        container_images=$(echo -e "$container_images\n$img" | grep -v "^$" | sort -u)
                    fi
                fi
            done <<< "$stopped_containers"
        fi
    fi
    
    if [ -n "$container_images" ]; then
        while IFS= read -r image; do
            if [ -n "$image" ]; then
                project_images+=("$image")
            fi
        done <<< "$container_images"
    fi
    
    if [ ${#project_images[@]} -gt 0 ]; then
        print_success "🖼️  Imágenes del proyecto (disponibles localmente): ${#project_images[@]}"
        local available_count=0
        for image in "${project_images[@]}"; do
            # Verificar si la imagen existe localmente
            if $DOCKER_CMD image inspect "$image" >/dev/null 2>&1; then
                local size=$($DOCKER_CMD image inspect "$image" --format '{{.Size}}' 2>/dev/null | numfmt --to=iec-i --suffix=B 2>/dev/null || $DOCKER_CMD images "$image" --format "{{.Size}}" 2>/dev/null | head -1)
                echo "   ✅ $image (tamaño: $size)"
                available_count=$((available_count + 1))
            else
                echo "   ⚠️  $image (no disponible localmente - se descargará en el próximo start)"
            fi
        done
        if [ $available_count -lt ${#project_images[@]} ]; then
            echo ""
            print_info "   ℹ️  $available_count de ${#project_images[@]} imágenes disponibles localmente"
        fi
    else
        print_info "🖼️  Imágenes del proyecto: 0"
    fi
    
    echo ""
    print_info "📋 RESUMEN:"
    local stopped_count=$(echo "$stopped_containers" | grep -v "^$" | wc -l)
    local available_images=0
    for image in "${project_images[@]}"; do
        if $DOCKER_CMD image inspect "$image" >/dev/null 2>&1; then
            available_images=$((available_images + 1))
        fi
    done
    echo "   - Contenedores detenidos: $stopped_count"
    echo "   - Redes disponibles: ${#existing_networks[@]}"
    echo "   - Volúmenes con datos: ${#existing_volumes[@]}"
    if [ ${#project_images[@]} -gt 0 ]; then
        echo "   - Imágenes disponibles: $available_images de ${#project_images[@]} totales"
    else
        echo "   - Imágenes disponibles: 0"
    fi
    echo ""
    print_success "✅ Todos estos recursos están listos para el próximo 'start'"
    echo ""
}

# Función para limpiar recursos del proyecto
# IMPORTANTE: Esta función solo debe llamarse explícitamente (clean o stop --clean)
# NO debe llamarse automáticamente porque los contenedores detenidos del proyecto
# NO son huérfanos - pertenecen al proyecto y se reutilizarán
# Parámetro: tipo de limpieza (all, containers, networks, storage, o vacío para default)
cleanup_orphaned_resources() {
    local clean_type=${1:-"default"}
    local project_dir=$(pwd)
    local found_any=0
    local cleaned_items=()
    local failed_items=()
    
    # Verificar que todos los contenedores estén detenidos
    if ! check_all_containers_stopped; then
        return 1
    fi
    
    # Para 'clean all', mostrar un resumen completo y pedir una sola confirmación
    if [ "$clean_type" = "all" ]; then
        print_warning "LIMPIEZA COMPLETA - OPERACIÓN MUY DESTRUCTIVA"
        print_info "Se eliminará TODO del proyecto:"
        echo ""
        
        # Contenedores
        local stopped_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
        local created_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=created" --format "{{.Names}}" 2>/dev/null)
        if [ -n "$stopped_containers" ] || [ -n "$created_containers" ]; then
            print_info "📦 Contenedores:"
            if [ -n "$stopped_containers" ]; then
                echo "$stopped_containers" | while read container; do [ -n "$container" ] && echo "   - $container (detenido)"; done
            fi
            if [ -n "$created_containers" ]; then
                echo "$created_containers" | while read container; do [ -n "$container" ] && echo "   - $container (creado)"; done
            fi
        fi
        
        # Redes
        local project_networks=("genai-network" "frontend-network" "backend-network" "security-network" "monitoring-network")
        local empty_networks=()
        for network in "${project_networks[@]}"; do
            if $DOCKER_CMD network inspect "$network" >/dev/null 2>&1; then
                local containers_in_network=$($DOCKER_CMD network inspect "$network" --format '{{range .Containers}}{{.Name}}{{end}}' 2>/dev/null | tr -d '[:space:]')
                if [ -z "$containers_in_network" ]; then
                    empty_networks+=("$network")
                fi
            fi
        done
        if [ ${#empty_networks[@]} -gt 0 ]; then
            print_info "🌐 Redes:"
            for network in "${empty_networks[@]}"; do
                echo "   - $network"
            done
        fi
        
        # Volúmenes
        local project_volumes=("n8n_storage" "postgres_storage" "qdrant_storage" "pgvector_data" "open_webui_storage" "n8n_data" "shared_data" "prometheus_data" "grafana_data" "alertmanager_data" "backup_data" "redis_data" "jenkins_data" "haproxy_data" "keycloak_data" "modsecurity_data" "cadvisor_data" "node_exporter_data" "postgres_exporter_data" "config_data" "ssl_certs_data" "logs_data" "grafana_provisioning_data" "prometheus_rules_data" "ollama_storage")
        local existing_volumes=()
        
        # Obtener nombre del proyecto para prefijos
        local project_name=""
        if $DOCKER_CMD compose config >/dev/null 2>&1; then
             project_name=$($DOCKER_CMD compose config 2>/dev/null | grep -E "^name:" | head -1 | awk '{print $2}' || echo "")
        fi
        if [ -z "$project_name" ]; then
             project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | sed 's/--/-/g')
        fi
        
        for volume in "${project_volumes[@]}"; do
            # Omitir ollama_storage de la lista general (se pregunta aparte)
            if [ "$volume" == "ollama_storage" ]; then
                continue
            fi

            local volume_with_prefix="${project_name}_${volume}"
            if $DOCKER_CMD volume inspect "$volume_with_prefix" >/dev/null 2>&1; then
                existing_volumes+=("$volume_with_prefix")
            elif $DOCKER_CMD volume inspect "$volume" >/dev/null 2>&1; then
                existing_volumes+=("$volume")
            fi
        done
        
        if [ ${#existing_volumes[@]} -gt 0 ]; then
            print_info "💾 Volúmenes (${#existing_volumes[@]}):"
            for volume in "${existing_volumes[@]}"; do
                echo "   - $volume"
            done
        fi
        
        # Imágenes
        local compose_images=$($DOCKER_CMD compose config --images 2>/dev/null || echo "")
        if [ -n "$compose_images" ]; then
            print_info "🖼️  Imágenes:"
            echo "$compose_images" | while read image; do [ -n "$image" ] && echo "   - $image"; done
        fi
        
        echo ""
        print_warning "ADVERTENCIA: Esto eliminará TODOS los recursos del proyecto"
        print_warning "Esto incluye: contenedores, redes, volúmenes (datos persistentes) e imágenes"
        print_warning "Esta operación NO se puede deshacer"
        echo ""
        read -p "¿Estás ABSOLUTAMENTE seguro de que quieres continuar? (escribe 'SI' para confirmar): " -r
        echo
        if [ "$REPLY" != "SI" ]; then
            print_info "Operación cancelada"
            return 0
        fi
        print_info "Procediendo con la limpieza completa..."
        echo ""
    fi
    
    print_info "Buscando recursos del proyecto para limpiar (tipo: $clean_type)..."
    
    # Limpiar contenedores huérfanos (solo si clean_type es "default")
    # Contenedores huérfanos = contenedores creados pero no iniciados (pueden tener referencias a redes corruptas)
    if [ "$clean_type" = "default" ]; then
        # Solo limpiar contenedores creados pero no iniciados (estos SÍ pueden ser problemáticos)
        local created_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=created" --format "{{.Names}}" 2>/dev/null)
        if [ -n "$created_containers" ]; then
            found_any=1
            print_info "📦 Contenedores huérfanos (creados pero no iniciados) encontrados:"
            while IFS= read -r container; do
                if [ -n "$container" ]; then
                    echo "   - $container"
                    if $DOCKER_CMD rm -f "$container" >/dev/null 2>&1; then
                        print_success "   Eliminado: $container"
                        cleaned_items+=("contenedor huérfano: $container")
                    else
                        print_warning "   ⚠️  No se pudo eliminar: $container"
                        failed_items+=("contenedor huérfano: $container")
                    fi
                fi
            done <<< "$created_containers"
        fi
    fi
    
    # Limpiar contenedores del proyecto (si clean_type es "all" o "containers")
    # NOTA: "default" NO limpia contenedores del proyecto, solo huérfanos
    if [ "$clean_type" = "all" ] || [ "$clean_type" = "containers" ]; then
        # Buscar contenedores a eliminar
        local stopped_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
        local created_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=created" --format "{{.Names}}" 2>/dev/null)
        
        if [ -n "$stopped_containers" ] || [ -n "$created_containers" ]; then
            found_any=1
            print_warning "LIMPIEZA DE CONTENEDORES - OPERACIÓN DESTRUCTIVA"
            print_info "Contenedores que se eliminarán:"
            
            if [ -n "$stopped_containers" ]; then
                print_info "📦 Contenedores detenidos:"
                while IFS= read -r container; do
                    if [ -n "$container" ]; then
                        echo "   - $container"
                    fi
                done <<< "$stopped_containers"
            fi
            
            if [ -n "$created_containers" ]; then
                print_info "📦 Contenedores creados (no iniciados):"
                while IFS= read -r container; do
                    if [ -n "$container" ]; then
                        echo "   - $container"
                    fi
                done <<< "$created_containers"
            fi
            
            echo ""
            # Solo pedir confirmación si NO es 'clean all' (ya se pidió antes)
            if [ "$clean_type" != "all" ]; then
                print_warning "ADVERTENCIA: Esto eliminará los contenedores del proyecto"
                echo ""
                read -p "¿Estás seguro de que quieres continuar? (escribe 'SI' para confirmar): " -r
                echo
                if [ "$REPLY" != "SI" ]; then
                    print_info "Operación cancelada"
                    return 0
                fi
            fi
            
            # PROTECCIÓN: Preguntar sobre imágenes antes de borrar
            local delete_images="n"
            if [ "$clean_type" = "all" ]; then
                 echo ""
                 print_warning "OPCIÓN DE LIMPIEZA DE IMÁGENES LOCALES"
                 print_info "   Borrar las imágenes liberará espacio, pero requerirá descargarlas nuevamente (varios GBs)."
                 read -p "¿Deseas borrar también las IMÁGENES locales? (s/N) " -n 1 -r
                 echo ""
                 if [[ "$REPLY" =~ ^[Ss]$ ]]; then
                     delete_images="s"
                 else
                     print_info "✅ Se conservarán las imágenes locales."
                 fi
            fi

            # PROTECCIÓN: Preguntar sobre modelos de Ollama antes de borrar
            local delete_models="n"
            if [ "$clean_type" = "all" ] || [ "$clean_type" = "storage" ]; then
                 echo ""
                 print_warning "OPCIÓN DE LIMPIEZA DE MODELOS OLLAMA"
                 print_info "   Borrar los modelos requerirá descargarlos nuevamente (varios GBs)."
                 read -p "¿Deseas borrar también los MODELOS LLM descargados? (s/N) " -n 1 -r
                 echo ""
                 if [[ "$REPLY" =~ ^[Ss]$ ]]; then
                     delete_models="s"
                 else
                     print_info "✅ Se conservarán los modelos LLM (ollama_storage)."
                 fi
            fi

            # Eliminar contenedores detenidos
            if [ -n "$stopped_containers" ]; then
                print_info "Eliminando contenedores detenidos..."
                while IFS= read -r container; do
                    if [ -n "$container" ]; then
                        if $DOCKER_CMD rm -f "$container" >/dev/null 2>&1; then
                            print_success "   Eliminado: $container"
                            cleaned_items+=("contenedor detenido: $container")
                        else
                            print_warning "   ⚠️  No se pudo eliminar: $container"
                            failed_items+=("contenedor detenido: $container")
                        fi
                    fi
                done <<< "$stopped_containers"
            fi
            
            # Eliminar contenedores creados
            if [ -n "$created_containers" ]; then
                print_info "Eliminando contenedores creados..."
                while IFS= read -r container; do
                    if [ -n "$container" ]; then
                        if $DOCKER_CMD rm -f "$container" >/dev/null 2>&1; then
                            print_success "   Eliminado: $container"
                            cleaned_items+=("contenedor creado: $container")
                        else
                            print_warning "   ⚠️  No se pudo eliminar: $container"
                            failed_items+=("contenedor creado: $container")
                        fi
                    fi
                done <<< "$created_containers"
            fi
        fi
    fi
    
    # NO limpiar redes huérfanas del sistema con 'docker network prune'
    # Esto eliminaría redes que el proyecto necesita
    # Solo limpiaremos redes específicas del proyecto que estén vacías (ver más abajo)
    
    # Limpiar redes (si clean_type es "all" o "networks" o "default")
    if [ "$clean_type" = "all" ] || [ "$clean_type" = "networks" ] || [ "$clean_type" = "default" ]; then
        # Verificar y limpiar redes específicas del proyecto que puedan estar corruptas o vacías
        local project_networks=("genai-network" "frontend-network" "backend-network" "security-network" "monitoring-network")
        local empty_networks=()
        for network in "${project_networks[@]}"; do
            if $DOCKER_CMD network inspect "$network" >/dev/null 2>&1; then
                # Verificar si la red tiene contenedores activos
                local containers_in_network=$($DOCKER_CMD network inspect "$network" --format '{{range .Containers}}{{.Name}}{{end}}' 2>/dev/null | tr -d '[:space:]')
                if [ -z "$containers_in_network" ]; then
                    empty_networks+=("$network")
                fi
            fi
        done
        
        if [ ${#empty_networks[@]} -gt 0 ]; then
            found_any=1
            
            # Solo pedir confirmación si NO es 'clean all' (ya se pidió antes)
            if [ "$clean_type" != "all" ]; then
                print_warning "LIMPIEZA DE REDES - OPERACIÓN DESTRUCTIVA"
                print_info "Redes del proyecto que se eliminarán:"
                for network in "${empty_networks[@]}"; do
                    echo "   - $network"
                done
                echo ""
                print_warning "ADVERTENCIA: Esto eliminará las redes del proyecto"
                echo ""
                read -p "¿Estás seguro de que quieres continuar? (escribe 'SI' para confirmar): " -r
                echo
                if [ "$REPLY" != "SI" ]; then
                    print_info "Operación cancelada"
                    return 0
                fi
            fi
            
            print_info "Eliminando redes..."
            for network in "${empty_networks[@]}"; do
                if $DOCKER_CMD network rm "$network" >/dev/null 2>&1; then
                    print_success "   Eliminada: $network"
                    cleaned_items+=("red del proyecto: $network")
                else
                    print_warning "   ⚠️  No se pudo eliminar: $network"
                    failed_items+=("red del proyecto: $network")
                fi
            done
        fi
    fi
    
    # Limpiar almacenamiento/volúmenes (si clean_type es "all" o "storage")
    if [ "$clean_type" = "all" ] || [ "$clean_type" = "storage" ]; then
        print_warning "LIMPIEZA DE ALMACENAMIENTO - ESTO ELIMINARÁ DATOS PERSISTENTES"
        print_info "Volúmenes del proyecto que se eliminarán:"
        local project_volumes=("n8n_storage" "postgres_storage" "qdrant_storage" "pgvector_data" "open_webui_storage" "n8n_data" "shared_data" "prometheus_data" "grafana_data" "alertmanager_data" "backup_data" "redis_data" "jenkins_data" "haproxy_data" "keycloak_data" "modsecurity_data" "cadvisor_data" "node_exporter_data" "postgres_exporter_data" "config_data" "ssl_certs_data" "logs_data" "grafana_provisioning_data" "prometheus_rules_data" "ollama_storage")
        
        # Obtener nombre del proyecto para prefijos (reutilizamos la lógica)
        local project_name=""
        if $DOCKER_CMD compose config >/dev/null 2>&1; then
             project_name=$($DOCKER_CMD compose config 2>/dev/null | grep -E "^name:" | head -1 | awk '{print $2}' || echo "")
        fi
        if [ -z "$project_name" ]; then
             project_name=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | sed 's/--/-/g')
        fi

        local existing_volumes=()
        for volume in "${project_volumes[@]}"; do
            # PROTECCiÓN: Omitir ollama_storage de la lista automática
            if [ "$volume" == "ollama_storage" ]; then
                continue
            fi
            
            local volume_with_prefix="${project_name}_${volume}"
            if $DOCKER_CMD volume inspect "$volume_with_prefix" >/dev/null 2>&1; then
                existing_volumes+=("$volume_with_prefix")
                echo "   - $volume_with_prefix"
            elif $DOCKER_CMD volume inspect "$volume" >/dev/null 2>&1; then
                existing_volumes+=("$volume")
                echo "   - $volume"
            fi
        done
        
        if [ ${#existing_volumes[@]} -gt 0 ]; then
            found_any=1
            
            # Solo pedir confirmación si NO es 'clean all' (ya se pidió antes)
            if [ "$clean_type" != "all" ]; then
                echo ""
                print_warning "ADVERTENCIA: Esto eliminará TODOS los datos persistentes del proyecto"
                print_warning "Esto incluye: bases de datos, configuraciones, logs, backups, etc."
                echo ""
                read -p "¿Estás seguro de que quieres continuar? (escribe 'SI' para confirmar): " -r
                echo
                if [ "$REPLY" != "SI" ]; then
                    print_info "Operación cancelada"
                    return 0
                fi
            fi
            
            print_info "Eliminando volúmenes..."
            for volume in "${existing_volumes[@]}"; do
                if $DOCKER_CMD volume rm "$volume" >/dev/null 2>&1; then
                    print_success "   Eliminado: $volume"
                    cleaned_items+=("volumen: $volume")
                else
                    print_warning "   ⚠️  No se pudo eliminar: $volume"
                    failed_items+=("volumen: $volume")
                fi
            done
        else
        fi
        
        # Eliminar modelos de Ollama (solo si se confirmó)
        if [ "$delete_models" = "s" ]; then
            print_info "🗑️  Eliminando volumen de modelos Ollama..."
            local volume="ollama_storage"
            local volume_with_prefix="${project_name}_${volume}"
            local target_volume=""
            
            if $DOCKER_CMD volume inspect "$volume_with_prefix" >/dev/null 2>&1; then
                target_volume="$volume_with_prefix"
            elif $DOCKER_CMD volume inspect "$volume" >/dev/null 2>&1; then
                target_volume="$volume"
            fi
            
            if [ -n "$target_volume" ]; then
                if $DOCKER_CMD volume rm "$target_volume" >/dev/null 2>&1; then
                    print_success "   Eliminado: $target_volume"
                    cleaned_items+=("volumen modelos: $target_volume")
                else
                    print_warning "   ⚠️  No se pudo eliminar: $target_volume"
                    failed_items+=("volumen modelos: $target_volume")
                fi
            fi
        fi
    fi
    
    # Limpiar imágenes (solo si clean_type es "all" Y el usuario confirmó)
    if [ "$clean_type" = "all" ] && [ "$delete_images" = "s" ]; then
        print_info "🖼️  Buscando imágenes del proyecto..."
        # Obtener imágenes usadas por los servicios del proyecto
        local project_images=()
        local compose_images=$($DOCKER_CMD compose config --images 2>/dev/null || echo "")
        
        if [ -n "$compose_images" ]; then
            while IFS= read -r image; do
                if [ -n "$image" ]; then
                    project_images+=("$image")
                fi
            done <<< "$compose_images"
        fi
        
        if [ ${#project_images[@]} -gt 0 ]; then
            found_any=1
            
            # Solo pedir confirmación si NO es 'clean all' (ya se pidió antes)
            if [ "$clean_type" != "all" ]; then
                print_info "Imágenes del proyecto encontradas:"
                for image in "${project_images[@]}"; do
                    echo "   - $image"
                done
                echo ""
                print_warning "ADVERTENCIA: Esto eliminará las imágenes del proyecto"
                print_warning "Tendrás que descargarlas nuevamente en el próximo start"
                echo ""
                read -p "¿Estás seguro de que quieres continuar? (escribe 'SI' para confirmar): " -r
                echo
                if [ "$REPLY" != "SI" ]; then
                    print_info "Operación cancelada"
                    return 0
                fi
            fi
            
            print_info "Eliminando imágenes..."
            for image in "${project_images[@]}"; do
                # Capturar error para análisis
                local rmi_output
                if rmi_output=$($DOCKER_CMD rmi "$image" 2>&1); then
                    print_success "   Eliminada: $image"
                    cleaned_items+=("imagen: $image")
                else
                    # Analizar si es error de uso (conflicto)
                    if echo "$rmi_output" | grep -qE "conflict|reference|used by"; then
                        print_info "   ℹ️  Omitida: $image (en uso por otro contenedor/proyecto)"
                        # No lo agregamos a failed_items porque es un comportamiento correcto/seguro
                    elif echo "$rmi_output" | grep -qE "No such image"; then
                         print_success "   Ya eliminada: $image"
                         # Considerarlo éxito (ya no está)
                    else
                        print_warning "   ⚠️  No se pudo eliminar: $image"
                        echo "      Error: $rmi_output"
                        failed_items+=("imagen: $image")
                    fi
                fi
            done
        else
            print_info "✅ No se encontraron imágenes del proyecto para eliminar"
        fi
    fi
    
    # Mostrar resumen final
    echo ""
    if [ $found_any -eq 0 ]; then
        print_info "✅ No se encontraron recursos huérfanos para limpiar"
    elif [ ${#cleaned_items[@]} -gt 0 ] && [ ${#failed_items[@]} -eq 0 ]; then
        print_success "Limpieza completada exitosamente"
        print_info "📋 Recursos limpiados (${#cleaned_items[@]}):"
        for item in "${cleaned_items[@]}"; do
            echo "   ✅ $item"
        done
    elif [ ${#cleaned_items[@]} -eq 0 ] && [ ${#failed_items[@]} -gt 0 ]; then
        print_warning "❌ No se pudo limpiar ningún recurso huérfano"
        print_warning "📋 Recursos que fallaron (${#failed_items[@]}):"
        for item in "${failed_items[@]}"; do
            echo "   ❌ $item"
        done
    else
        print_warning "Limpieza parcial: algunos recursos se limpiaron, otros fallaron"
        print_info "📋 Recursos limpiados exitosamente (${#cleaned_items[@]}):"
        for item in "${cleaned_items[@]}"; do
            echo "   ✅ $item"
        done
        echo ""
        print_warning "📋 Recursos que fallaron (${#failed_items[@]}):"
        for item in "${failed_items[@]}"; do
            echo "   ❌ $item"
        done
    fi
    
    # Mostrar recordatorio para reconfigurar Keycloak roles si se hizo clean all
    if [ "$clean_type" = "all" ] || [ "$clean_type" = "storage" ]; then
        echo ""
        print_header "⚠️  RECORDATORIO IMPORTANTE - KEYCLOAK ROLES"
        echo ""
        print_warning "🗑️  Has eliminado la base de datos de Keycloak"
        print_warning "📋 Los ROLES de Keycloak se han PERDIDO y deben reconfigurarse"
        echo ""
        print_info "Después de levantar los servicios de nuevo, ejecuta:"
        echo ""
        print_success "   ./scripts/keycloak-roles-manager.sh all"
        echo ""
        print_info "Este script reconfigurará:"
        echo "   • Grupos (super-admins, admins, users, viewers)"
        echo "   • Roles de Grafana (admin, editor, viewer)"
        echo "   • Roles de Open WebUI (admin, user)"
        echo "   • Roles de n8n (admin, user)"
        echo "   • Roles de Jenkins (admin, user)"
        echo ""
        print_info "⏱️  Tiempo estimado: ~30 segundos"
        echo ""
        print_info "📚 Más información: docs/KEYCLOAK_ROLES_SETUP.md"
        echo ""
    fi
}


# Función para verificar y corregir automáticamente problemas de base de datos de Keycloak
# Esta función se ejecuta automáticamente antes de levantar Keycloak
auto_fix_keycloak_db() {
    # Verificar que PostgreSQL está corriendo
    if ! $DOCKER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -qE "^postgres$|postgres"; then
        # PostgreSQL no está corriendo, no hay nada que verificar
        return 0
    fi
    
    # Cargar variables de entorno si existen
    if [ -f ".env" ]; then
        set -a
        source .env 2>/dev/null || true
        set +a
    fi
    
    local POSTGRES_USER=${POSTGRES_USER}
    local POSTGRES_DB=${POSTGRES_DB}
    local KEYCLOAK_DB_NAME=${KEYCLOAK_DB_NAME}
    
    # Verificar que la base de datos keycloak existe
    local DB_EXISTS=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT 1 FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME'" 2>/dev/null || echo "0")
    
    if [ "$DB_EXISTS" != "1" ]; then
        # Base de datos no existe aún, es normal si Keycloak no se ha iniciado nunca
        return 0
    fi
    
    # Verificar si Keycloak está realmente corriendo (no solo existe, sino que está "running")
    # IMPORTANTE: Verificar tanto "running" como "restarting" - si está "exited" o "stopped", NO está corriendo
    local KEYCLOAK_STATUS=$($DOCKER_CMD ps --format "{{.Status}}" --filter "name=keycloak" 2>/dev/null | head -1)
    local KEYCLOAK_RUNNING=0
    if echo "$KEYCLOAK_STATUS" | grep -qE "Up.*\(running\)|Up.*\(health"; then
        KEYCLOAK_RUNNING=1
    fi
    
    # Verificar si hay problemas (transacciones pendientes, locks, conexiones huérfanas)
    local fixes_applied=0
    local fix_messages=()
    
    # 1. Verificar y terminar transacciones pendientes (idle in transaction)
    local idle_tx=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND state IN ('idle in transaction', 'idle in transaction (aborted)') AND pid != pg_backend_pid();" 2>/dev/null || echo "0")
    
    if [ "$idle_tx" != "0" ]; then
        local terminated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
            "SELECT COUNT(*) FROM (SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND state IN ('idle in transaction', 'idle in transaction (aborted)') AND pid != pg_backend_pid()) t;" 2>/dev/null || echo "0")
        if [ "$terminated" != "0" ]; then
            fixes_applied=$((fixes_applied + terminated))
            fix_messages+=("Terminadas $terminated transacciones pendientes")
        fi
    fi
    
    # 2. Verificar conexiones huérfanas
    # IMPORTANTE: Si Keycloak NO está corriendo, terminar TODAS las conexiones (sin excepciones)
    # Si Keycloak SÍ está corriendo pero tiene problemas, ser más agresivo con conexiones antiguas o bloqueadas
    local orphaned_conns=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid();" 2>/dev/null || echo "0")
    
    if [ "$orphaned_conns" != "0" ]; then
        if [ "$KEYCLOAK_RUNNING" = "0" ]; then
            # Keycloak no está corriendo: terminar TODAS las conexiones sin excepciones
            # IMPORTANTE: Hacer múltiples intentos para asegurar que todas se terminen
            local attempts=0
            local max_attempts=3
            while [ $attempts -lt $max_attempts ]; do
                local terminated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
                    "SELECT COUNT(*) FROM (SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid()) t;" 2>/dev/null || echo "0")
                if [ "$terminated" != "0" ]; then
                    fixes_applied=$((fixes_applied + terminated))
                    fix_messages+=("Terminadas $terminated conexiones huérfanas (Keycloak no está corriendo)")
                    sleep 1
                fi
                attempts=$((attempts + 1))
                # Verificar si quedan conexiones
                local remaining=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
                    "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid();" 2>/dev/null || echo "0")
                if [ "$remaining" = "0" ]; then
                    break
                fi
            done
        else
            # Keycloak está corriendo: terminar conexiones problemáticas AGRESIVAMENTE
            # - Conexiones idle o en transacción
            # - Conexiones activas antiguas (>30 segundos) - probablemente bloqueando
            # - Conexiones esperando locks (wait_event_type = 'Lock') - INMEDIATAMENTE
            # - Cualquier conexión que pueda estar bloqueando
            local terminated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
                "SELECT COUNT(*) FROM (SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid() AND (state IN ('idle', 'idle in transaction', 'idle in transaction (aborted)') OR (state = 'active' AND query_start < now() - interval '30 seconds') OR wait_event_type = 'Lock' OR wait_event_type = 'LWLock')) t;" 2>/dev/null || echo "0")
            if [ "$terminated" != "0" ]; then
                fixes_applied=$((fixes_applied + terminated))
                fix_messages+=("Terminadas $terminated conexiones problemáticas (idle, antiguas o esperando locks)")
            fi
        fi
    fi
    
    # 3. Verificar si la base de datos existe
    # NOTA: docker-compose tiene keycloak-db-init que crea la BD automáticamente
    # Este script solo verifica y limpia bloqueos, NO crea la BD (docker-compose lo hace)
    local db_exists=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT 1 FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME';" 2>/dev/null || echo "0")
    
    if [ "$db_exists" != "1" ]; then
        # Base de datos no existe - docker-compose (keycloak-db-init) la creará automáticamente
        # Solo informar, no crear aquí para evitar conflictos
        print_info "Base de datos '$KEYCLOAK_DB_NAME' no existe (keycloak-db-init la creará automáticamente)"
    else
        # Base de datos existe, verificar si está corrupta (solo advertir, no recrear)
        local db_corruption=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
            "SELECT 1;" 2>&1 | grep -q "MultiXactId.*wraparound" && echo "1" || echo "0")
        
        if [ "$db_corruption" = "1" ]; then
            # Base de datos corrupta - solo advertir, NO recrear automáticamente
            print_error "❌ ERROR: Base de datos corrupta (MultiXactId wraparound)"
            print_warning "⚠️  NO se puede reparar automáticamente (sería destructivo)"
            print_info "💡 Intenta reparar PostgreSQL primero:"
            echo "      docker compose restart postgres"
            echo "      docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'VACUUM FREEZE;'"
            echo ""
            print_warning "⚠️  Si la reparación falla, contacta al administrador"
        fi
    fi
    
    # 4. Verificar y limpiar locks en databasechangeloglock
    # Si Keycloak NO está corriendo, limpiar TODOS los locks (sin importar antigüedad)
    # Si Keycloak SÍ está corriendo, solo limpiar locks antiguos (más de 5 minutos)
    if [ "$KEYCLOAK_RUNNING" = "0" ]; then
        # Verificar que la base de datos existe y es accesible
        local db_accessible=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
            "SELECT 1;" 2>/dev/null | grep -q "^1$" && echo "1" || echo "0")
        
        if [ "$db_accessible" = "1" ]; then
            # Keycloak no está corriendo: limpiar TODOS los locks (sin importar si están locked o no)
            # IMPORTANTE: Limpiar TODOS los registros para asegurar un inicio limpio
            local hung_locks=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
                "SELECT COUNT(*) FROM databasechangeloglock WHERE locked = true;" 2>/dev/null || echo "0")
            
            # Limpiar TODOS los locks (incluso si no están marcados como locked)
            local updated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
                "UPDATE databasechangeloglock SET locked = false, lockgranted = NULL, lockedby = NULL; SELECT COUNT(*) FROM databasechangeloglock WHERE locked = false;" 2>/dev/null || echo "0")
            if [ "$updated" != "0" ] || [ "$hung_locks" != "0" ]; then
                fixes_applied=$((fixes_applied + 1))
                fix_messages+=("Limpiados todos los locks en databasechangeloglock (Keycloak no estaba corriendo)")
            fi
        fi
    else
        # Keycloak está corriendo: limpiar locks antiguos (más de 1 minuto) - MÁS AGRESIVO
        local old_locks=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
            "SELECT COUNT(*) FROM pg_stat_activity a JOIN pg_locks l ON a.pid = l.pid WHERE a.datname = '$KEYCLOAK_DB_NAME' AND a.pid != pg_backend_pid() AND l.relation::regclass::text = 'databasechangeloglock' AND a.query_start < now() - interval '1 minute';" 2>/dev/null || echo "0")
        
        if [ "$old_locks" != "0" ]; then
            local terminated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
                "SELECT COUNT(*) FROM (SELECT pg_terminate_backend(a.pid) FROM pg_stat_activity a JOIN pg_locks l ON a.pid = l.pid WHERE a.datname = '$KEYCLOAK_DB_NAME' AND a.pid != pg_backend_pid() AND l.relation::regclass::text = 'databasechangeloglock' AND a.query_start < now() - interval '1 minute') t;" 2>/dev/null || echo "0")
            if [ "$terminated" != "0" ]; then
                fixes_applied=$((fixes_applied + terminated))
                fix_messages+=("Terminadas $terminated conexiones con locks antiguos (>1 min)")
            fi
        fi
        
        # También limpiar locks colgados en la tabla (más de 1 minuto) - MÁS AGRESIVO
        local hung_locks=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
            "SELECT COUNT(*) FROM databasechangeloglock WHERE locked = true AND (lockgranted IS NULL OR lockgranted < now() - interval '1 minute');" 2>/dev/null || echo "0")
        
        if [ "$hung_locks" != "0" ]; then
            local updated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
                "UPDATE databasechangeloglock SET locked = false, lockgranted = NULL, lockedby = NULL WHERE locked = true AND (lockgranted IS NULL OR lockgranted < now() - interval '1 minute'); SELECT COUNT(*) FROM databasechangeloglock WHERE locked = false AND (lockgranted IS NULL OR lockgranted < now() - interval '1 minute');" 2>/dev/null || echo "0")
            if [ "$updated" != "0" ]; then
                fixes_applied=$((fixes_applied + 1))
                fix_messages+=("Limpiados locks antiguos en databasechangeloglock (>1 min)")
            fi
        fi
    fi
    
    # Informar qué se corrigió
    if [ $fixes_applied -gt 0 ]; then
        print_info "🔧 Verificando base de datos de Keycloak..."
        print_success "✅ Base de datos de Keycloak corregida automáticamente:"
        for msg in "${fix_messages[@]}"; do
            echo "   • $msg"
        done
        echo ""
    fi
    
    return 0
}

# Función para esperar a que Keycloak esté listo
wait_for_keycloak_ready() {
    local max_wait=${1:-180}  # Tiempo máximo de espera en segundos (default: 3 minutos)
    local wait_interval=5     # Intervalo entre verificaciones en segundos
    local elapsed=0
    
    print_info "⏳ Esperando a que Keycloak esté listo..."
    
    while [ $elapsed -lt $max_wait ]; do
        # Verificar si Keycloak está corriendo y healthy
        local keycloak_status=$($DOCKER_CMD ps --filter "name=keycloak" --format "{{.Status}}" 2>/dev/null | head -1)
        
        if echo "$keycloak_status" | grep -qE "Up.*\(healthy\)"; then
            # Verificar que el endpoint de health responda
            if curl -s -f http://localhost:8080/health/ready > /dev/null 2>&1; then
                print_success "✅ Keycloak está listo"
                return 0
            fi
        fi
        
        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
        
        # Mostrar progreso cada 30 segundos
        if [ $((elapsed % 30)) -eq 0 ]; then
            print_info "   Esperando... (${elapsed}s/${max_wait}s)"
        fi
    done
    
    print_warning "⚠️ Keycloak no está listo después de ${max_wait}s"
    return 1
}

# Función para crear clientes de Keycloak automáticamente usando el script existente
auto_create_keycloak_clients() {
    # Verificar que Keycloak está corriendo
    if ! $DOCKER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -qE "^keycloak$"; then
        return 0  # Keycloak no está corriendo, no hay nada que hacer
    fi
    
    # Esperar a que Keycloak esté listo
    if ! wait_for_keycloak_ready 120; then
        print_warning "⚠️ No se pueden crear clientes: Keycloak no está listo"
        return 1
    fi
    
    # Usar el script existente en lugar de duplicar código
    if [ -f "${SCRIPT_DIR}/recreate-keycloak-clients.sh" ]; then
        print_info "🔧 Creando clientes OIDC de Keycloak automáticamente..."
        # Ejecutar el script existente de forma silenciosa (solo errores)
        bash "${SCRIPT_DIR}/recreate-keycloak-clients.sh" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_success "✅ Clientes OIDC creados automáticamente"
        else
            print_warning "⚠️ Algunos clientes pueden no haberse creado. Revisa los logs si es necesario."
        fi
    else
        print_warning "⚠️ Script recreate-keycloak-clients.sh no encontrado"
        return 1
    fi
    
    return 0
}

# Función para limpiar base de datos de Keycloak antes de detener servicios
# Se ejecuta automáticamente al detener servicios con perfil security
cleanup_keycloak_db_before_stop() {
    # Verificar que PostgreSQL está corriendo
    if ! $DOCKER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -qE "^postgres$|postgres"; then
        return 0
    fi
    
    # Cargar variables de entorno si existen
    if [ -f ".env" ]; then
        set -a
        source .env 2>/dev/null || true
        set +a
    fi
    
    local POSTGRES_USER=${POSTGRES_USER}
    local POSTGRES_DB=${POSTGRES_DB}
    local KEYCLOAK_DB_NAME=${KEYCLOAK_DB_NAME}
    
    # Verificar que la base de datos keycloak existe
    local DB_EXISTS=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT 1 FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME'" 2>/dev/null || echo "0")
    
    if [ "$DB_EXISTS" != "1" ]; then
        return 0
    fi
    
    # Esperar un momento para que Keycloak termine de cerrar conexiones
    sleep 2
    
    # Terminar todas las conexiones a la base de datos keycloak (excepto la actual)
    local terminated=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT COUNT(*) FROM (SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid()) t;" 2>/dev/null || echo "0")
    
    # Limpiar todos los locks en databasechangeloglock
    $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
        "UPDATE databasechangeloglock SET locked = false, lockgranted = NULL, lockedby = NULL WHERE locked = true;" 2>/dev/null || true
    
    if [ "$terminated" != "0" ]; then
        print_info "🔧 Limpiadas $terminated conexiones de Keycloak antes de detener servicios"
    fi
    
    return 0
}

# Función para diagnóstico detallado de base de datos de Keycloak
# Similar a auto_fix_keycloak_db pero con salida detallada y opción de limpiar manualmente
diagnose_keycloak_db() {
    # Verificar que PostgreSQL está corriendo
    if ! $DOCKER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -qE "^postgres$|postgres"; then
        print_error "PostgreSQL NO está corriendo"
        echo "   Levántalo con: docker compose up -d postgres"
        return 1
    fi
    
    # Cargar variables de entorno si existen
    if [ -f ".env" ]; then
        set -a
        source .env 2>/dev/null || true
        set +a
    fi
    
    local POSTGRES_USER=${POSTGRES_USER}
    local POSTGRES_DB=${POSTGRES_DB}
    local KEYCLOAK_DB_NAME=${KEYCLOAK_DB_NAME}
    
    print_header "DIAGNÓSTICO DE BASE DE DATOS DE KEYCLOAK"
    
    # Verificar que la base de datos keycloak existe
    local DB_EXISTS=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT 1 FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME'" 2>/dev/null || echo "0")
    
    if [ "$DB_EXISTS" != "1" ]; then
        print_warning "La base de datos '$KEYCLOAK_DB_NAME' no existe"
        echo "   Esto es normal si Keycloak no se ha iniciado nunca"
        echo "   La base de datos se creará automáticamente cuando Keycloak inicie"
        return 0
    fi
    
    print_success "Base de datos '$KEYCLOAK_DB_NAME' existe"
    echo ""
    
    # Mostrar conexiones activas
    print_info "📊 Conexiones activas:"
    $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -c "
        SELECT 
            pid,
            usename,
            application_name,
            state,
            query_start,
            age(now(), query_start) AS connection_age
        FROM pg_stat_activity
        WHERE datname = '$KEYCLOAK_DB_NAME'
        AND pid != pg_backend_pid()
        ORDER BY query_start;
    " 2>/dev/null || print_warning "No se pudo verificar conexiones"
    echo ""
    
    # Mostrar transacciones pendientes
    print_info "📊 Transacciones pendientes:"
    $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -c "
        SELECT 
            pid,
            usename,
            application_name,
            state,
            xact_start,
            now() - xact_start AS transaction_duration
        FROM pg_stat_activity
        WHERE datname = '$KEYCLOAK_DB_NAME'
        AND state IN ('idle in transaction', 'idle in transaction (aborted)')
        AND pid != pg_backend_pid()
        ORDER BY xact_start;
    " 2>/dev/null || print_warning "No se pudo verificar transacciones"
    echo ""
    
    # Mostrar locks
    print_info "📊 Locks:"
    $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -c "
        SELECT 
            l.locktype,
            l.relation::regclass,
            l.mode,
            l.granted,
            a.usename,
            a.query_start,
            age(now(), a.query_start) AS age
        FROM pg_locks l
        LEFT JOIN pg_stat_activity a ON l.pid = a.pid
        WHERE l.database = (SELECT oid FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME')
        AND a.pid != pg_backend_pid()
        ORDER BY a.query_start;
    " 2>/dev/null || print_warning "No se pudo verificar locks"
    echo ""
    
    # Verificar si hay problemas
    local idle_tx=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND state IN ('idle in transaction', 'idle in transaction (aborted)') AND pid != pg_backend_pid();" 2>/dev/null || echo "0")
    
    local old_locks=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
        "SELECT COUNT(*) FROM pg_stat_activity a JOIN pg_locks l ON a.pid = l.pid WHERE a.datname = '$KEYCLOAK_DB_NAME' AND a.pid != pg_backend_pid() AND l.relation::regclass::text = 'databasechangeloglock' AND a.query_start < now() - interval '5 minutes';" 2>/dev/null || echo "0")
    
    local hung_locks=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -tAc \
        "SELECT COUNT(*) FROM databasechangeloglock WHERE locked = true AND (lockgranted IS NULL OR lockgranted < now() - interval '5 minutes');" 2>/dev/null || echo "0")
    
    if [ "$idle_tx" = "0" ] && [ "$old_locks" = "0" ] && [ "$hung_locks" = "0" ]; then
        print_success "✅ No se detectaron problemas"
        return 0
    fi
    
    # Hay problemas
    print_warning "⚠️ Se detectaron problemas:"
    [ "$idle_tx" != "0" ] && echo "   • $idle_tx transacciones pendientes"
    [ "$old_locks" != "0" ] && echo "   • $old_locks locks antiguos"
    [ "$hung_locks" != "0" ] && echo "   • $hung_locks locks colgados en databasechangeloglock"
    echo ""
    
    # Preguntar si quiere limpiar
    read -p "¿Deseas limpiar automáticamente? (s/n) " -n 1 -r
    echo ""
    
    if [[ "$REPLY" =~ ^[Ss]$ ]]; then
        # Usar la función automática de corrección
        auto_fix_keycloak_db
        print_success "✅ Limpieza completada"
        echo ""
        print_info "Ahora puedes intentar levantar Keycloak:"
        echo "   ./scripts/stack-manager.sh start security"
    else
        print_info "Operación cancelada"
        echo ""
        print_info "Puedes limpiar automáticamente ejecutando:"
        echo "   ./scripts/stack-manager.sh start security"
        echo ""
        print_info "O manualmente con:"
        echo "   ./scripts/keycloak-manager.sh fix-db"
    fi
    
    return 0
}

# Función para analizar estado de servicios antes de levantar
analyze_services_before_start() {
    local profiles=("$@")
    local cmd="$DOCKER_CMD compose"
    
    # Agregar perfiles al comando
    for profile in "${profiles[@]}"; do
        cmd="$cmd --profile $profile"
    done
    
    local running_healthy=0
    local running_unhealthy=0
    local stopped=0
    local unhealthy_services=()
    
    # Obtener estado de servicios (sin jq, usando formato de tabla)
    local services_info=$($cmd ps --format "{{.Name}}|{{.State}}|{{.Health}}" 2>/dev/null || echo "")
    
    if [ -z "$services_info" ]; then
        print_info "No hay servicios corriendo con estos perfiles"
        return 0
    fi
    
    # Usar process substitution para evitar subshell
    while IFS='|' read -r name state health; do
        if [ -z "$name" ] || [ "$name" = "NAME" ]; then
            continue
        fi
        
        # Normalizar health (puede estar vacío o tener espacios)
        health=$(echo "$health" | xargs)
        if [ -z "$health" ]; then
            health="none"
        fi
        
        case "$state" in
            running|Up*)
                if [ "$health" = "healthy" ]; then
                    running_healthy=$((running_healthy + 1))
                    print_info "✅ $name: Ya está corriendo y healthy"
                elif [ "$health" = "unhealthy" ]; then
                    running_unhealthy=$((running_unhealthy + 1))
                    unhealthy_services+=("$name")
                    print_warning "⚠️  $name: Está corriendo pero UNHEALTHY"
                elif echo "$health" | grep -q "starting"; then
                    print_info "⏳ $name: Está iniciando..."
                else
                    running_healthy=$((running_healthy + 1))
                    print_info "ℹ️  $name: Ya está corriendo (sin healthcheck o estado: $health)"
                fi
                ;;
            *)
                stopped=$((stopped + 1))
                ;;
        esac
    done < <(echo "$services_info")
    
    # Si hay servicios unhealthy, mostrar advertencia
    if [ ${#unhealthy_services[@]} -gt 0 ]; then
        echo ""
        print_warning "Servicios unhealthy detectados:"
        for service in "${unhealthy_services[@]}"; do
            echo "  - $service"
        done
        echo ""
        print_info "Puedes revisar los logs con: ./scripts/stack-manager.sh logs <servicio>"
        echo ""
        return 1  # Hay servicios unhealthy
    fi
    
    return 0  # Todo OK
}

# Función para levantar servicios
start_services() {
    local profiles=()
    local auto_setup_roles=false
    
    # Parsear argumentos para detectar --setup-roles
    for arg in "$@"; do
        if [ "$arg" = "--setup-roles" ]; then
            auto_setup_roles=true
        else
            profiles+=("$arg")
        fi
    done
    
    # Si no hay perfiles, usar preset default
    if [ ${#profiles[@]} -eq 0 ]; then
        print_header "USANDO PRESET 'default'"
        print_info "No se especificaron perfiles, usando preset 'default'"
        local preset_profiles=$(expand_preset default)
        read -ra profiles <<< "$preset_profiles"
        echo ""
        print_info "📋 Perfiles que se van a levantar:"
        for profile in "${profiles[@]}"; do
            echo "   ✅ $profile"
        done
        echo ""
        print_info "📦 Servicios incluidos en este preset:"
        print_info "   • GPU: Ollama con NVIDIA"
        print_info "   • Monitoring: Prometheus, Grafana, AlertManager, exporters"
        print_info "   • Infrastructure: Redis, HAProxy"
        print_info "   • Security: Keycloak, ModSecurity"
        print_info "   • Automation: n8n, Watchtower, Sync"
        print_info "   • Chat-AI: Open WebUI"
        echo ""
    fi
    
    # Expandir presets si alguno es un preset
    local expanded_profiles=()
    local preset_used=""
    for profile in "${profiles[@]}"; do
        local expanded=$(expand_preset "$profile")
        if [ "$expanded" != "$profile" ]; then
            # Es un preset, expandirlo
            preset_used="$profile"
            read -ra preset_array <<< "$expanded"
            expanded_profiles+=("${preset_array[@]}")
        else
            # No es preset, agregarlo tal cual
            expanded_profiles+=("$profile")
        fi
    done
    
    # Eliminar duplicados
    local unique_profiles=($(printf '%s\n' "${expanded_profiles[@]}" | sort -u))
    
    print_header "LEVANTANDO SERVICIOS"
    if [ -n "$preset_used" ]; then
        print_info "Preset usado: '$preset_used'"
    fi
    print_info "Perfiles activos: ${unique_profiles[*]}"
    echo ""
    
    # Limpiar automáticamente contenedores en estado "Created" (problemáticos)
    # Estos contenedores pueden tener referencias a redes corruptas y causan errores
    # NOTA: NO limpiamos contenedores "exited" - esos son del proyecto y se reutilizan
    echo ""
    cleanup_created_containers
    
    # Verificar estado de servicios antes de levantar
    echo ""
    print_info "Verificando estado de servicios existentes..."
    if ! analyze_services_before_start "${unique_profiles[@]}"; then
        echo ""
        read -p "¿Continuar levantando servicios? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            print_info "Operación cancelada"
            exit 0
        fi
    fi
    
    # Validar antes de levantar
    if ! validate_before_start; then
        print_error "Validación falló. Corrige los errores antes de continuar."
        exit 1
    fi
    
    # Verificar y corregir base de datos de Keycloak automáticamente
    # IMPORTANTE: Siempre verificar si hay conexiones huérfanas, incluso si no se levanta security
    # porque pueden bloquear futuros inicios. Si se levanta security, limpieza completa.
    if [[ " ${unique_profiles[@]} " =~ " security " ]]; then
        # Se va a levantar security: limpieza COMPLETA Y AGRESIVA
        # IMPORTANTE: Detener Keycloak primero para asegurar limpieza completa
        print_info "🔧 Preparando base de datos de Keycloak (limpieza completa)..."
        if $DOCKER_CMD ps --format "{{.Names}}" --filter "name=keycloak" 2>/dev/null | grep -qE "^keycloak$"; then
            print_info "Deteniendo Keycloak para limpieza completa de base de datos..."
            $DOCKER_CMD compose stop keycloak 2>&1 | grep -v "^$" || true
            sleep 3
        fi
        
        # Limpieza completa y agresiva
        auto_fix_keycloak_db
        
        # Limpiar locks también (por si acaso) - hacerlo múltiples veces para asegurar
        if [ -f ".env" ]; then
            set -a
            source .env 2>/dev/null || true
            set +a
        fi
        local POSTGRES_USER=${POSTGRES_USER}
        local KEYCLOAK_DB_NAME=${KEYCLOAK_DB_NAME}
        
        # Limpiar locks múltiples veces para asegurar
        for i in 1 2 3; do
            $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -c "UPDATE databasechangeloglock SET locked = false, lockgranted = NULL, lockedby = NULL;" 2>/dev/null || true
            sleep 1
        done
        
        # Verificar que no queden conexiones
        local remaining_conns=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
            "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid();" 2>/dev/null || echo "0")
        if [ "$remaining_conns" != "0" ]; then
            print_warning "⚠️ Aún quedan $remaining_conns conexiones, terminándolas..."
            $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid();" 2>/dev/null || true
            sleep 2
        fi
        
        print_success "✅ Base de datos de Keycloak lista para iniciar"
    else
        # No se va a levantar security, pero verificar conexiones huérfanas preventivamente
        # (pueden ser de intentos anteriores que bloqueen futuros inicios)
        if $DOCKER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -qE "^postgres$|postgres"; then
            local POSTGRES_USER=${POSTGRES_USER}
            local POSTGRES_DB=${POSTGRES_DB}
            local KEYCLOAK_DB_NAME=${KEYCLOAK_DB_NAME}
            
            # Solo verificar si hay conexiones huérfanas antiguas (>5 minutos)
            local orphaned_conns=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
                "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid() AND query_start < now() - interval '5 minutes';" 2>/dev/null || echo "0")
            
            if [ "$orphaned_conns" != "0" ]; then
                print_info "🔧 Detectadas conexiones huérfanas de Keycloak (aunque no se levanta security), limpiando preventivamente..."
                auto_fix_keycloak_db
            fi
        fi
    fi
    
    # Construir y ejecutar comando
    local cmd=$(build_compose_command up "${unique_profiles[@]}")
    print_info "Ejecutando: $cmd"
    
    # Después de levantar, verificar si Keycloak tiene problemas (si se levantó security)
    # IMPORTANTE: Keycloak puede estar "healthy" pero fallando con lock timeout
    # También verificar si hay conexiones huérfanas que puedan causar problemas futuros
    if [[ " ${unique_profiles[@]} " =~ " security " ]]; then
        # Cargar variables de entorno si no están definidas (ANTES de usarlas)
        if [ -f ".env" ]; then
            set -a
            source .env 2>/dev/null || true
            set +a
        fi
        
        local POSTGRES_USER=${POSTGRES_USER}
        local POSTGRES_DB=${POSTGRES_DB}
        local KEYCLOAK_DB_NAME=${KEYCLOAK_DB_NAME}
        
        # Esperar 3 segundos para que Keycloak intente iniciar
        sleep 3
        
        # Verificar si Keycloak está realmente corriendo (no solo existe)
        local keycloak_status=$($DOCKER_CMD ps --filter "name=keycloak" --format "{{.Status}}" 2>/dev/null | head -1)
        local keycloak_is_running=0
        if echo "$keycloak_status" | grep -qE "Up.*\(running\)|Up.*\(health"; then
            keycloak_is_running=1
        fi
        
        # Solo verificar bloqueos si Keycloak NO está corriendo o tiene problemas
        if [ "$keycloak_is_running" = "0" ] || echo "$keycloak_status" | grep -qE "Exited|Restarting|unhealthy"; then
            # Verificar si hay conexiones bloqueando (solo conexiones MUY antiguas o esperando locks)
            # IMPORTANTE: No terminar conexiones nuevas de Keycloak que está iniciando normalmente
            local blocking_conns=$($DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
                "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$KEYCLOAK_DB_NAME' AND pid != pg_backend_pid() AND (wait_event_type = 'Lock' OR wait_event_type = 'LWLock' OR (state = 'active' AND query_start < now() - interval '2 minutes'));" 2>/dev/null || echo "0")
            
            # Verificar logs de errores
            local keycloak_logs=$($DOCKER_CMD compose logs --tail=30 keycloak 2>&1 | grep -E "lock timeout|Failed to retrieve lock|This connection has been closed|canceling statement due to lock timeout|ERROR.*lock" | head -1)
            
            if [ "$blocking_conns" != "0" ] || [ -n "$keycloak_logs" ] || echo "$keycloak_status" | grep -qE "Exited|Restarting"; then
                print_warning "⚠️ Keycloak tiene problemas (lock timeout o conexiones bloqueando detectadas), limpiando y reiniciando..."
                # Detener Keycloak primero (si está corriendo)
                if [ "$keycloak_is_running" = "1" ]; then
                    $DOCKER_CMD compose stop keycloak 2>&1 | grep -v "^$" || true
                    sleep 1
                fi
                # Limpiar agresivamente: terminar TODAS las conexiones y limpiar locks
                auto_fix_keycloak_db
                # Limpiar locks también
                $DOCKER_CMD exec postgres psql -U "$POSTGRES_USER" -d "$KEYCLOAK_DB_NAME" -c "UPDATE databasechangeloglock SET locked = false, lockgranted = NULL, lockedby = NULL WHERE locked = true;" 2>/dev/null || true
                
                print_info "Reiniciando Keycloak..."
                $DOCKER_CMD compose up -d keycloak 2>&1 | grep -v "^$" || true
            fi
        fi
    fi
    
    # Capturar salida del comando para análisis de errores
    local compose_output
    compose_output=$(eval "$cmd" 2>&1)
    local compose_exit_code=$?
    
    if [ $compose_exit_code -eq 0 ]; then
        print_success "Servicios levantados correctamente"
        
        # Esperar un poco y mostrar estado
        sleep 3
        print_info "Estado de servicios:"
        $DOCKER_CMD compose ps
        
        # Si hay perfil monitoring, informar URLs
        if [[ " ${unique_profiles[@]} " =~ " monitoring " ]]; then
            echo ""
            print_info "Servicios de monitoreo disponibles:"
            echo "  - Grafana: http://localhost:3001"
            echo "  - Prometheus: http://localhost:9090"
            echo "  - AlertManager: http://localhost:9093"
        fi
        
        # Si hay perfil security, informar URLs
        # NOTA: docker-compose tiene keycloak-init que crea los clientes automáticamente
        # Este script solo informa, NO crea clientes (docker-compose lo hace)
        if [[ " ${unique_profiles[@]} " =~ " security " ]]; then
            echo ""
            print_info "Servicios de seguridad disponibles:"
            echo "  - Keycloak: http://localhost:8080"
            echo ""
            print_info "ℹ️  Los clientes OIDC se crean automáticamente por keycloak-init en docker-compose"
        fi
        
        return 0
    else
        print_error "Error al levantar servicios"
        echo ""
        
        # Detectar errores específicos y proporcionar información detallada
        if echo "$compose_output" | grep -q "failed to set up container networking.*network.*not found"; then
            print_warning "⚠️  ERROR DETECTADO: Contenedores con referencias a redes inexistentes"
            echo ""
            print_info "📋 Contenedores problemáticos detectados:"
            
            # Buscar contenedores en estado "Created" que pueden tener referencias corruptas
            local project_dir=$(pwd)
            local problematic_containers=$($DOCKER_CMD ps -a --filter "label=com.docker.compose.project.working_dir=$project_dir" --filter "status=created" --format "{{.Names}}" 2>/dev/null)
            
            if [ -n "$problematic_containers" ]; then
                echo "$problematic_containers" | while read container; do
                    if [ -n "$container" ]; then
                        print_warning "   ❌ $container (estado: Created - tiene referencias a redes inexistentes)"
                    fi
                done
                echo ""
                print_info "🔧 ACCIÓN: Limpiando contenedores problemáticos..."
                cleanup_created_containers
                echo ""
                print_info "🔄 Reintentando levantar servicios..."
                if eval "$cmd" 2>&1; then
                    print_success "✅ Servicios levantados correctamente después de limpiar contenedores problemáticos"
                    return 0
                else
                    print_error "❌ Error persistente después de limpiar. Revisa los logs."
                    return 1
                fi
            else
                print_warning "   No se encontraron contenedores en estado 'Created'"
                print_info "   El error puede deberse a redes huérfanas del sistema"
                echo ""
                print_info "💡 SUGERENCIA: Ejecuta 'docker network prune' manualmente si es necesario"
            fi
        else
            # Otro tipo de error - mostrar salida completa
            print_error "Detalles del error:"
            echo "$compose_output" | tail -20
        fi
        
        return 1
    fi
    
    # Mostrar recordatorio o ejecutar automáticamente configuración de roles de Keycloak
    if [[ " ${unique_profiles[@]} " =~ " security " ]]; then
        echo ""
        
        if [ "$auto_setup_roles" = "true" ]; then
            # Ejecutar automáticamente el script de configuración
            print_header "🔧 CONFIGURANDO ROLES DE KEYCLOAK AUTOMÁTICAMENTE"
            echo ""
            print_info "Flag --setup-roles detectado, configurando roles automáticamente..."
            echo ""
            
            # Esperar a que Keycloak esté completamente listo
            print_info "Esperando a que Keycloak esté listo..."
            local max_wait=60
            local waited=0
            while [ $waited -lt $max_wait ]; do
                if curl -s http://localhost:8080/health/ready > /dev/null 2>&1; then
                    print_success "✓ Keycloak está listo"
                    break
                fi
                sleep 2
                waited=$((waited + 2))
                echo -n "."
            done
            echo ""
            
            if [ $waited -ge $max_wait ]; then
                print_warning "⚠️  Keycloak tardó demasiado en estar listo"
                print_info "Puedes ejecutar manualmente: ./scripts/auth-manager.sh --setup-roles"
            else
                # Ejecutar script de configuración
                echo ""
                if "$SCRIPT_DIR/auth-manager.sh" --setup-roles; then
                    print_success "✅ Roles de Keycloak configurados exitosamente"
                else
                    print_warning "⚠️  Hubo un problema configurando los roles"
                    print_info "Puedes ejecutar manualmente: ./scripts/auth-manager.sh --setup-roles"
                fi
            fi
            echo ""
        else
            # Mostrar recordatorio (comportamiento por defecto)
            print_header "⚠️  RECORDATORIO IMPORTANTE - KEYCLOAK ROLES"
            echo ""
            print_warning "📋 Keycloak se ha levantado, pero los ROLES aún NO están configurados"
            echo ""
            print_info "Los roles de Keycloak NO se configuran automáticamente por seguridad."
            print_info "Debes ejecutar el script de configuración manualmente:"
            echo ""
            print_success "   ./scripts/auth-manager.sh --setup-roles"
            echo ""
            print_info "O puedes usar el flag --setup-roles para configuración automática:"
            echo ""
            print_success "   ./scripts/stack-manager.sh start --setup-roles"
            echo ""
            print_info "Este script configura:"
            echo "   • Grupos (super-admins, admins, users, viewers)"
            echo "   • Roles de Grafana (admin, editor, viewer)"
            echo "   • Roles de Open WebUI (admin, user)"
            echo "   • Roles de n8n (admin, user)"
            echo "   • Roles de Jenkins (admin, user)"
            echo ""
            print_info "⏱️  Tiempo estimado: ~30 segundos"
            print_info "🔒 Seguro: Detecta roles existentes y los omite"
            echo ""
            print_warning "⚠️  Si ya ejecutaste este script antes, NO necesitas ejecutarlo de nuevo"
            print_info "   (Los roles persisten en la base de datos)"
            echo ""
            print_info "📚 Más información: docs/KEYCLOAK_ROLES_SETUP.md"
            echo ""
        fi
    fi
}


# Función para limpiar base de datos de Keycloak antes de detener (opcional)
# Esto ayuda a prevenir problemas cuando se reinicie

# Función para detener servicios
stop_services() {
    local profiles=()
    local clean_mode=false
    
    # Procesar argumentos
    for arg in "$@"; do
        if [ "$arg" = "--clean" ]; then
            clean_mode=true
        else
            profiles+=("$arg")
        fi
    done
    
    print_header "DETENIENDO SERVICIOS"
    
    # Limpiar base de datos de Keycloak antes de detener
    # IMPORTANTE: Siempre limpiar, incluso si no se detiene security explícitamente
    # porque puede haber conexiones huérfanas de intentos anteriores
    # Si se detiene TODO (sin perfiles), también limpiar porque puede incluir security
    cleanup_keycloak_db_before_stop
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_info "Deteniendo todos los servicios (incluyendo todos los perfiles)..."
        # Detener todos los contenedores del proyecto directamente usando el directorio de trabajo
        local project_dir=$(pwd)
        print_info "Deteniendo contenedores del proyecto en: $project_dir"
        
        # Obtener todos los contenedores del proyecto usando el label del directorio de trabajo
        local containers=$($DOCKER_CMD ps --filter "label=com.docker.compose.project.working_dir=$project_dir" --format "{{.Names}}" 2>/dev/null)
        
        if [ -n "$containers" ]; then
            echo "$containers" | while read container; do
                if [ -n "$container" ]; then
                    print_info "Deteniendo: $container"
                    $DOCKER_CMD stop "$container" 2>/dev/null || true
                fi
            done
        fi
        
        # IMPORTANTE: NO usar 'docker compose down' porque elimina las redes del proyecto
        # NO usar 'docker network prune' porque elimina redes que el proyecto necesita
        # Solo detenemos contenedores manualmente para conservar redes y volúmenes
        print_info "✅ Contenedores detenidos (redes y volúmenes conservados)"
    else
        local expanded_profiles=()
        for profile in "${profiles[@]}"; do
            local expanded=$(expand_preset "$profile")
            if [ "$expanded" != "$profile" ]; then
                read -ra preset_array <<< "$expanded"
                expanded_profiles+=("${preset_array[@]}")
            else
                expanded_profiles+=("$profile")
            fi
        done
        
        local unique_profiles=($(printf '%s\n' "${expanded_profiles[@]}" | sort -u))
        print_info "Deteniendo perfiles: ${unique_profiles[*]}"
        
        # IMPORTANTE: NO usar 'docker compose down' porque elimina las redes del proyecto
        # Solo detenemos contenedores de los perfiles especificados
        print_info "Deteniendo contenedores de perfiles: ${unique_profiles[*]}"
        local cmd=$(build_compose_command stop "${unique_profiles[@]}")
        if eval "$cmd" 2>&1; then
            print_success "✅ Contenedores detenidos (redes y volúmenes conservados)"
        else
            print_warning "⚠️  Algunos contenedores no se pudieron detener"
        fi
        
        # IMPORTANTE: NO eliminar redes del proyecto en 'stop'
        # Las redes se conservan para el próximo 'start'
        # Solo se eliminan explícitamente con 'clean networks' o 'clean all'
        print_info "✅ Redes del proyecto conservadas (listas para el próximo start)"
    fi
    
    print_success "Servicios detenidos"
    
    # Generar reporte de recursos disponibles
    echo ""
    generate_stop_report
}

# Función para reiniciar servicios
restart_services() {
    local profiles=("$@")
    
    print_header "REINICIANDO SERVICIOS"
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_info "Reiniciando todos los servicios..."
        $DOCKER_CMD compose restart
    else
        local expanded_profiles=()
        for profile in "${profiles[@]}"; do
            local expanded=$(expand_preset "$profile")
            if [ "$expanded" != "$profile" ]; then
                read -ra preset_array <<< "$expanded"
                expanded_profiles+=("${preset_array[@]}")
            else
                expanded_profiles+=("$profile")
            fi
        done
        
        local unique_profiles=($(printf '%s\n' "${expanded_profiles[@]}" | sort -u))
        print_info "Reiniciando perfiles: ${unique_profiles[*]}"
        
        local cmd=$(build_compose_command restart "${unique_profiles[@]}")
        eval "$cmd"
    fi
    
    print_success "Servicios reiniciados"
}

# Función para mostrar estado
show_status() {
    print_header "ESTADO DE SERVICIOS"
    $DOCKER_CMD compose ps
}

# Función para mostrar logs
show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        print_info "Mostrando logs de todos los servicios..."
        $DOCKER_CMD compose logs -f
    else
        print_info "Mostrando logs de: $service"
        $DOCKER_CMD compose logs -f "$service"
    fi
}

# Función para monitorear modelos Ollama (integra verifica_modelos.sh)
monitor_models() {
    print_header "MONITOREANDO DESCARGA DE MODELOS OLLAMA"
    if [ -f "$SCRIPT_DIR/verifica_modelos.sh" ]; then
        bash "$SCRIPT_DIR/verifica_modelos.sh"
    else
        print_error "Script 'verifica_modelos.sh' no encontrado."
        print_info "Puedes ejecutarlo manualmente si lo tienes: ./scripts/verifica_modelos.sh"
    fi
}

# Función para validación automática completa (integra auto-validate.sh)
auto_validate() {
    print_header "VALIDACIÓN AUTOMÁTICA COMPLETA"
    
    # OIDC Sync Verification (Specialized)
    if [ -f "$SCRIPT_DIR/tests/test-grafana-oidc-sync.sh" ]; then
        print_info "🔍 Verificando sincronización OIDC Grafana-Keycloak..."
        if ! bash "$SCRIPT_DIR/tests/test-grafana-oidc-sync.sh"; then
             print_warning "⚠️ La verificación de sincronización OIDC detectó advertencias (revisar output arriba). El despliegue continuará."
        fi
    fi

    if [ -f "$SCRIPT_DIR/auto-validate.sh" ]; then
        bash "$SCRIPT_DIR/auto-validate.sh"
    else
        print_error "Script 'auto-validate.sh' no encontrado."
        exit 1
    fi
}

# Función para probar integración de servicios (test-integration.sh)
test_integration() {
    print_header "PRUEBA DE INTEGRACIÓN DE SERVICIOS"
    if [ -f "$SCRIPT_DIR/tests/test-integration.sh" ]; then
        bash "$SCRIPT_DIR/tests/test-integration.sh"
    else
        print_error "Script 'tests/test-integration.sh' no encontrado."
        exit 1
    fi
}

# Función para inicializar volúmenes de configuración (integra init-config-volumes.sh)
init_volumes() {
    print_header "INICIALIZACIÓN DE VOLÚMENES DE CONFIGURACIÓN"
    
    print_info "📋 Sobre los volúmenes:"
    echo "   - Docker Compose crea volúmenes automáticamente cuando levantas servicios"
    echo "   - Este script copia configuraciones INICIALES a los volúmenes"
    echo "   - Útil para primera vez o cuando necesitas resetear configuraciones"
    echo ""
    
    read -p "¿Continuar con la inicialización de volúmenes? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_info "Operación cancelada"
        exit 0
    fi
    
    if [ -f "$SCRIPT_DIR/init-config-volumes.sh" ]; then
        bash "$SCRIPT_DIR/init-config-volumes.sh"
    else
        print_error "Script 'init-config-volumes.sh' no encontrado."
        exit 1
    fi
}

# Función para mostrar información de servicios levantados
show_service_info() {
    print_header "INFORMACIÓN DE SERVICIOS"
    
    # Servicios base
    if $DOCKER_CMD compose ps postgres 2>/dev/null | grep -q "Up"; then
        print_info "Servicios Base:"
        echo "  - PostgreSQL: localhost:5432"
        echo "  - Open WebUI: http://localhost:3000"
        echo "  - n8n: http://localhost:5678"
        echo "  - Qdrant: http://localhost:6333"
        echo ""
    fi
    
    # Servicios con perfiles
    if $DOCKER_CMD compose --profile monitoring ps prometheus 2>/dev/null | grep -q "Up"; then
        print_info "Servicios de Monitoreo:"
        echo "  - Grafana: http://localhost:3001"
        echo "  - Prometheus: http://localhost:9090"
        echo "  - AlertManager: http://localhost:9093"
        echo ""
    fi
    
    if $DOCKER_CMD compose --profile security ps keycloak 2>/dev/null | grep -q "Up"; then
        print_info "Servicios de Seguridad:"
        echo "  - Keycloak: http://localhost:8080"
        echo ""
    fi
    
    if $DOCKER_CMD compose --profile infrastructure ps redis 2>/dev/null | grep -q "Up"; then
        print_info "Servicios de Infraestructura:"
        echo "  - Redis: localhost:6379"
        echo "  - HAProxy: http://localhost:80"
        echo ""
    fi
}

# Función principal
main() {
    local action=${1:-help}
    shift || true
    
    case "$action" in
        start)
            start_services "$@"
            ;;
        stop)
            stop_services "$@"
            ;;
        clean)
            local clean_type=${1:-"default"}
            print_header "LIMPIEZA DE RECURSOS DEL PROYECTO"
            
            # Validar tipo de limpieza
            case "$clean_type" in
                all|containers|networks|storage|default)
                    ;;
                *)
                    print_error "Tipo de limpieza inválido: $clean_type"
                    echo ""
                    print_info "Tipos válidos:"
                    echo "  - all        : Elimina contenedores, redes, almacenamiento e imágenes"
                    echo "  - containers : Solo elimina contenedores detenidos/creados"
                    echo "  - networks   : Solo elimina redes vacías del proyecto"
                    echo "  - storage    : Solo elimina volúmenes/almacenamiento del proyecto"
                    echo "  - (vacío)    : Limpieza de recursos huérfanos (redes vacías, contenedores creados) - SEGURO"
                    echo ""
                    print_info "Ejemplo: ./scripts/stack-manager.sh clean all"
                    exit 1
                    ;;
            esac
            
            cleanup_orphaned_resources "$clean_type"
            ;;
        restart)
            restart_services "$@"
            ;;
        status)
            show_status
            ;;
        info)
            show_service_info
            ;;
        logs)
            show_logs "$@"
            ;;
        validate)
            validate_before_start
            ;;
        auto-validate)
            auto_validate
            ;;
        test)
            test_changes
            ;;
        diagnose)
            local diagnose_target=${1:-""}
            case "$diagnose_target" in
                keycloak-db)
                    diagnose_keycloak_db
                    ;;
                *)
                    print_error "Diagnóstico no válido: $diagnose_target"
                    echo ""
                    print_info "Diagnósticos disponibles:"
                    echo "  keycloak-db    - Diagnóstico detallado de base de datos de Keycloak"
                    echo ""
                    exit 1
                    ;;
            esac
            ;;
        init-volumes)
            init_volumes
            ;;
        monitor)
            monitor_models
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Opción desconocida: $action"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
