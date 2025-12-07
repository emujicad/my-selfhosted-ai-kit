#!/bin/bash

# =============================================================================
# Script de Backup Mejorado - My Self-Hosted AI Kit
# =============================================================================
# Realiza backups incrementales de volúmenes Docker, bases de datos y configuraciones
#
# Uso:
#   ./scripts/backup.sh [--full] [--verify]
#
# Opciones:
#   --full    : Realiza backup completo (no incremental)
#   --verify  : Verifica integridad después del backup
# =============================================================================

set -uo pipefail  # Removido -e para permitir manejo manual de errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_TYPE="${1:-incremental}"  # incremental o full
VERIFY="${2:-false}"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Función de logging
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

# Verificar que Docker está corriendo
if ! docker info >/dev/null 2>&1; then
    log_error "Docker no está corriendo"
    exit 1
fi

# Verificar que docker-compose está disponible
if ! command -v docker compose >/dev/null 2>&1; then
    log_error "docker compose no está disponible"
    exit 1
fi

log "Iniciando backup: $BACKUP_TYPE"
log "Directorio de backups: $BACKUP_DIR"

# Crear directorio para este backup
BACKUP_SESSION_DIR="${BACKUP_DIR}/${TIMESTAMP}"
mkdir -p "$BACKUP_SESSION_DIR"

# Archivo de metadatos del backup
METADATA_FILE="${BACKUP_SESSION_DIR}/metadata.json"

# Función para obtener tamaño de archivo
get_size() {
    if [ -f "$1" ]; then
        du -h "$1" | cut -f1
    else
        echo "0"
    fi
}

# Función para backup de volumen Docker
backup_volume() {
    local VOLUME_NAME=$1
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/${VOLUME_NAME}.tar.gz"
    
    log "Backupeando volumen: $VOLUME_NAME"
    
    # Crear contenedor temporal para backup
    docker run --rm \
        -v "$VOLUME_NAME":/source:ro \
        -v "$BACKUP_SESSION_DIR":/backup \
        alpine:latest \
        tar czf "/backup/${VOLUME_NAME}.tar.gz" -C /source . 2>/dev/null || {
        log_error "Error al hacer backup del volumen $VOLUME_NAME"
        return 1
    }
    
    local SIZE=$(get_size "$BACKUP_FILE")
    log_success "Volumen $VOLUME_NAME: $SIZE"
    return 0
}

# Función para backup de base de datos PostgreSQL
backup_postgres() {
    local DB_NAME="${POSTGRES_DB:-n8n}"
    local DB_USER="${POSTGRES_USER:-postgres}"
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/postgres_${DB_NAME}.sql.gz"
    
    log "Backupeando base de datos PostgreSQL: $DB_NAME"
    
    # Verificar que el contenedor de PostgreSQL está corriendo
    if ! docker compose ps postgres | grep -q "Up"; then
        log_warning "PostgreSQL no está corriendo, omitiendo backup de BD"
        return 0
    fi
    
    docker compose exec -T postgres \
        pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE" || {
        log_error "Error al hacer backup de PostgreSQL"
        return 1
    }
    
    local SIZE=$(get_size "$BACKUP_FILE")
    log_success "PostgreSQL $DB_NAME: $SIZE"
    return 0
}

# Función para backup de configuración
backup_config() {
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/config.tar.gz"
    
    log "Backupeando configuraciones"
    
    tar czf "$BACKUP_FILE" \
        -C "$PROJECT_DIR" \
        docker-compose.yml \
        .env.example \
        monitoring/ \
        modsecurity/ \
        scripts/ \
        --exclude='*.log' \
        --exclude='*.tmp' 2>/dev/null || {
        log_error "Error al hacer backup de configuraciones"
        return 1
    }
    
    local SIZE=$(get_size "$BACKUP_FILE")
    log_success "Configuraciones: $SIZE"
    return 0
}

