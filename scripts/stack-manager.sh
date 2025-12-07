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
    ./scripts/stack-manager.sh [OPCIÓN] [PERFILES...]

OPCIONES:
    start [perfiles]     Levantar servicios con perfiles especificados
    stop [perfiles]      Detener servicios con perfiles especificados
    restart [perfiles]   Reiniciar servicios con perfiles especificados
    status               Mostrar estado de todos los servicios
    info                 Mostrar información de URLs y servicios disponibles
    logs [servicio]      Mostrar logs de servicios
    validate             Validar configuración antes de levantar
    auto-validate        Validación completa automática (variables, config, servicios)
    test                 Probar cambios recientes (ModSecurity, Prometheus, etc.)
    init-volumes         Inicializar volúmenes con configuraciones por defecto
    monitor              Monitorear descarga de modelos Ollama
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
        automation       Watchtower, Sync
        ci-cd            Jenkins
        testing          Test Runner
        debug            Debug Tools
        dev              Development Tools

PRESETS (combinaciones predefinidas):
    default              gpu-nvidia + monitoring + infrastructure + security
    minimal              Solo servicios base (sin perfiles)
    dev                  cpu + dev + testing
    production           gpu-nvidia + monitoring + infrastructure + security + automation
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
    - El preset 'default' incluye: gpu-nvidia + monitoring + infrastructure + security

HELP_EOF
}

# Función para validar antes de levantar
validate_before_start() {
    print_header "VALIDACIÓN PREVIA"
    
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
        if ! bash "$SCRIPT_DIR/validate-config.sh" > /tmp/stack-config-validation.log 2>&1; then
            print_warning "Algunos problemas en configuración (revisa el log)"
            return 0  # No bloqueamos, solo advertimos
        fi
        print_success "Configuración OK"
    fi
    
    return 0
}

# Función para expandir presets
expand_preset() {
    local preset=$1
    case "$preset" in
        default)
            echo "gpu-nvidia monitoring infrastructure security"
            ;;
        minimal)
            echo ""
            ;;
        dev)
            echo "cpu dev testing"
            ;;
        production)
            echo "gpu-nvidia monitoring infrastructure security automation"
            ;;
        full)
            echo "gpu-nvidia monitoring infrastructure security automation ci-cd testing debug dev"
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
    local profiles=("$@")
    
    local cmd="$DOCKER_CMD compose"
    
    # Agregar perfiles
    for profile in "${profiles[@]}"; do
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

# Función para levantar servicios
start_services() {
    local profiles=("$@")
    
    # Si no hay perfiles, usar preset default
    if [ ${#profiles[@]} -eq 0 ]; then
        print_info "No se especificaron perfiles, usando preset 'default'"
        local preset_profiles=$(expand_preset default)
        read -ra profiles <<< "$preset_profiles"
    fi
    
    # Expandir presets si alguno es un preset
    local expanded_profiles=()
    for profile in "${profiles[@]}"; do
        local expanded=$(expand_preset "$profile")
        if [ "$expanded" != "$profile" ]; then
            # Es un preset, expandirlo
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
    print_info "Perfiles: ${unique_profiles[*]}"
    
    # Validar antes de levantar
    if ! validate_before_start; then
        print_error "Validación falló. Corrige los errores antes de continuar."
        exit 1
    fi
    
    # Construir y ejecutar comando
    local cmd=$(build_compose_command up "${unique_profiles[@]}")
    print_info "Ejecutando: $cmd"
    
    if eval "$cmd"; then
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
        if [[ " ${unique_profiles[@]} " =~ " security " ]]; then
            echo ""
            print_info "Servicios de seguridad disponibles:"
            echo "  - Keycloak: http://localhost:8080"
        fi
        
        return 0
    else
        print_error "Error al levantar servicios"
        return 1
    fi
}

# Función para detener servicios
stop_services() {
    local profiles=("$@")
    
    print_header "DETENIENDO SERVICIOS"
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_info "Deteniendo todos los servicios..."
        $DOCKER_CMD compose down
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
        
        local cmd=$(build_compose_command down "${unique_profiles[@]}")
        eval "$cmd"
    fi
    
    print_success "Servicios detenidos"
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
    if [ -f "$SCRIPT_DIR/auto-validate.sh" ]; then
        bash "$SCRIPT_DIR/auto-validate.sh"
    else
        print_error "Script 'auto-validate.sh' no encontrado."
        exit 1
    fi
}

# Función para probar cambios recientes (integra test-changes.sh)
test_changes() {
    print_header "PRUEBA DE CAMBIOS RECIENTES"
    if [ -f "$SCRIPT_DIR/test-changes.sh" ]; then
        bash "$SCRIPT_DIR/test-changes.sh"
    else
        print_error "Script 'test-changes.sh' no encontrado."
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
