# 🔧 Corrección Automática de Base de Datos de Keycloak

## 📋 Descripción

La corrección de problemas de base de datos de Keycloak ahora es **automática y transparente**. Ya no necesitas ejecutar un script separado.

## ✅ ¿Qué hace automáticamente?

Cuando ejecutas `./scripts/stack-manager.sh start` con el perfil `security`, el sistema:

1. **Verifica automáticamente** si hay problemas en la base de datos de Keycloak
2. **Corrige automáticamente** cualquier problema encontrado:
   - Transacciones pendientes
   - Locks antiguos en `databasechangeloglock`
   - Conexiones huérfanas
3. **Informa** qué corrigió (solo si corrigió algo)
4. **Continúa** levantando Keycloak normalmente

## 🎯 Comportamiento

### Si NO hay problemas:
- ✅ **Silencioso**: No muestra nada, simplemente continúa
- ✅ **Rápido**: No retrasa el inicio

### Si HAY problemas:
- 🔧 Muestra: "🔧 Verificando base de datos de Keycloak..."
- ✅ Muestra: "✅ Base de datos de Keycloak corregida automáticamente:"
- 📋 Lista qué corrigió:
  - "• Terminadas X transacciones pendientes"
  - "• Terminadas X conexiones con locks antiguos"
  - "• Limpiada tabla databasechangeloglock"
- ✅ Continúa levantando Keycloak normalmente

## 📝 Ejemplo de Uso

```bash
# Levantar con perfil security (corrección automática incluida)
./scripts/stack-manager.sh start security

# O con preset default (incluye security)
./scripts/stack-manager.sh start

# Si hay problemas, verás:
# 🔧 Verificando base de datos de Keycloak...
# ✅ Base de datos de Keycloak corregida automáticamente:
#    • Terminadas 2 transacciones pendientes
#    • Limpiada tabla databasechangeloglock
```

## 🔄 También en Stop

Cuando detienes servicios con el perfil `security`, el sistema también limpia transacciones muy antiguas (más de 10 minutos) para prevenir problemas en el próximo inicio.

```bash
# Detener servicios (limpieza preventiva automática)
./scripts/stack-manager.sh stop security
```

## 🆚 Comparación: Antes vs Ahora

### ❌ Antes (Manual)
```bash
# 1. Detectar problema
# 2. Ejecutar script manualmente
./scripts/keycloak-manager.sh fix-db
# 3. Responder "s" para limpiar
# 4. Levantar servicios
./scripts/stack-manager.sh start security
```

### ✅ Ahora (Automático)
```bash
# Solo esto:
./scripts/stack-manager.sh start security
# Todo se hace automáticamente, transparente para el usuario
```

## 🛠️ Script Manual (Opcional)

Para diagnóstico detallado, puedes usar:

```bash
# Diagnóstico detallado con opción de limpiar manualmente
./scripts/stack-manager.sh diagnose keycloak-db

# O usando el wrapper de keycloak-manager
./scripts/keycloak-manager.sh fix-db
```

Esto mostrará información detallada sobre conexiones, transacciones y locks, y te permitirá decidir si limpiar manualmente.

**Nota**: La corrección automática en `start` es suficiente para el funcionamiento normal.

## ⚙️ Configuración

La corrección automática está integrada en `stack-manager.sh` y se ejecuta:
- **Antes de levantar** servicios con perfil `security`
- **Antes de detener** servicios con perfil `security` (limpieza preventiva)

No requiere configuración adicional.

## 🔍 Qué Verifica

1. **Transacciones pendientes**: `idle in transaction` o `idle in transaction (aborted)`
2. **Locks antiguos**: Locks en `databasechangeloglock` con más de 5 minutos
3. **Locks colgados**: Locks en la tabla `databasechangeloglock` que están activos pero son antiguos

## ✅ Qué Corrige

1. **Termina transacciones pendientes** de forma segura
2. **Termina conexiones con locks antiguos** (más de 5 minutos)
3. **Limpia la tabla `databasechangeloglock`** directamente si hay locks colgados

## 🛡️ Seguridad

- ✅ Solo corrige problemas reales (verifica antes de corregir)
- ✅ No toca conexiones activas recientes
- ✅ No borra datos, solo cierra conexiones y limpia locks
- ✅ Silencioso si no hay problemas (no molesta)

## 📊 Ventajas

1. **Transparente**: El usuario no necesita saber que existe
2. **Automático**: Se ejecuta solo cuando es necesario
3. **Rápido**: No retrasa el inicio si no hay problemas
4. **Informativo**: Muestra qué corrigió si hubo problemas
5. **Seguro**: Solo corrige problemas reales

---

**Última actualización**: 2025-01-07

