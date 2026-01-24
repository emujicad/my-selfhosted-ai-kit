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
    ├── ollama_storage.tar.gz  # Modelos de IA (opcional)
    └── config.tar.gz          # docker-compose.yml, .env.example, config/, haproxy/, monitoring/, modsecurity/, scripts/
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

## 📝 ¿Qué Se Respalda Exactamente?

### ✅ Volúmenes Docker (Datos Críticos)
- ✅ `n8n_storage`: Workflows y datos de n8n
- ✅ `postgres_storage`: Base de datos PostgreSQL
- ✅ `qdrant_storage`: Vectores y embeddings
- ✅ `open_webui_storage`: Configuración de Open WebUI
- ✅ `grafana_data`: Dashboards personalizados y configuración de Grafana
- ✅ `prometheus_data`: Datos históricos de métricas
- ✅ `keycloak_data`: Datos de autenticación y usuarios
- ❌ `ollama_storage`: **Excluido por defecto** (modelos descargables)

### ✅ Base de Datos
- ✅ Dump completo de PostgreSQL (n8n)

### ✅ Configuraciones del Proyecto
- ✅ `docker-compose.yml`: Orquestación de servicios
- ✅ `.env.example`: Plantilla de variables
- ✅ `config/`: Configuración de Open WebUI OIDC y otros
- ✅ `haproxy/`: Configuración del proxy inverso
- ✅ `monitoring/`: Dashboards, alertas, reglas de Prometheus
- ✅ `modsecurity/`: Reglas de WAF
- ✅ `scripts/`: Scripts de gestión del stack

### ❌ Volúmenes Excluidos (Datos Regenerables)

Estos volúmenes **NO se respaldan** porque contienen datos temporales o regenerables:

#### `ollama_storage` (Modelos IA)
- **Por qué se excluye**: Los modelos se pueden volver a descargar
- **Beneficio**: Ahorra decenas de GB de espacio
- **Cómo recuperar**: `ollama pull <modelo>`
- **Para incluirlo**: Edita `scripts/backup-manager.sh` y descomenta la línea

#### Volúmenes Temporales
- `ssl_certs_data`: Certificados auto-generados (se regeneran)
- `logs_data`: Logs operacionales (temporales)
- `prometheus_rules_data`: Reglas derivadas de `monitoring/` (regenerables)
- `grafana_provisioning_data`: Dashboards desde `monitoring/grafana/` (regenerables)

### 📋 Notas Importantes

1. **Retención**: Considera implementar rotación de backups antiguos
2. **Ubicación**: Los backups se guardan localmente en `backups/`
3. **Seguridad**: Los backups contienen datos sensibles (.env, contraseñas, tokens)
4. **Configuraciones bind mount**: `monitoring/`, `haproxy/`, `modsecurity/` están incluidas en config.tar.gz

---

**Última actualización**: 2026-01-24


