# 🔍 Causa Raíz: Conexiones Huérfanas en Keycloak

## 📋 Problema

Keycloak genera conexiones huérfanas a PostgreSQL incluso durante el inicio, causando que falle al iniciar con errores como:
- `Failed to retrieve lock`
- `This connection has been closed`
- `An I/O error occurred while sending to the backend`

## 🔍 Causas Identificadas

### 1. **Interrupciones Durante el Inicio**

**Qué pasa:**
- Keycloak inicia y crea conexiones del pool de conexiones
- Intenta adquirir un lock en `databasechangeloglock` para hacer migraciones
- Si el proceso se interrumpe (docker stop, kill, reinicio, etc.), las conexiones no se cierran correctamente
- Las conexiones quedan en estado `idle in transaction` o `active` pero huérfanas

**Por qué:**
- Docker puede detener el contenedor abruptamente
- El proceso de Keycloak no tiene tiempo de cerrar las conexiones limpiamente
- PostgreSQL mantiene las conexiones abiertas hasta que se detectan como muertas

### 2. **Pool de Conexiones de Keycloak**

**Configuración actual:**
```yaml
- KC_DB_POOL_INITIAL_SIZE=5    # 5 conexiones al inicio
- KC_DB_POOL_MIN_SIZE=5         # Mínimo 5 conexiones
- KC_DB_POOL_MAX_SIZE=20        # Máximo 20 conexiones
```

**Qué pasa:**
- Keycloak crea 5 conexiones al inicio (INITIAL_SIZE)
- Si Keycloak falla durante el inicio, estas 5 conexiones pueden quedar abiertas
- Cada conexión intenta adquirir el lock en `databasechangeloglock`
- Si fallan, quedan en estado `idle in transaction`

### 3. **Locks en databasechangeloglock**

**Qué pasa:**
- Keycloak usa Liquibase para gestionar migraciones de base de datos
- Liquibase necesita un lock exclusivo en `databasechangeloglock` para evitar migraciones concurrentes
- Si una conexión anterior tiene el lock y Keycloak se detiene, el lock queda "colgado"
- La nueva instancia de Keycloak no puede adquirir el lock

**Flujo problemático:**
```
1. Keycloak inicia → Crea conexión 1 → Intenta adquirir lock
2. Keycloak falla o se detiene → Conexión 1 queda con lock activo
3. Keycloak reinicia → Crea conexión 2 → Intenta adquirir lock
4. Lock está ocupado por conexión 1 (huérfana) → Keycloak falla
```

### 4. **Timeouts de PostgreSQL**

**Configuración actual:**
```yaml
- statement_timeout=30000                    # 30 segundos
- idle_in_transaction_session_timeout=60000  # 60 segundos
- lock_timeout=10000                         # 10 segundos
```

**Qué pasa:**
- Si Keycloak tarda más de 60 segundos en iniciar, PostgreSQL puede cerrar conexiones idle
- Si Keycloak está usando una conexión y PostgreSQL la cierra, Keycloak falla
- Esto puede crear un ciclo: Keycloak intenta iniciar → Conexión se cierra → Keycloak falla → Nueva conexión huérfana

### 5. **Errores de I/O Durante el Inicio**

**De los logs:**
```
An I/O error occurred while sending to the backend
This connection has been closed
```

**Qué pasa:**
- Durante el inicio, Keycloak puede tener problemas de red con PostgreSQL
- Si la conexión se interrumpe mientras Keycloak está usando el lock, queda huérfana
- Keycloak intenta hacer rollback pero la conexión ya está cerrada

## 🛠️ Soluciones Implementadas

### 1. **Limpieza Automática Antes de Iniciar**

La función `auto_fix_keycloak_db()` ahora:
- Detecta si Keycloak está corriendo
- Si NO está corriendo: termina TODAS las conexiones huérfanas
- Limpia TODOS los locks en `databasechangeloglock`
- Se ejecuta automáticamente antes de levantar Keycloak

### 2. **Limpieza Automática al Detener**

La función `cleanup_keycloak_db_before_stop()`:
- Se ejecuta antes de detener servicios
- Termina todas las conexiones de Keycloak
- Limpia todos los locks
- Previene que queden conexiones huérfanas

### 3. **Verificación Post-Inicio**

Después de levantar servicios:
- Espera 3 segundos
- Verifica si Keycloak falló
- Si falló, limpia automáticamente y reintenta

## 🔧 Mejoras Recomendadas (Futuras)

### 1. **Ajustar Pool de Conexiones**

Reducir conexiones iniciales para minimizar conexiones huérfanas:
```yaml
- KC_DB_POOL_INITIAL_SIZE=2    # Menos conexiones al inicio
- KC_DB_POOL_MIN_SIZE=2
```

### 2. **Aumentar Timeouts de PostgreSQL**

Dar más tiempo para que Keycloak inicie:
```yaml
- idle_in_transaction_session_timeout=120000  # 2 minutos
```

### 3. **Configurar Healthcheck Mejorado**

Usar el endpoint real de Keycloak:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:8080/health/ready || exit 1"]
```

### 4. **Configurar Retry en Keycloak**

Keycloak ya tiene retry automático, pero se puede mejorar con:
```yaml
- KC_DB_POOL_MAX_LIFETIME=600000  # 10 minutos
```

## 📊 Resumen

**Causa raíz:** Las conexiones huérfanas se generan porque:
1. Keycloak crea conexiones del pool al inicio
2. Si Keycloak se interrumpe o falla, estas conexiones no se cierran
3. Las conexiones quedan con locks activos en `databasechangeloglock`
4. La siguiente instancia de Keycloak no puede adquirir el lock

**Solución:** Limpieza automática antes de iniciar y después de detener, más verificación post-inicio para reintentar si falla.

---

**Última actualización**: 2025-12-08

