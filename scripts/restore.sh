#!/bin/bash

# =============================================================================
# Script de Restauración - My Self-Hosted AI Kit
# =============================================================================
# Restaura backups de volúmenes Docker y bases de datos
#
# Uso:
#   ./scripts/restore.sh <timestamp-del-backup>
#
# Ejemplo:
#   ./scripts/restore.sh 20251207-140000
# =============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Verificar argumentos
if [ $# -eq 0 ]; then
    log_error "Debes especificar el timestamp del backup a restaurar"
    echo ""
    echo "Backups disponibles:"
    ls -1 "$BACKUP_DIR" 2>/dev/null | grep -E "^[0-9]{8}-[0-9]{6}$" || echo "  (ninguno)"
    echo ""
    echo "Uso: $0 <timestamp>"
    echo "Ejemplo: $0 20251207-140000"
    exit 1
fi

TIMESTAMP=$1
BACKUP_SESSION_DIR="${BACKUP_DIR}/${TIMESTAMP}"

# Verificar que el backup existe
if [ ! -d "$BACKUP_SESSION_DIR" ]; then
    log_error "Backup no encontrado: $BACKUP_SESSION_DIR"
    exit 1
fi

log_warning "⚠️  ADVERTENCIA: Esta operación reemplazará datos existentes"
log_warning "⚠️  Asegúrate de tener un backup reciente antes de continuar"
echo ""
read -p "¿Continuar con la restauración? (escribe 'si' para confirmar): " CONFIRM

if [ "$CONFIRM" != "si" ]; then
    log "Restauración cancelada"
    exit 0
fi

# Función para restaurar volumen
restore_volume() {
    local VOLUME_NAME=$1
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/${VOLUME_NAME}.tar.gz"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_warning "Backup de volumen $VOLUME_NAME no encontrado, omitiendo"
        return 0
    fi
    
    log "Restaurando volumen: $VOLUME_NAME"
    
    # Verificar que el volumen existe o crearlo
    if ! docker volume ls | grep -q "$VOLUME_NAME"; then
        log "Creando volumen $VOLUME_NAME"
        docker volume create "$VOLUME_NAME" >/dev/null
    fi
    
    # Restaurar desde backup
    docker run --rm \
        -v "$VOLUME_NAME":/target \
        -v "$BACKUP_SESSION_DIR":/backup:ro \
        alpine:latest \
        sh -c "cd /target && rm -rf * .[!.]* ..?* 2>/dev/null; tar xzf /backup/${VOLUME_NAME}.tar.gz" || {
        log_error "Error al restaurar volumen $VOLUME_NAME"
        return 1
    }
    
    log_success "Volumen $VOLUME_NAME restaurado"
}

# Función para restaurar PostgreSQL
restore_postgres() {
    local DB_NAME="${POSTGRES_DB:-n8n}"
    local DB_USER="${POSTGRES_USER:-postgres}"
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/postgres_${DB_NAME}.sql.gz"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_warning "Backup de PostgreSQL no encontrado, omitiendo"
        return 0
    fi
    
    log "Restaurando base de datos PostgreSQL: $DB_NAME"
    
    # Verificar que PostgreSQL está corriendo
    if ! docker compose ps postgres | grep -q "Up"; then
        log_error "PostgreSQL no está corriendo. Inicia el servicio primero."
        return 1
    fi
    
    # Restaurar base de datos
    gunzip -c "$BACKUP_FILE" | docker compose exec -T postgres \
        psql -U "$DB_USER" "$DB_NAME" || {
        log_error "Error al restaurar PostgreSQL"
        return 1
    }
    
    log_success "PostgreSQL $DB_NAME restaurado"
}

# Función principal
main() {
    log "=== Inicio de Restauración ==="
    log "Backup: $TIMESTAMP"
    log "Origen: $BACKUP_SESSION_DIR"
    
    # Cargar variables de entorno si existen
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env"
    fi
    
    # Lista de volúmenes a restaurar
    # NOTA: ollama_storage se excluye porque los modelos se pueden volver a descargar
    VOLUMES=(
        "n8n_storage"
        "postgres_storage"
        # "ollama_storage"  # Excluido: modelos se pueden volver a descargar
        "qdrant_storage"
        "open_webui_storage"
        "grafana_data"
        "prometheus_data"
        "keycloak_data"
    )
    
    local SUCCESS=0
    local FAILED=0
    
    # Restaurar volúmenes
    for volume in "${VOLUMES[@]}"; do
        if restore_volume "$volume"; then
            ((SUCCESS++))
        else
            ((FAILED++))
        fi
    done
    
    # Restaurar PostgreSQL
    restore_postgres || ((FAILED++))
    
    # Resumen
    log ""
    log "=== Resumen de Restauración ==="
    log_success "Restauraciones exitosas: $SUCCESS"
    if [ $FAILED -gt 0 ]; then
        log_error "Restauraciones fallidas: $FAILED"
    fi
    
    log ""
    log_warning "Reinicia los servicios para aplicar los cambios:"
    log "  docker compose restart"
    
    if [ $FAILED -eq 0 ]; then
        log_success "Restauración completada exitosamente"
        exit 0
    else
        log_error "Restauración completada con errores"
        exit 1
    fi
}

main

