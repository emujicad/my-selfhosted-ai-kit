#!/bin/bash

# =============================================================================
# Script de Validación Automática Completa
# =============================================================================
# Ejecuta todas las validaciones y pruebas automáticamente
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
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
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Detectar comando de Docker
detect_docker() {
    if docker ps > /dev/null 2>&1; then
        DOCKER_CMD="docker"
        print_success "Docker accesible sin sudo"
        return 0
    elif sudo docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
        print_success "Docker accesible con sudo"
        return 0
    else
        print_error "Docker no está disponible"
        return 1
    fi
}

# Paso 0: Verificar variables de entorno (CRÍTICO)
step0_verify_env_variables() {
    print_header "PASO 0: VERIFICAR VARIABLES DE ENTORNO (CRÍTICO)"
    
    print_info "Verificando variables críticas de .env..."
    
    if [ -f "$SCRIPT_DIR/validate-system.sh" ]; then
        bash "$SCRIPT_DIR/validate-system.sh" --env > /tmp/env-verification.log 2>&1
        ENV_VERIFICATION_EXIT=$?
        
        # Contar errores
        ERROR_COUNT=$(grep -c "❌" /tmp/env-verification.log | tr -d '[:space:]' || echo "0")
        WARNING_COUNT=$(grep -c "⚠️" /tmp/env-verification.log | tr -d '[:space:]' || echo "0")
        
        if [ "$ERROR_COUNT" -eq 0 ]; then
            if [ "$WARNING_COUNT" -gt 0 ]; then
                print_warning "Verificación de variables completada con advertencias"
                cat /tmp/env-verification.log | grep -E "⚠️|ℹ️" | head -10
            else
                print_success "Todas las variables críticas están configuradas correctamente"
            fi
            return 0
        else
            print_error "Se encontraron errores críticos en las variables de entorno"
            cat /tmp/env-verification.log | grep "❌"
            print_error "Por favor, corrige las variables vacías en .env antes de continuar"
            return 1
        fi
    else
        print_warning "Script de validación no encontrado, saltando este paso"
        return 0
    fi
}

# Paso 1: Validación estática
step1_static_validation() {
    print_header "PASO 1: VALIDACIÓN ESTÁTICA"
    
    print_info "Ejecutando validación estática de configuración..."
    
    if [ -f "$SCRIPT_DIR/validate-system.sh" ]; then
    bash "$SCRIPT_DIR/validate-system.sh" --config > /tmp/validation.log 2>&1
    VALIDATION_EXIT=$?
    
    # Contar errores reales (no warnings)
    ERROR_COUNT=$(grep -c "❌" /tmp/validation.log | tr -d '[:space:]' || echo "0")
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        print_success "Validación estática completada"
        cat /tmp/validation.log | grep -E "✅|❌|⚠️" | head -20
        return 0
    else
        print_error "Validación estática encontró errores"
        cat /tmp/validation.log | grep "❌"
        return 1
    fi
    else
        print_error "Script de sistema (validate-system.sh) no encontrado"
        return 1
    fi
}

