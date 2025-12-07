# 🚀 Guía del Stack Manager

## 📋 Descripción

`scripts/stack-manager.sh` es el script maestro para gestionar el stack completo de servicios Docker Compose con diferentes perfiles y combinaciones.

## 🎯 Características Principales

- ✅ Gestión simplificada de perfiles Docker Compose
- ✅ Presets predefinidos para casos comunes
- ✅ Validación automática antes de levantar servicios
- ✅ Integración con scripts de validación existentes
- ✅ Información de servicios y URLs disponibles
- ✅ Monitoreo de descarga de modelos

## 📖 Uso Básico

### Levantar servicios (preset por defecto)

```bash
./scripts/stack-manager.sh start
```

Esto levanta automáticamente:
- `gpu-nvidia` (Ollama con GPU NVIDIA)
- `monitoring` (Prometheus, Grafana, AlertManager)
- `infrastructure` (Redis, HAProxy)
- `security` (Keycloak, ModSecurity)

### Levantar con perfiles específicos

```bash
./scripts/stack-manager.sh start gpu-nvidia monitoring
```

### Usar presets

```bash
# Desarrollo
./scripts/stack-manager.sh start dev

# Producción completa
./scripts/stack-manager.sh start production

# Stack completo (todos los perfiles)
./scripts/stack-manager.sh start full
```

## 🔧 Comandos Disponibles

### `start [perfiles...]`
Levanta servicios con los perfiles especificados. Si no se especifican perfiles, usa el preset `default`.

**Ejemplos:**
```bash
./scripts/stack-manager.sh start
./scripts/stack-manager.sh start gpu-nvidia monitoring infrastructure
./scripts/stack-manager.sh start dev
```

### `stop [perfiles...]`
Detiene servicios con los perfiles especificados. Si no se especifican perfiles, detiene todos.

**Ejemplos:**
```bash
./scripts/stack-manager.sh stop
./scripts/stack-manager.sh stop monitoring security
```

### `restart [perfiles...]`
Reinicia servicios con los perfiles especificados.

**Ejemplos:**
```bash
./scripts/stack-manager.sh restart
./scripts/stack-manager.sh restart grafana prometheus
```

### `status`
Muestra el estado de todos los servicios.

```bash
./scripts/stack-manager.sh status
```

### `info`
Muestra información de URLs y servicios disponibles según los perfiles activos.

```bash
./scripts/stack-manager.sh info
```

### `logs [servicio]`
Muestra logs de servicios. Si no se especifica servicio, muestra logs de todos.

```bash
./scripts/stack-manager.sh logs
./scripts/stack-manager.sh logs prometheus
./scripts/stack-manager.sh logs grafana
```

### `validate`
Valida la configuración antes de levantar servicios (variables de entorno y configuración).

```bash
./scripts/stack-manager.sh validate
```

### `auto-validate`
Ejecuta una validación completa automática que incluye:
- Verificación de variables de entorno (CRÍTICO)
- Validación estática de configuración
- Levantamiento de servicios Docker
- Verificación de servicios corriendo

```bash
./scripts/stack-manager.sh auto-validate
```

### `test`
Prueba cambios recientes en servicios (ModSecurity, Prometheus, etc.), verificando que funcionen correctamente.

```bash
./scripts/stack-manager.sh test
```

### `init-volumes`
Inicializa volúmenes de configuración copiando archivos iniciales a los volúmenes persistentes.

**Nota:** Docker Compose crea volúmenes automáticamente cuando levantas servicios. Este comando es **opcional** y solo se usa para copiar configuraciones iniciales (útil para primera vez o cuando necesitas resetear configuraciones).

```bash
./scripts/stack-manager.sh init-volumes
```

### `monitor`
Monitorea la descarga de modelos Ollama (usa `scripts/verifica_modelos.sh`).

```bash
./scripts/stack-manager.sh monitor
```

### `help`
Muestra la ayuda completa.

```bash
./scripts/stack-manager.sh help
```

## 📊 Presets Disponibles

### `default`
**Perfiles:** `gpu-nvidia` + `monitoring` + `infrastructure` + `security`

**Uso:** Configuración recomendada para producción con GPU NVIDIA.

```bash
./scripts/stack-manager.sh start
# o explícitamente:
./scripts/stack-manager.sh start default
```

### `minimal`
**Perfiles:** Ninguno (solo servicios base)

**Uso:** Solo servicios esenciales sin perfiles adicionales.

```bash
./scripts/stack-manager.sh start minimal
```

### `dev`
**Perfiles:** `cpu` + `dev` + `testing`

**Uso:** Desarrollo sin GPU, con herramientas de desarrollo y testing.

```bash
./scripts/stack-manager.sh start dev
```

### `production`
**Perfiles:** `gpu-nvidia` + `monitoring` + `infrastructure` + `security` + `automation`

**Uso:** Producción completa con automatización.

```bash
./scripts/stack-manager.sh start production
```

### `full`
**Perfiles:** Todos los perfiles disponibles

