#!/bin/bash

# =============================================================================
# Script Consolidado: Gestión de Backups - My Self-Hosted AI Kit
# =============================================================================
# Este script consolida la gestión de backups: crear, restaurar y listar
# Reemplaza: backup.sh, restore.sh, list-backups.sh
# =============================================================================

set -uo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Asegurar que estamos en el directorio del proyecto
cd "$PROJECT_DIR"
BACKUP_DIR="${PROJECT_DIR}/backups"

# Funciones de logging
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

# Función de ayuda
show_help() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}Gestor de Backups - My Self-Hosted AI Kit${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
    echo ""
    echo "USO:"
    echo "    ./scripts/backup-manager.sh [COMANDO] [OPCIONES]"
    echo ""
    echo "COMANDOS:"
    echo "    backup [--full] [--verify]"
    echo "                          Crear backup de volúmenes y bases de datos"
    echo "                          --full    : Backup completo (no incremental)"
    echo "                          --verify  : Verificar integridad después del backup"
    echo ""
    echo "    restore <timestamp>   Restaurar backup desde un timestamp específico"
    echo "                          Ejemplo: restore 20251207-140000"
    echo ""
    echo "    list                  Listar backups disponibles"
    echo ""
    echo "    help                  Mostrar esta ayuda"
    echo ""
    echo "EJEMPLOS:"
    echo "    ./scripts/backup-manager.sh backup"
    echo "    ./scripts/backup-manager.sh backup --full --verify"
    echo "    ./scripts/backup-manager.sh restore 20251207-140000"
    echo "    ./scripts/backup-manager.sh list"
    echo ""
}

# Verificar Docker
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker no está corriendo"
        exit 1
    fi
    
    if ! command -v docker compose >/dev/null 2>&1; then
        log_error "docker compose no está disponible"
        exit 1
    fi
}