# Paso 2: Levantar servicios
step2_start_services() {
    print_header "PASO 2: LEVANTAR SERVICIOS"
    
    if ! detect_docker; then
        print_warning "Docker no disponible, saltando este paso"
        return 1
    fi
    
    print_info "Verificando servicios existentes..."
    EXISTING_SERVICES=$($DOCKER_CMD compose ps --format json 2>/dev/null | jq -r '.[].Name' 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_SERVICES" ]; then
        print_info "Servicios existentes encontrados, verificando estado..."
    fi
    
    print_info "Levantando servicios principales..."
    if $DOCKER_CMD compose up -d postgres pgvector qdrant 2>&1 | tee /tmp/docker-start.log | tail -5; then
        print_success "Servicios principales levantados"
    else
        print_error "Error al levantar servicios principales"
        return 1
    fi
    
    sleep 5
    
    print_info "Levantando servicios con perfil monitoring..."
    if $DOCKER_CMD compose --profile monitoring up -d prometheus grafana alertmanager 2>&1 | tee -a /tmp/docker-start.log | tail -5; then
        print_success "Servicios de monitoreo levantados"
    else
        print_error "Error al levantar servicios de monitoreo"
        return 1
    fi
    
    sleep 5
    
    print_info "Levantando servicios con perfil security..."
    if $DOCKER_CMD compose --profile security up -d modsecurity 2>&1 | tee -a /tmp/docker-start.log | tail -5; then
        print_success "Servicios de seguridad levantados"
    else
        print_error "Error al levantar servicios de seguridad"
        return 1
    fi
    
    print_info "Esperando a que los servicios estén listos..."
    sleep 10
    
    return 0
}

# Paso 3: Verificar servicios
step3_verify_services() {
    print_header "PASO 3: VERIFICAR SERVICIOS"
    
    if ! detect_docker; then
        print_warning "Docker no disponible, saltando este paso"
        return 1
    fi
    
    ERRORS=0
    
    # Verificar Prometheus
    print_info "Verificando Prometheus..."
    if $DOCKER_CMD compose --profile monitoring ps prometheus 2>/dev/null | grep -q "Up\|running"; then
        print_success "Prometheus está corriendo"
        
        # Verificar endpoint
        sleep 3
        if curl -s -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
            print_success "Prometheus responde en http://localhost:9090"
            
            # Verificar Targets Granularmente
            print_info "Verificando estado de los Targets de Prometheus..."
            TARGETS_STATUS=$(curl -s http://localhost:9090/api/v1/targets | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    targets = data.get('data', {}).get('activeTargets', [])
    down_targets = []
    print(f'{len(targets)} targets configurados.')
    for t in targets:
        job = t['labels']['job']
        health = t['health']
        error = t.get('lastError', '')
        status_icon = '✅' if health == 'up' else '❌'
        print(f'   {status_icon} {job}: {health} {error}')
        if health != 'up':
            down_targets.append(job)
    
    if down_targets:
        print('DOWN_TARGETS=' + ','.join(down_targets))
except Exception as e:
    print(f'Error parsing targets: {e}')
    exit(1)
")
            echo "$TARGETS_STATUS"
            
            if echo "$TARGETS_STATUS" | grep -q "DOWN_TARGETS="; then
                 # Si encontramos targets caídos, verificar si son críticos
                 # (Para esta validación estricta, cualquier fallo es un warning/error)
                 print_warning "Algunos targets de Prometheus no están UP"
                 ((ERRORS++))
            else
                 print_success "Todos los targets de Prometheus están UP"
            fi

            # Verificar que las alertas están cargadas
            sleep 1
            if curl -s http://localhost:9090/api/v1/rules 2>/dev/null | grep -q "alerts\|groups"; then
                print_success "Alertas cargadas en Prometheus"
            else
                print_warning "No se pudo verificar alertas (puede requerir más tiempo)"
            fi
        else
            print_warning "Prometheus no responde aún (puede estar iniciando)"
            ((ERRORS++))
        fi
        
        # Verificar logs
        print_info "Revisando logs de Prometheus..."
        PROMETHEUS_LOGS=$($DOCKER_CMD compose --profile monitoring logs prometheus 2>&1 | tail -10)
        if echo "$PROMETHEUS_LOGS" | grep -qi "error\|fatal\|failed"; then
            print_warning "Posibles errores en logs de Prometheus:"
            echo "$PROMETHEUS_LOGS" | grep -i "error\|fatal\|failed" | head -3
            # No contamos esto como error crítico si el healthcheck pasa
        else
            print_success "No hay errores críticos en logs de Prometheus"
        fi
    else
        print_error "Prometheus no está corriendo"
        ((ERRORS++))
    fi
    
    echo ""
    
    # Verificar ModSecurity
    print_info "Verificando ModSecurity..."
    if $DOCKER_CMD compose --profile security ps modsecurity 2>/dev/null | grep -q "Up\|running"; then
        print_success "ModSecurity está corriendo"
        
        # Verificar montaje de archivos
        print_info "Verificando montaje de archivos de configuración..."
        if $DOCKER_CMD exec modsecurity test -f /etc/nginx/modsecurity/modsecurity.conf 2>/dev/null; then
            print_success "modsecurity.conf está montado correctamente"
        else
            print_error "modsecurity.conf NO está montado"
            ((ERRORS++))
        fi
        
        if $DOCKER_CMD exec modsecurity test -d /etc/nginx/modsecurity/rules 2>/dev/null; then
            print_success "Directorio rules/ está montado correctamente"
        else
            print_error "Directorio rules/ NO está montado"
            ((ERRORS++))
        fi
        
        # Verificar logs
        print_info "Revisando logs de ModSecurity..."
        MODSECURITY_LOGS=$($DOCKER_CMD compose --profile security logs modsecurity 2>&1 | tail -10)
        if echo "$MODSECURITY_LOGS" | grep -qi "error\|fatal\|failed\|cannot"; then
            print_warning "Posibles errores en logs de ModSecurity:"
            echo "$MODSECURITY_LOGS" | grep -i "error\|fatal\|failed\|cannot" | head -3
            ((ERRORS++))
        else
            print_success "No hay errores críticos en logs de ModSecurity"
        fi
    else
        print_error "ModSecurity no está corriendo"
        ((ERRORS++))
    fi
    
    echo ""
    
    # Resumen de verificación
    if [ $ERRORS -eq 0 ]; then
        print_success "Todas las verificaciones pasaron"
        return 0
    else
        print_error "Se encontraron $ERRORS problema(s)"
        return 1
    fi
}

# Función principal
main() {
    echo ""
    print_header "🚀 VALIDACIÓN AUTOMÁTICA COMPLETA"
    echo ""
    print_info "Este script ejecutará automáticamente:"
    echo "  0. Verificación de variables de entorno (CRÍTICO)"
    echo "  1. Validación estática de configuración"
    echo "  2. Levantamiento de servicios Docker"
    echo "  3. Verificación de servicios corriendo"
    echo ""
    
    TOTAL_STEPS=4
    COMPLETED_STEPS=0
    
    # Paso 0: Verificar variables de entorno (CRÍTICO)
    if step0_verify_env_variables; then
        ((COMPLETED_STEPS++))
    else
        print_error "Paso 0 falló, abortando..."
        print_error "Corrige las variables vacías en .env antes de continuar"
        exit 1
    fi
    
    # Paso 1: Validación estática
    if step1_static_validation; then
        ((COMPLETED_STEPS++))
    else
        print_error "Paso 1 falló, abortando..."
        exit 1
    fi
    
    # Paso 2: Levantar servicios (solo si Docker está disponible)
    if detect_docker > /dev/null 2>&1; then
        if step2_start_services; then
            ((COMPLETED_STEPS++))
        else
            print_warning "Paso 2 tuvo problemas, continuando con verificación..."
        fi
        
        # Paso 3: Verificar servicios
        if step3_verify_services; then
            ((COMPLETED_STEPS++))
        else
            print_warning "Paso 3 tuvo problemas"
        fi
    else
        print_warning "Docker no disponible, saltando pasos 2 y 3"
        print_info "Para ejecutar pasos 2 y 3, asegúrate de que Docker esté corriendo"
    fi
    
    # Resumen final
    print_header "📊 RESUMEN FINAL"
    echo ""
    echo "Pasos completados: $COMPLETED_STEPS/$TOTAL_STEPS"
    echo ""
    
    if [ $COMPLETED_STEPS -eq $TOTAL_STEPS ]; then
        print_success "✅ Todas las validaciones completadas exitosamente"
        echo ""
        print_info "Servicios disponibles:"
        echo "  - Prometheus: http://localhost:9090"
        echo "  - Grafana: http://localhost:3001"
        echo "  - AlertManager: http://localhost:9093"
        echo ""
        print_info "Para ver logs:"
        echo "  $DOCKER_CMD compose --profile monitoring logs -f prometheus"
        echo "  $DOCKER_CMD compose --profile security logs -f modsecurity"
        exit 0
    elif [ $COMPLETED_STEPS -eq 1 ]; then
        print_warning "Solo validación estática completada"
        print_info "Ejecuta este script nuevamente cuando Docker esté disponible"
        exit 0
    else
        print_warning "Algunas validaciones tuvieron problemas"
        print_info "Revisa los mensajes anteriores para más detalles"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"

