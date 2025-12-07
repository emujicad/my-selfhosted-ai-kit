#!/bin/bash

# =============================================================================
# Script para Listar Backups - My Self-Hosted AI Kit
# =============================================================================
# Muestra información sobre los backups disponibles
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

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