# Función para obtener tamaño de archivo
get_size() {
    if [ -f "$1" ]; then
        du -h "$1" | cut -f1
    else
        echo "0"
    fi
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

# Función para backup de volumen Docker
backup_volume() {
    local VOLUME_NAME=$1
    local BACKUP_SESSION_DIR=$2
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/${VOLUME_NAME}.tar.gz"
    
    log "Backupeando volumen: $VOLUME_NAME"
    
    # Calcular ruta del host para DooD (si aplica)
    local HOST_SESSION_DIR="$BACKUP_SESSION_DIR"
    if [ -n "${HOST_BACKUP_PATH:-}" ]; then
        HOST_SESSION_DIR="${HOST_BACKUP_PATH}/$(basename "$BACKUP_SESSION_DIR")"
    fi
    
    # Crear contenedor temporal para backup
    docker run --rm \
        -v "$VOLUME_NAME":/source:ro \
        -v "$HOST_SESSION_DIR":/backup \
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
    local BACKUP_SESSION_DIR=$1
    local DB_NAME="${POSTGRES_DB}"
    local DB_USER="${POSTGRES_USER}"
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/postgres_${DB_NAME}.sql.gz"
    
    log "Backupeando base de datos PostgreSQL: $DB_NAME"
    
    # Verificar que el contenedor de PostgreSQL está corriendo
    if ! docker ps --filter "name=${DB_POSTGRESDB_HOST}" --format '{{.Status}}' | grep -q "Up"; then
        log_warning "PostgreSQL no está corriendo, omitiendo backup de BD"
        return 0
    fi
    
    # Obtener nombre real del contenedor (puede tener prefijo)
    local PG_CONTAINER=$(docker ps --filter "name=${DB_POSTGRESDB_HOST}" --format '{{.Names}}' | head -1)

    docker exec "$PG_CONTAINER" \
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
    local BACKUP_SESSION_DIR=$1
    local BACKUP_FILE="${BACKUP_SESSION_DIR}/config.tar.gz"
    
    log "Backupeando configuraciones"
    
    tar czf "$BACKUP_FILE" \
        -C "$PROJECT_DIR" \
        docker-compose.yml \
        .env.example \
        config/ \
        haproxy/ \
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
    local BACKUP_SESSION_DIR=$1
    log "Verificando integridad de backups..."
    
    local ERRORS=0
    
    for file in "$BACKUP_SESSION_DIR"/*.tar.gz "$BACKUP_SESSION_DIR"/*.sql.gz; do
        if [ -f "$file" ]; then
            if ! gzip -t "$file" 2>/dev/null; then
                log_error "Archivo corrupto: $(basename "$file")"
                ((ERRORS++))
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
    local BACKUP_SESSION_DIR=$1
    local TIMESTAMP=$2
    local BACKUP_TYPE=$3
    local METADATA_FILE="${BACKUP_SESSION_DIR}/metadata.json"
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

# Comando: Crear backup
cmd_backup() {
    local BACKUP_TYPE="incremental"
    local VERIFY_BACKUP=false
    
    # Parsear opciones
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                BACKUP_TYPE="full"
                shift
                ;;
            --verify)
                VERIFY_BACKUP=true
                shift
                ;;
            *)
                log_error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    check_docker
    
    log "=== Inicio de Backup ==="
    log "Tipo: $BACKUP_TYPE"
    
    # Crear directorio de backups si no existe
    mkdir -p "$BACKUP_DIR"
    
    # Crear directorio para este backup
    local TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    local BACKUP_SESSION_DIR="${BACKUP_DIR}/${TIMESTAMP}"
    mkdir -p "$BACKUP_SESSION_DIR"
    
    # Cargar variables de entorno si existen
    if [ -f "${PROJECT_DIR}/.env" ]; then
        source "${PROJECT_DIR}/.env" || true
    fi
    
    # Lista de volúmenes base a respaldar
    # NOTA: ollama_storage se excluye porque los modelos se pueden volver a descargar
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
    
    local SUCCESS=0
    local FAILED=0
    
    # Backup de volúmenes
    for volume_base in "${VOLUME_BASES[@]}"; do
        local volume_name=$(get_volume_name "$volume_base")
        
        if [ -n "$volume_name" ]; then
            log "Volumen encontrado: $volume_name (buscado: $volume_base)"
            if backup_volume "$volume_name" "$BACKUP_SESSION_DIR" 2>&1; then
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
    if backup_postgres "$BACKUP_SESSION_DIR" 2>&1; then
        ((SUCCESS++))
    else
        ((FAILED++))
    fi
    
    # Backup de configuraciones
    if backup_config "$BACKUP_SESSION_DIR" 2>&1; then
        ((SUCCESS++))
    else
        ((FAILED++))
    fi
    
    # Crear metadatos
    create_metadata "$BACKUP_SESSION_DIR" "$TIMESTAMP" "$BACKUP_TYPE"
    
    # Verificar si se solicita verificación
    if [ "$VERIFY_BACKUP" = true ]; then
        verify_backup "$BACKUP_SESSION_DIR" || ((FAILED++))
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
        log "Timestamp: $TIMESTAMP"
        exit 0
    else
        log_error "Backup completado con errores"
        exit 1
    fi
}

# Función para restaurar volumen
restore_volume() {
    local VOLUME_NAME=$1
    local BACKUP_SESSION_DIR=$2
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
    local BACKUP_SESSION_DIR=$1
    local DB_NAME="${POSTGRES_DB}"
    local DB_USER="${POSTGRES_USER}"
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

# Comando: Restaurar backup
cmd_restore() {
    shift  # Remover "restore"
    
    if [ $# -eq 0 ]; then
        log_error "Debes especificar el timestamp del backup a restaurar"
        echo ""
        echo "Backups disponibles:"
        ls -1 "$BACKUP_DIR" 2>/dev/null | grep -E "^[0-9]{8}-[0-9]{6}$" || echo "  (ninguno)"
        echo ""
        echo "Uso: $0 restore <timestamp>"
        echo "Ejemplo: $0 restore 20251207-140000"
        exit 1
    fi
    
    local TIMESTAMP=$1
    local BACKUP_SESSION_DIR="${BACKUP_DIR}/${TIMESTAMP}"
    
    # Verificar que el backup existe
    if [ ! -d "$BACKUP_SESSION_DIR" ]; then
        log_error "Backup no encontrado: $BACKUP_SESSION_DIR"
        exit 1
    fi
    
    check_docker
    
    log_warning "⚠️  ADVERTENCIA: Esta operación reemplazará datos existentes"
    log_warning "⚠️  Asegúrate de tener un backup reciente antes de continuar"
    echo ""
    read -p "¿Continuar con la restauración? (escribe 'si' para confirmar): " CONFIRM
    
    if [ "$CONFIRM" != "si" ]; then
        log "Restauración cancelada"
        exit 0
    fi
    
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
        if restore_volume "$volume" "$BACKUP_SESSION_DIR"; then
            ((SUCCESS++))
        else
            ((FAILED++))
        fi
    done
    
    # Restaurar PostgreSQL
    restore_postgres "$BACKUP_SESSION_DIR" || ((FAILED++))
    
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

# Comando: Listar backups
cmd_list() {
    echo -e "${BLUE}=== Backups Disponibles ===${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "No hay backups disponibles"
        exit 0
    fi
    
    for backup_dir in "$BACKUP_DIR"/*/; do
        if [ -d "$backup_dir" ]; then
            timestamp=$(basename "$backup_dir")
            if [[ "$timestamp" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
                size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
                date_str=$(echo "$timestamp" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)-\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
                
                echo -e "${GREEN}$timestamp${NC} - $date_str - Tamaño: $size"
                
                # Mostrar archivos en el backup
                if [ -f "${backup_dir}metadata.json" ]; then
                    echo "  📄 Metadatos disponibles"
                fi
                
                file_count=$(find "$backup_dir" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" \) | wc -l)
                echo "  📦 Archivos: $file_count"
                echo ""
            fi
        fi
    done
}

# Main logic
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

COMMAND=$1

case "$COMMAND" in
    backup)
        cmd_backup "$@"
        ;;
    restore)
        cmd_restore "$@"
        ;;
    list)
        cmd_list
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Comando no válido: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac

