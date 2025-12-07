# 💾 Guía de Backup y Restauración

## 📋 Scripts Disponibles

### 1. `scripts/backup.sh` - Crear Backup

Realiza backups de volúmenes Docker, bases de datos y configuraciones.

**Uso básico:**
```bash
./scripts/backup.sh
```

**Opciones:**
```bash
# Backup completo (no incremental)
./scripts/backup.sh --full

# Backup con verificación de integridad
./scripts/backup.sh --verify

# Backup completo con verificación
./scripts/backup.sh --full --verify
```

**Qué respalda:**
- ✅ Volúmenes Docker (n8n, postgres, qdrant, grafana, etc.)
- ✅ Base de datos PostgreSQL
- ✅ Configuraciones (docker-compose.yml, monitoring/, scripts/)
- ❌ **ollama_storage se EXCLUYE** (los modelos se pueden volver a descargar con `ollama pull`)

**Ubicación de backups:**
- `backups/YYYYMMDD-HHMMSS/`

### 2. `scripts/restore.sh` - Restaurar Backup

Restaura un backup específico.

**Uso:**
```bash
# Listar backups disponibles
./scripts/list-backups.sh

# Restaurar un backup específico
./scripts/restore.sh 20251207-140000
```

**⚠️ Advertencia:**
- La restauración reemplazará datos existentes
- Asegúrate de tener un backup reciente antes de restaurar

### 3. `scripts/list-backups.sh` - Listar Backups

Muestra todos los backups disponibles con información detallada.

**Uso:**
```bash
./scripts/list-backups.sh
```

## 🔄 Flujo de Trabajo Recomendado

### Backup Regular
```bash
# Backup diario (agregar a cron)
0 2 * * * cd /ruta/al/proyecto && ./scripts/backup.sh --verify
```

### Antes de Cambios Importantes
```bash
# Crear backup completo antes de cambios
./scripts/backup.sh --full --verify
```

### Restauración
```bash
# 1. Listar backups disponibles
./scripts/list-backups.sh

# 2. Detener servicios (opcional pero recomendado)
docker compose down

# 3. Restaurar backup específico
./scripts/restore.sh 20251207-140000

# 4. Reiniciar servicios
docker compose up -d
```

## 📊 Estructura de Backups

```
backups/
└── 20251207-140000/
    ├── metadata.json          # Metadatos del backup
    ├── n8n_storage.tar.gz     # Volumen n8n
    ├── postgres_storage.tar.gz # Volumen PostgreSQL
    ├── postgres_n8n.sql.gz    # Dump de base de datos
    ├── ollama_storage.tar.gz  # Modelos de IA
    └── config.tar.gz          # Configuraciones
```

## 🔍 Verificación de Integridad

Los backups incluyen verificación automática cuando usas `--verify`:

```bash
./scripts/backup.sh --verify
```

Esto verifica que todos los archivos comprimidos no estén corruptos.

## ⚙️ Configuración

Los scripts leen variables de entorno desde `.env` si existe:
- `POSTGRES_USER` - Usuario de PostgreSQL
- `POSTGRES_DB` - Nombre de base de datos

## 🚨 Troubleshooting

### Error: "Docker no está corriendo"
```bash
# Verificar estado de Docker
docker info
```

### Error: "Volumen no existe"
- Algunos volúmenes pueden no existir si no se han usado
- El script omite volúmenes inexistentes automáticamente

### Error: "PostgreSQL no está corriendo"
- Inicia PostgreSQL antes de restaurar:
```bash
docker compose up -d postgres
```

## 📝 Notas Importantes

1. **Espacio en disco**: Los backups ahora son más pequeños al excluir `ollama_storage`
2. **Modelos de IA**: Los modelos en `ollama_storage` NO se respaldan porque:
   - Se pueden volver a descargar fácilmente con `ollama pull <modelo>`
   - Son muy grandes (varios GB cada uno)
   - El backup sería muy lento
3. **Retención**: Considera implementar rotación de backups antiguos
4. **Ubicación**: Los backups se guardan localmente en `backups/`
5. **Seguridad**: Los backups contienen datos sensibles, protégelos adecuadamente

---

**Última actualización**: 2025-12-07

