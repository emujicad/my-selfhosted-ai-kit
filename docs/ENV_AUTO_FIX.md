# 🔧 Corrección Automática de Variables de .env

## 📋 Descripción

La corrección de variables de `.env` que necesitan comillas ahora es **automática y transparente**. Ya no necesitas ejecutar un script separado.

## ✅ ¿Qué hace automáticamente?

Cuando ejecutas `./scripts/stack-manager.sh start` o `./scripts/stack-manager.sh validate`, el sistema:

1. **Verifica automáticamente** si hay variables en `.env` que necesitan comillas
2. **Corrige automáticamente** cualquier problema encontrado:
   - Variables `*_SCOPES` con espacios sin comillas
   - Variable `WATCHTOWER_SCHEDULE` con espacios sin comillas
3. **Crea un backup** automáticamente antes de modificar
4. **Informa** qué corrigió (solo si corrigió algo)
5. **Continúa** con la validación normalmente

## 🎯 Comportamiento

### Si NO hay problemas:
- ✅ **Silencioso**: No muestra nada, simplemente continúa
- ✅ **Rápido**: No retrasa la validación

### Si HAY problemas:
- 🔧 Muestra: "✅ Archivo .env corregido automáticamente (X variables):"
- 📋 Lista qué corrigió:
  - "• N8N_OIDC_SCOPES"
  - "• OPEN_WEBUI_OAUTH_SCOPES"
  - "• GRAFANA_OAUTH_SCOPES"
  - "• JENKINS_OIDC_SCOPES"
  - "• WATCHTOWER_SCHEDULE"
- 💾 Muestra: "Backup guardado en: .env.backup.YYYYMMDD_HHMMSS"
- ✅ Continúa con la validación normalmente

## 📝 Ejemplo de Uso

```bash
# Validar (corrección automática incluida)
./scripts/stack-manager.sh validate

# O al levantar servicios (corrección automática incluida)
./scripts/stack-manager.sh start

# Si hay problemas, verás:
# ✅ Archivo .env corregido automáticamente (3 variables):
#    • N8N_OIDC_SCOPES
#    • OPEN_WEBUI_OAUTH_SCOPES
#    • GRAFANA_OAUTH_SCOPES
#    Backup guardado en: .env.backup.20250107_123456
```

## 🆚 Comparación: Antes vs Ahora

### ❌ Antes (Manual)
```bash
# 1. Detectar errores al hacer source .env
source .env
# profile: command not found
# email: command not found

# 2. Editar .env manualmente para agregar comillas
nano .env

# 3. Validar
./scripts/stack-manager.sh validate
```

### ✅ Ahora (Automático)
```bash
# Solo esto:
./scripts/stack-manager.sh validate
# O simplemente:
./scripts/stack-manager.sh start
# Todo se hace automáticamente, transparente para el usuario
```

## 🛠️ Corrección Manual (Si Necesitas)

Si necesitas corregir manualmente, puedes editar directamente el archivo `.env`:

```bash
# Editar .env manualmente
nano .env

# Agregar comillas a variables con espacios:
# ❌ Antes: N8N_OIDC_SCOPES=openid profile email
# ✅ Después: N8N_OIDC_SCOPES="openid profile email"
```

Pero **normalmente no es necesario** - la corrección es automática.

## ⚙️ Configuración

La corrección automática está integrada en `stack-manager.sh` y se ejecuta:
- **Antes de validar** variables de entorno (en `validate_before_start`)
- **Automáticamente** cuando ejecutas `validate` o `start`

No requiere configuración adicional.

## 🔍 Qué Verifica

1. **Variables SCOPES sin comillas**: `N8N_OIDC_SCOPES=openid profile email` (sin comillas)
2. **WATCHTOWER_SCHEDULE sin comillas**: `WATCHTOWER_SCHEDULE=0 0 2 * * *` (sin comillas)

## ✅ Qué Corrige

1. **Agrega comillas** a variables con espacios
2. **Crea backup** automáticamente antes de modificar
3. **Informa** qué corrigió

## 🛡️ Seguridad

- ✅ Crea backup automáticamente antes de modificar
- ✅ Solo corrige variables específicas conocidas
- ✅ No modifica otras variables
- ✅ Silencioso si no hay problemas (no molesta)

## 📊 Ventajas

1. **Transparente**: El usuario no necesita saber que existe
2. **Automático**: Se ejecuta solo cuando es necesario
3. **Rápido**: No retrasa la validación si no hay problemas
4. **Informativo**: Muestra qué corrigió si hubo problemas
5. **Seguro**: Crea backup antes de modificar

## 🔄 Restaurar Backup

Si algo sale mal, puedes restaurar el backup:

```bash
# Listar backups disponibles
ls -la .env.backup.*

# Restaurar un backup específico
cp .env.backup.20250107_123456 .env
```

---

**Última actualización**: 2025-01-07