**Uso:** Stack completo con todos los servicios (¡cuidado con recursos!).

```bash
./scripts/stack-manager.sh start full
```

## 🔄 Integración con Scripts Existentes

El script integra las siguientes funcionalidades de scripts existentes:

### ✅ Integrados

1. **`verify-env-variables.sh`**
   - Se ejecuta automáticamente en `validate` y antes de `start`
   - Verifica que las variables críticas de `.env` estén configuradas

2. **`validate-config.sh`**
   - Se ejecuta automáticamente en `validate` y antes de `start`
   - Valida la configuración de archivos (ModSecurity, Prometheus, etc.)

3. **`scripts/verifica_modelos.sh`**
   - Se ejecuta con el comando `monitor`
   - Monitorea la descarga de modelos Ollama

### ✅ Integrados en stack-manager.sh

Los siguientes scripts están integrados como comandos en `stack-manager.sh`:

- **`verify-env-variables.sh`** → `validate` (verificación de variables críticas)
- **`validate-config.sh`** → `validate` (validación estática de configuración)
- **`verifica_modelos.sh`** → `monitor` (monitoreo de descarga de modelos)
- **`auto-validate.sh`** → `auto-validate` (validación completa automática)
- **`test-changes.sh`** → `test` (prueba de cambios recientes)
- **`init-config-volumes.sh`** → `init-volumes` (inicialización de volúmenes)

**Nota sobre volúmenes:** Docker Compose crea volúmenes automáticamente cuando levantas servicios. El comando `init-volumes` es **opcional** y solo se usa para copiar configuraciones iniciales a los volúmenes (útil para primera vez o cuando necesitas resetear configuraciones).

### 📦 Mantenidos Separados

Los siguientes scripts se mantienen separados porque tienen funcionalidades específicas:

- **`backup-manager.sh`** - Gestión consolidada de backups (crear, restaurar, listar) - Reemplaza `backup.sh`, `restore.sh` y `list-backups.sh`
- **`keycloak-manager.sh`** - Gestión completa de Keycloak (setup, verify, fix, credentials, create-user, init-db, status) - Reemplaza `setup-keycloak.sh`, `show-keycloak-credentials.sh` y `create-keycloak-user.sh`

## 🎯 Flujo de Trabajo Recomendado

### Primera vez / Después de cambios en configuración

```bash
# 1. Validar configuración
./scripts/stack-manager.sh validate

# 2. Si hay errores, corregirlos y volver a validar

# 3. Levantar servicios
./scripts/stack-manager.sh start

# 4. Verificar estado
./scripts/stack-manager.sh status

# 5. Ver información de servicios
./scripts/stack-manager.sh info
```

### Desarrollo

```bash
# Levantar stack de desarrollo
./scripts/stack-manager.sh start dev

# Ver logs mientras desarrollas
./scripts/stack-manager.sh logs

# Reiniciar después de cambios
./scripts/stack-manager.sh restart
```

### Producción

```bash
# Levantar stack de producción
./scripts/stack-manager.sh start production

# Monitorear servicios
./scripts/stack-manager.sh status
./scripts/stack-manager.sh logs prometheus
```

## ⚠️ Notas Importantes

1. **Validación Automática**: El comando `start` ejecuta validación automáticamente antes de levantar servicios. Si hay errores críticos, aborta.

2. **Preset por Defecto**: Si no especificas perfiles, se usa el preset `default` que incluye GPU NVIDIA, monitoreo, infraestructura y seguridad.

3. **Combinación de Perfiles**: Puedes combinar múltiples perfiles libremente:
   ```bash
   ./scripts/stack-manager.sh start gpu-nvidia monitoring security
   ```

4. **Presets vs Perfiles**: Los presets son combinaciones predefinidas de perfiles. Puedes usar tanto presets como perfiles individuales.

5. **Servicios Base**: Los servicios sin perfil (postgres, n8n, open-webui, qdrant) siempre se levantan cuando ejecutas `start`.

## 🔍 Troubleshooting

### Error: "Docker no está disponible"
- Verifica que Docker esté corriendo: `docker ps`
- Si necesitas sudo, el script lo detecta automáticamente

### Error: "Validación falló"
- Ejecuta `./scripts/stack-manager.sh validate` para ver errores detallados
- Corrige las variables en `.env` según los mensajes de error
- Vuelve a validar antes de levantar servicios

### Los servicios no levantan
- Verifica el estado: `./scripts/stack-manager.sh status`
- Revisa los logs: `./scripts/stack-manager.sh logs [servicio]`
- Verifica que los puertos no estén en uso

## 📚 Scripts Relacionados

Para más información sobre funcionalidades específicas:

- **Backups**: Ver `docs/BACKUP_GUIDE.md`
- **Validación**: Ver `docs/VALIDATION_GUIDE.md`
- **Keycloak**: Ver `docs/KEYCLOAK_INTEGRATION_PLAN.md`
- **Monitoreo**: Ver `docs/GRAFANA_MONITORING_GUIDE.md`

