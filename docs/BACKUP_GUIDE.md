# 💾 Guía de Backup y Restauración

## 📋 Script Consolidado: `scripts/backup-manager.sh`

Este script consolida todas las operaciones de backup en un solo comando con subcomandos.

### Comandos Disponibles

#### 1. Crear Backup

Realiza backups de volúmenes Docker, bases de datos y configuraciones.

**Uso básico:**
```bash
./scripts/backup-manager.sh backup
```

**Opciones:**
```bash
# Backup completo (no incremental)
./scripts/backup-manager.sh backup --full

# Backup con verificación de integridad
./scripts/backup-manager.sh backup --verify

# Backup completo con verificación
./scripts/backup-manager.sh backup --full --verify
```

**Qué respalda:**
- ✅ Volúmenes Docker (n8n, postgres, qdrant, grafana, etc.)
- ✅ Base de datos PostgreSQL
- ✅ Configuraciones (docker-compose.yml, monitoring/, scripts/)
- ❌ **ollama_storage se EXCLUYE** (los modelos se pueden volver a descargar con `ollama pull`)

**Ubicación de backups:**
- `backups/YYYYMMDD-HHMMSS/`

#### 2. Restaurar Backup

Restaura un backup específico.

**Uso:**
```bash
# Listar backups disponibles primero
./scripts/backup-manager.sh list

# Restaurar un backup específico
./scripts/backup-manager.sh restore 20251207-140000
```

**⚠️ Advertencia:**
- La restauración reemplazará datos existentes
- Asegúrate de tener un backup reciente antes de restaurar
- Requiere confirmación escribiendo 'si'

#### 3. Listar Backups

Muestra todos los backups disponibles con información detallada.

**Uso:**
```bash
./scripts/backup-manager.sh list
```

**Ayuda:**
```bash
./scripts/backup-manager.sh help
```

## 🔄 Flujo de Trabajo Recomendado

### Backup Regular
```bash
# Backup diario (agregar a cron)
0 2 * * * cd /ruta/al/proyecto && ./scripts/backup-manager.sh backup --verify
```

### Antes de Cambios Importantes
```bash
# Crear backup completo antes de cambios
./scripts/backup-manager.sh backup --full --verify
```

### Restauración
```bash
# 1. Listar backups disponibles
./scripts/backup-manager.sh list

# 2. Detener servicios (opcional pero recomendado)
docker compose down

# 3. Restaurar backup específico
./scripts/backup-manager.sh restore 20251207-140000

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
./scripts/backup-manager.sh backup --verify
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


## 📦 Nuevos Volúmenes de Persistencia

### Volúmenes Agregados para Mejorar Persistencia

#### 1. `ssl_certs_data` - Certificados SSL/TLS
**Propósito**: Almacenar certificados SSL/TLS generados automáticamente o por Let's Encrypt.

**Contenido**:
- Certificados generados automáticamente
- Claves privadas
- Certificados intermedios

**Uso**: Montar en servicios que necesiten certificados SSL/TLS.

#### 2. `logs_data` - Logs Consolidados
**Propósito**: Centralizar logs de todos los servicios para análisis y auditoría.

**Contenido**:
- Logs consolidados de servicios
- Logs de acceso
- Logs de errores

**Uso**: Para análisis centralizado de logs y auditoría.

#### 3. `prometheus_rules_data` - Reglas Personalizadas de Prometheus
**Propósito**: Almacenar reglas de alertas personalizadas que persistan independientemente del proyecto.

**Contenido**:
- Reglas de alertas personalizadas (`.yml`)
- Configuraciones de alertas específicas del usuario

**Uso**: Montar en `/etc/prometheus/rules/custom/` para reglas personalizadas.

#### 4. `grafana_provisioning_data` - Dashboards Personalizados de Grafana
**Propósito**: Almacenar dashboards personalizados creados por usuarios.

**Contenido**:
- Dashboards JSON personalizados
- Configuraciones de dashboards específicas

**Uso**: Complementa los dashboards provisionados desde el proyecto.

### ⚠️ Nota sobre Configuraciones Existentes

Las configuraciones en bind mounts (`./monitoring/`, `./haproxy/`, `./modsecurity/`) están montadas directamente desde el proyecto. Estas configuraciones:

- ✅ Son fáciles de editar durante desarrollo
- ⚠️ Se pierden si se borra el proyecto
- ✅ Están incluidas en los backups automáticos

**Recomendación**: Ejecutar `./scripts/backup-manager.sh backup` regularmente para respaldar estas configuraciones.