# Función para verificar integridad
verify_backup() {
    log "Verificando integridad de backups..."
    
    local ERRORS=0
    
    for file in "$BACKUP_SESSION_DIR"/*.tar.gz "$BACKUP_SESSION_DIR"/*.sql.gz; do
        if [ -f "$file" ]; then
            if [[ "$file" == *.tar.gz ]]; then
                if ! gzip -t "$file" 2>/dev/null; then
                    log_error "Archivo corrupto: $(basename "$file")"
                    ((ERRORS++))
                fi
            elif [[ "$file" == *.sql.gz ]]; then
                if ! gzip -t "$file" 2>/dev/null; then
                    log_error "Archivo corrupto: $(basename "$file")"
                    ((ERRORS++))
                fi
            fi
        fi
    done
    
    if [ $ERRORS -eq 0 ]; then
        log_success "Todos los backups están íntegros"
        return 0
    else
        log_error "Se encontraron $ERRORS archivos corruptos"
        return 1
    fi
}

# Función para crear metadatos
create_metadata() {
    local TOTAL_SIZE=$(du -sh "$BACKUP_SESSION_DIR" | cut -f1)
    
    cat > "$METADATA_FILE" <<EOF
{
    "timestamp": "$TIMESTAMP",
    "type": "$BACKUP_TYPE",
    "total_size": "$TOTAL_SIZE",
    "volumes": [
$(docker volume ls --format '{{.Name}}' | grep -E "(n8n|postgres|ollama|qdrant|grafana|prometheus|keycloak)" | while read vol; do
    echo "        \"$vol\""
done | sed '$!s/$/,/')
    ],
    "created_at": "$(date -Iseconds)"
}
EOF
}

# Función para obtener nombre real del volumen (con prefijo del proyecto si existe)
get_volume_name() {
    local VOLUME_BASE=$1
    local PROJECT_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr '_' '-')
    
    # Buscar volumen con prefijo del proyecto primero
    local VOLUME_WITH_PREFIX="${PROJECT_NAME}_${VOLUME_BASE}"
    if docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_WITH_PREFIX}$"; then
        echo "$VOLUME_WITH_PREFIX"
    # Buscar volumen sin prefijo
    elif docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_BASE}$"; then
        echo "$VOLUME_BASE"
    # Buscar cualquier volumen que contenga el nombre
    else
        docker volume ls --format '{{.Name}}' | grep -i "${VOLUME_BASE}" | head -1 || echo ""
    fi
}

# Función principal
main() {
    log "=== Inicio de Backup ==="
    
    # Lista de volúmenes base a respaldar
    # NOTA: ollama_storage se excluye porque los modelos se pueden volver a descargar
    #       y el backup sería muy grande (varios GB) y lento
    VOLUME_BASES=(
        "n8n_storage"
        "postgres_storage"
        # "ollama_storage"  # Excluido: modelos se pueden volver a descargar
        "qdrant_storage"
        "open_webui_storage"
        "grafana_data"
        "prometheus_data"
        "keycloak_data"
    )
    
    local TOTAL_SIZE=0
    local SUCCESS=0
    local FAILED=0
    
    # Backup de volúmenes
    for volume_base in "${VOLUME_BASES[@]}"; do
        local volume_name=$(get_volume_name "$volume_base")
        
        if [ -n "$volume_name" ]; then
            log "Volumen encontrado: $volume_name (buscado: $volume_base)"
            if backup_volume "$volume_name" 2>&1; then
                ((SUCCESS++))
            else
                log_error "Error al hacer backup de $volume_name"
                ((FAILED++))
            fi
        else
            log_warning "Volumen $volume_base no existe, omitiendo"
        fi
    done
    
    # Backup de PostgreSQL
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env" || true
    fi
    if backup_postgres 2>&1; then
        ((SUCCESS++))
    else
        ((FAILED++))
    fi
    
    # Backup de configuraciones
    if backup_config 2>&1; then
        ((SUCCESS++))
    else
        ((FAILED++))
    fi
    
    # Crear metadatos
    create_metadata
    
    # Verificar si se solicita verificación
    if [ "$VERIFY" = "--verify" ] || [ "$VERIFY" = "true" ]; then
        verify_backup || ((FAILED++))
    fi
    
    # Resumen
    log ""
    log "=== Resumen de Backup ==="
    log_success "Backups exitosos: $SUCCESS"
    if [ $FAILED -gt 0 ]; then
        log_error "Backups fallidos: $FAILED"
    fi
    log "Ubicación: $BACKUP_SESSION_DIR"
    log "Tamaño total: $(du -sh "$BACKUP_SESSION_DIR" | cut -f1)"
    log ""
    
    if [ $FAILED -eq 0 ]; then
        log_success "Backup completado exitosamente"
        exit 0
    else
        log_error "Backup completado con errores"
        exit 1
    fi
}

# Ejecutar función principal
main

