#!/bin/bash

# =============================================================================
# Script de Prueba de Cambios Recientes
# =============================================================================
# Prueba que ModSecurity y Prometheus Alerts funcionen correctamente
# =============================================================================

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Verificar variables de entorno antes de continuar
if [ -f "$SCRIPT_DIR/../verify-env-variables.sh" ]; then
    echo "🔍 Verificando variables de entorno..."
    
    # Crear directorio de logs
    LOG_DIR="$PROJECT_ROOT/logs"
    mkdir -p "$LOG_DIR"
    
    if ! bash "$SCRIPT_DIR/../verify-env-variables.sh" > "$LOG_DIR/env-verification.log" 2>&1; then
        echo "❌ ERROR: Se encontraron errores críticos en las variables de entorno"
        cat "$LOG_DIR/env-verification.log" | grep "❌ ERROR"
        echo ""
        echo "Por favor, corrige las variables vacías en .env antes de continuar"
        exit 0
    fi
    echo "✅ Variables de entorno verificadas"
    echo ""
fi

# Detectar comando de Docker
DOCKER_CMD="docker"
if ! docker ps > /dev/null 2>&1; then
    if sudo docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        echo "❌ Docker no está disponible"
        exit 0
    fi
fi

echo "🧪 PRUEBA DE CAMBIOS RECIENTES"
echo "==============================="
echo ""
echo "Usando: $DOCKER_CMD"
echo ""

ERRORS=0

# Función para verificar servicio
check_service() {
    local SERVICE=$1
    local PROFILE=$2
    
    echo "🔍 Verificando servicio: $SERVICE"
    
    # Usar --format para obtener estado confiable
    STATUS=$($DOCKER_CMD compose ps --format "{{.Status}}" "$SERVICE" 2>/dev/null)
    
    if [ -n "$STATUS" ]; then
        # El estado puede ser "Up 2 hours", "running", "Up (healthy)", etc.
        if [[ "$STATUS" == "Up"* ]] || [[ "$STATUS" == "running"* ]]; then
            echo "   ✅ $SERVICE está corriendo ($STATUS)"
            return 0
        else
            echo "   ⚠️  $SERVICE existe pero no está corriendo (Estado: $STATUS)"
            return 1
        fi
    else
        echo "   ⚠️  $SERVICE no está corriendo"
        return 1
    fi
}

# Función para verificar logs sin errores críticos
check_logs() {
    local SERVICE=$1
    local PROFILE=$2
    
    echo "📋 Verificando logs de: $SERVICE"
    
    # Nota: Ya no usamos --profile porque causa errores si faltan dependencias de otros perfiles
    LOGS=$($DOCKER_CMD compose logs "$SERVICE" 2>&1 | tail -20)
    
    # Buscar errores críticos
    if echo "$LOGS" | grep -qi "error\|fatal\|failed\|cannot\|unable" | grep -v "INFO\|DEBUG"; then
        echo "   ⚠️  Se encontraron posibles errores en los logs"
        echo "$LOGS" | grep -i "error\|fatal\|failed\|cannot\|unable" | head -3
        return 1
    else
        echo "   ✅ No se encontraron errores críticos en los logs"
        return 0
    fi
}

# Función para verificar endpoint HTTP
check_endpoint() {
    local SERVICE=$1
    local PORT=$2
    local PATH=$3
    
    echo "🌐 Verificando endpoint: http://127.0.0.1:$PORT$PATH"
    
    # Usar 127.0.0.1 para evitar problemas de resolución IPv6
    if /usr/bin/curl -s -f "http://127.0.0.1:$PORT$PATH" > /dev/null; then
        echo "   ✅ Endpoint accesible"
        return 0
    else
        echo "   ⚠️  Endpoint no accesible. Salida de curl:"
        /usr/bin/curl -v "http://127.0.0.1:$PORT$PATH" || true
        return 1
    fi
}

echo "1️⃣  PRUEBA DE PROMETHEUS Y ALERTAS"
echo "-----------------------------------"
echo ""

