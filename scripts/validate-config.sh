#!/bin/bash

# =============================================================================
# Script de Validación de Configuración
# =============================================================================
# Valida que todos los cambios estén correctamente configurados
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "🔍 VALIDACIÓN DE CONFIGURACIÓN DEL STACK"
echo "========================================"
echo ""

ERRORS=0
WARNINGS=0

# Función para verificar archivo
check_file() {
    if [ -f "$1" ]; then
        echo "   ✅ $1 existe"
        return 0
    else
        echo "   ❌ $1 NO existe"
        ((ERRORS++))
        return 1
    fi
}

# Función para verificar directorio
check_dir() {
    if [ -d "$1" ]; then
        echo "   ✅ $1/ existe"
        return 0
    else
        echo "   ❌ $1/ NO existe"
        ((ERRORS++))
        return 1
    fi
}

# Función para verificar contenido en archivo
check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo "   ✅ $1 contiene: $2"
        return 0
    else
        echo "   ❌ $1 NO contiene: $2"
        ((ERRORS++))
        return 1
    fi
}

echo "1️⃣  VALIDANDO MODSECURITY"
echo "-------------------------"
check_file "modsecurity/modsecurity.conf"
check_file "modsecurity/README.md"
check_dir "modsecurity/rules"
check_file "modsecurity/rules/REQUEST-901-INITIALIZATION.conf"
echo ""

echo "2️⃣  VALIDANDO PROMETHEUS ALERTS"
echo "-------------------------------"
check_file "monitoring/prometheus.yml"
check_file "monitoring/prometheus/alerts.yml"
check_content "monitoring/prometheus.yml" "alerts.yml"
echo ""

echo "3️⃣  VALIDANDO DOCKER COMPOSE"
echo "----------------------------"
check_file "docker-compose.yml"
check_content "docker-compose.yml" "modsecurity.conf"
check_content "docker-compose.yml" "alerts.yml"
echo ""

echo "4️⃣  VALIDANDO SINTAXIS YAML"
echo "---------------------------"
if command -v python3 > /dev/null 2>&1; then
    echo "   Verificando prometheus.yml..."
    if python3 -c "import yaml; yaml.safe_load(open('monitoring/prometheus.yml'))" 2>/dev/null; then
        echo "   ✅ prometheus.yml: Sintaxis válida"
    else
        echo "   ❌ prometheus.yml: Error de sintaxis"
        ((ERRORS++))
    fi
    
    echo "   Verificando alerts.yml..."
    if python3 -c "import yaml; yaml.safe_load(open('monitoring/prometheus/alerts.yml'))" 2>/dev/null; then
        echo "   ✅ alerts.yml: Sintaxis válida"
    else
        echo "   ❌ alerts.yml: Error de sintaxis"
        ((ERRORS++))
    fi
else
    echo "   ⚠️  python3 no disponible, saltando validación YAML"
    ((WARNINGS++))
fi
echo ""

echo "5️⃣  VALIDANDO DOCKER COMPOSE SYNTAX"
echo "-----------------------------------"
if command -v docker > /dev/null 2>&1 || command -v docker-compose > /dev/null 2>&1; then
    echo "   Verificando sintaxis de docker-compose.yml..."
    if docker compose config > /dev/null 2>&1 || docker-compose config > /dev/null 2>&1; then
        echo "   ✅ docker-compose.yml: Sintaxis válida"
    else
        # Si falla, puede ser porque Docker no está corriendo, no necesariamente error de sintaxis
        if docker ps > /dev/null 2>&1 || sudo docker ps > /dev/null 2>&1; then
            echo "   ❌ docker-compose.yml: Error de sintaxis"
            ((ERRORS++))
        else
            echo "   ⚠️  Docker no está corriendo, no se puede validar sintaxis"
            ((WARNINGS++))
        fi
    fi
else
    echo "   ⚠️  Docker no disponible, saltando validación"
    ((WARNINGS++))
fi
echo ""

echo "6️⃣  VALIDANDO SERVICIOS (si Docker está disponible)"
echo "--------------------------------------------------"
if docker ps > /dev/null 2>&1 || sudo docker ps > /dev/null 2>&1; then
    DOCKER_CMD="docker"
    if ! docker ps > /dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi
    
    echo "   Verificando servicios de monitoreo..."
    if $DOCKER_CMD compose ps prometheus 2>/dev/null | grep -q prometheus; then
        echo "   ✅ Prometheus está corriendo"
    else
        echo "   ⚠️  Prometheus no está corriendo (normal si no se levantó con --profile monitoring)"
        ((WARNINGS++))
    fi
    
    echo "   Verificando servicios de seguridad..."
    if $DOCKER_CMD compose ps modsecurity 2>/dev/null | grep -q modsecurity; then
        echo "   ✅ ModSecurity está corriendo"
    else
        echo "   ⚠️  ModSecurity no está corriendo (normal si no se levantó con --profile security)"
        ((WARNINGS++))
    fi
else
    echo "   ⚠️  Docker no disponible, saltando verificación de servicios"
    ((WARNINGS++))
fi
echo ""

echo "========================================"
echo "📊 RESUMEN DE VALIDACIÓN"
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ Validación exitosa: No se encontraron errores"
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  Advertencias: $WARNINGS (normal si Docker no está disponible)"
    fi
    echo ""
    echo "🎉 La configuración está lista para usar"
    echo ""
    echo "Para levantar los servicios:"
    echo "  # Servicios principales"
    echo "  docker compose up -d"
    echo ""
    echo "  # Con monitoreo"
    echo "  docker compose --profile monitoring up -d"
    echo ""
    echo "  # Con seguridad"
    echo "  docker compose --profile security up -d"
    echo ""
    echo "  # Todo junto"
    echo "  docker compose --profile monitoring --profile security up -d"
    exit 0
else
    echo "❌ Se encontraron $ERRORS error(es)"
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  Advertencias: $WARNINGS"
    fi
    echo ""
    echo "Por favor, corrige los errores antes de continuar"
    # Solo salir con error si hay errores reales, no solo advertencias
    if [ $ERRORS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
fi

