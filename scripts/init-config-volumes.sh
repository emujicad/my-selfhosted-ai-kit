#!/bin/bash

# =============================================================================
# MY SELF-HOSTED AI KIT - Inicialización de Volúmenes de Configuración
# =============================================================================
# Este script copia las configuraciones iniciales a volúmenes persistentes
# para que persistan incluso si se borra el proyecto.
#
# Uso: ./scripts/init-config-volumes.sh
# =============================================================================

set -e

PROJECT_NAME="my-selfhosted-ai-kit"

echo "============================================================================="
echo "🔧 Inicialización de Volúmenes de Configuración Persistente"
echo "============================================================================="
echo ""

# Verificar que Docker está corriendo
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker no está corriendo"
    exit 1
fi

# Crear contenedor temporal para copiar archivos
CONTAINER_NAME="config-init-$$"

echo "1. Creando contenedor temporal..."
docker run -d --name "$CONTAINER_NAME" \
  -v "${PROJECT_NAME}_config_data:/config" \
  -v "${PROJECT_NAME}_grafana_provisioning_data:/grafana-provisioning" \
  -v "${PROJECT_NAME}_prometheus_rules_data:/prometheus-rules" \
  alpine:latest sleep 3600

echo "2. Copiando configuraciones de Prometheus..."
docker cp monitoring/prometheus.yml "$CONTAINER_NAME:/config/prometheus.yml" 2>/dev/null || echo "   ⚠️ monitoring/prometheus.yml no encontrado (se creará manualmente)"
docker cp monitoring/prometheus/alerts.yml "$CONTAINER_NAME:/config/alerts.yml" 2>/dev/null || echo "   ⚠️ monitoring/prometheus/alerts.yml no encontrado"
docker cp monitoring/alertmanager.yml "$CONTAINER_NAME:/config/alertmanager.yml" 2>/dev/null || echo "   ⚠️ monitoring/alertmanager.yml no encontrado"

echo "3. Copiando configuraciones de Grafana..."
docker cp monitoring/grafana/provisioning/datasources "$CONTAINER_NAME:/grafana-provisioning/" 2>/dev/null || echo "   ⚠️ monitoring/grafana/provisioning/datasources no encontrado"
docker cp monitoring/grafana/provisioning/dashboards "$CONTAINER_NAME:/grafana-provisioning/" 2>/dev/null || echo "   ⚠️ monitoring/grafana/provisioning/dashboards no encontrado"
docker cp monitoring/grafana/config/grafana.ini "$CONTAINER_NAME:/grafana-provisioning/grafana.ini" 2>/dev/null || echo "   ⚠️ monitoring/grafana/config/grafana.ini no encontrado"

echo "4. Copiando configuraciones de HAProxy..."
docker cp haproxy/haproxy.cfg "$CONTAINER_NAME:/config/haproxy.cfg" 2>/dev/null || echo "   ⚠️ haproxy/haproxy.cfg no encontrado"

echo "5. Copiando configuraciones de ModSecurity..."
docker cp modsecurity/modsecurity.conf "$CONTAINER_NAME:/config/modsecurity.conf" 2>/dev/null || echo "   ⚠️ modsecurity/modsecurity.conf no encontrado"
docker cp modsecurity/rules "$CONTAINER_NAME:/config/modsecurity-rules/" 2>/dev/null || echo "   ⚠️ modsecurity/rules no encontrado"

echo "6. Creando estructura de directorios para Prometheus..."
docker exec "$CONTAINER_NAME" mkdir -p /prometheus-rules/custom
docker exec "$CONTAINER_NAME" mkdir -p /config/prometheus

echo "7. Creando estructura de directorios para servicios..."
docker exec "$CONTAINER_NAME" mkdir -p /config/alertmanager
docker exec "$CONTAINER_NAME" mkdir -p /config/haproxy
docker exec "$CONTAINER_NAME" mkdir -p /config/modsecurity

echo "8. Moviendo archivos a ubicaciones correctas..."
docker exec "$CONTAINER_NAME" sh -c "
  # Prometheus
  [ -f /config/prometheus.yml ] && mv /config/prometheus.yml /config/prometheus/ || true
  [ -f /config/alerts.yml ] && mv /config/alerts.yml /config/prometheus/ || true
  
  # AlertManager
  [ -f /config/alertmanager.yml ] && mv /config/alertmanager.yml /config/alertmanager/ || true
  
  # HAProxy
  [ -f /config/haproxy.cfg ] && mv /config/haproxy.cfg /config/haproxy/ || true
  
  # ModSecurity
  [ -f /config/modsecurity.conf ] && mv /config/modsecurity.conf /config/modsecurity/ || true
  [ -d /config/modsecurity-rules ] && mv /config/modsecurity-rules /config/modsecurity/rules || true
"

echo "9. Limpiando contenedor temporal..."
docker rm -f "$CONTAINER_NAME"

echo ""
echo "✅ Volúmenes de configuración inicializados correctamente"
echo ""
echo "📋 Volúmenes creados/inicializados:"
echo "   - ${PROJECT_NAME}_config_data: Configuraciones de Prometheus, AlertManager, HAProxy, ModSecurity"
echo "   - ${PROJECT_NAME}_grafana_provisioning_data: Dashboards y datasources provisionados"
echo "   - ${PROJECT_NAME}_prometheus_rules_data: Reglas de alertas personalizadas"
echo ""
echo "📝 NOTA: Las configuraciones ahora persisten en volúmenes Docker."
echo "   Si necesitas actualizar configuraciones, edita los archivos en el proyecto"
echo "   y ejecuta este script nuevamente."