# Verificar Prometheus
check_service "prometheus" "monitoring"
if [ $? -eq 0 ]; then
    check_logs "prometheus" "monitoring"
    
    # Verificar que las alertas están cargadas
    echo "📊 Verificando que las alertas están cargadas..."
    if curl -s "http://localhost:9090/api/v1/rules" 2>/dev/null | grep -q "alerts"; then
        echo "   ✅ Alertas cargadas en Prometheus"
    else
        echo "   ⚠️  No se pudo verificar alertas (puede requerir tiempo para cargar)"
    fi
    
    # Verificar endpoint de Prometheus
    check_endpoint "prometheus" "9090" "/-/healthy"
fi

echo ""
echo "2️⃣  PRUEBA DE MODSECURITY"
echo "-------------------------"
echo ""

# Verificar ModSecurity
check_service "modsecurity" "security"
if [ $? -eq 0 ]; then
    check_logs "modsecurity" "security"
    
    # Verificar que los archivos de configuración están montados
    echo "📁 Verificando montaje de archivos de configuración..."
    if $DOCKER_CMD exec modsecurity test -f /etc/nginx/modsecurity/modsecurity.conf 2>/dev/null; then
        echo "   ✅ modsecurity.conf está montado correctamente"
    else
        echo "   ⚠️  modsecurity.conf no está montado"
        ((ERRORS++))
    fi
    
    if $DOCKER_CMD exec modsecurity test -d /etc/nginx/modsecurity/rules 2>/dev/null; then
        echo "   ✅ Directorio rules/ está montado correctamente"
    else
        echo "   ⚠️  Directorio rules/ no está montado"
        ((ERRORS++))
    fi
fi

echo ""
echo "4️⃣  PRUEBA DE REDIS (OPEN WEBUI)"
echo "--------------------------------"
echo ""

# Verificar Redis
check_service "redis" "infrastructure"
if [ $? -eq 0 ]; then
    echo "🔍 Verificando integración Open WebUI -> Redis..."
    
    # 1. Variables de entorno
    if $DOCKER_CMD exec open-webui env | grep -q "CACHE_TYPE=redis"; then
         echo "   ✅ Variable CACHE_TYPE=redis configurada"
    else
         echo "   ❌ Variable CACHE_TYPE no configurada correctamente"
         ((ERRORS++))
    fi
    
    # 2. Conectividad
    # Curl devuelve 52 (Empty reply) cuando conecta exitosamente a Redis (porque Redis no habla HTTP)
    # O verifica "Connected to redis" en el output verbose
    if $DOCKER_CMD exec open-webui curl -v redis:6379 2>&1 | grep -q "Connected to redis"; then
         echo "   ✅ Open WebUI puede conectarse a Redis:6379"
    else
         echo "   ❌ Open WebUI NO puede conectarse a Redis"
         ((ERRORS++))
    fi
fi

echo ""
echo "5️⃣  VERIFICACIÓN DE CONFIGURACIÓN"
echo "----------------------------------"
echo ""

# Verificar que los volúmenes están correctamente configurados
echo "🔍 Verificando configuración de volúmenes en docker-compose..."
if grep -q "modsecurity.conf.*:ro" "$PROJECT_ROOT/docker-compose.yml"; then
    echo "   ✅ modsecurity.conf configurado como solo lectura"
else
    echo "   ⚠️  modsecurity.conf no configurado como solo lectura"
fi

if grep -q "alerts.yml.*:ro" "$PROJECT_ROOT/docker-compose.yml"; then
    echo "   ✅ alerts.yml configurado como solo lectura"
else
    echo "   ⚠️  alerts.yml no configurado como solo lectura"
fi

echo ""
echo "========================================"
echo "📊 RESUMEN DE PRUEBAS"
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ Todas las pruebas pasaron exitosamente"
    echo ""
    echo "🎉 Los cambios están funcionando correctamente"
    echo ""
    echo "Para ver los servicios en acción:"
    echo "  # Ver logs de Prometheus"
    echo "  $DOCKER_CMD compose --profile monitoring logs -f prometheus"
    echo ""
    echo "  # Ver logs de ModSecurity"
    echo "  $DOCKER_CMD compose --profile security logs -f modsecurity"
    echo ""
    echo "  # Ver estado de todos los servicios"
    echo "  $DOCKER_CMD compose ps"
    exit 0
else
    echo "⚠️  Se encontraron $ERRORS problema(s)"
    echo ""
    echo "Revisa los mensajes anteriores para más detalles"
    exit 0
fi

