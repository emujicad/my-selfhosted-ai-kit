# 🔧 Solución de Problemas de Base de Datos de Keycloak

## ❓ ¿Por qué ocurre el problema?

Aunque no uses `kill` directamente, el problema puede ocurrir por varias razones:

### Causas Comunes

1. **Reinicio del sistema**
   - Si el servidor se reinicia (actualizaciones, cortes de luz, etc.)
   - Docker se detiene abruptamente
   - Keycloak no tiene tiempo de cerrar sus conexiones a PostgreSQL
   - PostgreSQL queda con conexiones "huérfanas" que parecen activas pero no lo están

2. **`docker compose down` o `docker compose stop`**
   - A veces Docker detiene contenedores muy rápido
   - Si Keycloak está en medio de una transacción, no puede completarla
   - La transacción queda "colgada" en PostgreSQL

3. **Problemas de red**
   - Si hay un problema de red entre Keycloak y PostgreSQL
   - La conexión se corta pero PostgreSQL no se da cuenta inmediatamente
   - La conexión queda en estado "idle in transaction"

4. **Falta de memoria (OOM)**
   - Si el sistema se queda sin memoria
   - Linux puede matar procesos (OOM Killer)
   - Keycloak muere sin cerrar conexiones

5. **Crashes de Keycloak**
   - Si Keycloak tiene un error y se cae
   - No puede cerrar sus conexiones limpiamente

## 🔍 ¿Qué es una "transacción pendiente"?

Cuando Keycloak hace una operación en la base de datos:

1. **Abre una transacción**: `BEGIN`
2. **Hace cambios**: INSERT, UPDATE, DELETE
3. **Cierra la transacción**: `COMMIT` o `ROLLBACK`

**El problema**: Si Keycloak se detiene entre el paso 1 y 3, la transacción queda abierta.

PostgreSQL piensa: "Esta conexión está en medio de una transacción, debo esperar a que termine"

Pero Keycloak ya no existe, así que la transacción nunca termina.

## 🛠️ ¿Qué hace el diagnóstico integrado?

> **NOTA IMPORTANTE**: La corrección ahora es **automática** cuando usas `./scripts/stack-manager.sh start security`. El comando `diagnose keycloak-db` es útil para diagnóstico detallado o limpieza manual. Ver [KEYCLOAK_AUTO_FIX.md](KEYCLOAK_AUTO_FIX.md) para más detalles.

El comando `stack-manager.sh diagnose keycloak-db` hace **3 cosas simples**:

### 1. **Verifica el estado actual** (Solo lectura, no cambia nada)

Muestra:
- **Conexiones activas**: Qué conexiones hay a la base de datos
- **Transacciones pendientes**: Transacciones que están "colgadas"
- **Locks**: Bloqueos en tablas que impiden que Keycloak inicie

**Ejemplo de salida**:
```
📊 Verificando transacciones pendientes...
 pid  | usename | state                  | xact_start
------+---------+------------------------+----------------------------
 1234 | postgres| idle in transaction    | 2025-01-07 10:30:00
```

Esto significa: "Hay una transacción que empezó a las 10:30 y nunca terminó"

### 2. **Limpia conexiones huérfanas** (Solo si tú lo autorizas)

Usa el comando de PostgreSQL `pg_terminate_backend()` que:
- Encuentra conexiones de Keycloak que están "muertas"
- Las termina de forma segura
- **NO borra datos**, solo cierra conexiones

**Es como desconectar un teléfono que quedó colgado**

### 3. **Limpia transacciones pendientes** (Solo si tú lo autorizas)

Encuentra transacciones que están en estado `idle in transaction` y las termina.

**Es como colgar un teléfono que quedó en espera**

### 4. **Limpia locks** (Solo si tú lo autorizas)

Si hay tablas bloqueadas por transacciones muertas, las desbloquea.

**Es como quitar un candado que quedó puesto**

## ✅ ¿Es seguro?

**SÍ, es completamente seguro** porque:

1. **Solo termina conexiones "muertas"**
   - No toca conexiones activas
   - No borra datos
   - Solo cierra conexiones que ya no sirven

2. **Solo termina transacciones "colgadas"**
   - No toca transacciones activas
   - Solo termina las que están en estado `idle in transaction` (esperando indefinidamente)

3. **No modifica datos**
   - Solo cierra conexiones
   - No ejecuta `DELETE`, `DROP`, ni nada destructivo
   - Es como "desenchufar" conexiones muertas

## 📋 Ejemplo de Uso

```bash
# Ejecutar el script
./scripts/keycloak-manager.sh fix-db

# El script mostrará:
# 1. Estado actual (qué conexiones/transacciones hay)
# 2. Te preguntará si quieres limpiar
# 3. Si dices "s", limpiará todo
# 4. Mostrará el estado después de limpiar
```

## 🔄 Flujo Completo

```
1. Keycloak está corriendo normalmente
   ↓
2. Algo pasa (reinicio, docker stop, crash, etc.)
   ↓
3. Keycloak se detiene abruptamente
   ↓
4. PostgreSQL queda con:
   - Conexiones que parecen activas pero no lo están
   - Transacciones que nunca terminaron
   - Locks en tablas
   ↓
5. Intentas levantar Keycloak de nuevo
   ↓
6. Keycloak no puede conectarse porque:
   - Hay transacciones pendientes bloqueando tablas
   - Hay locks que impiden acceso
   ↓
7. Ejecutas: ./scripts/keycloak-manager.sh fix-db
   ↓
8. El script:
   - Muestra qué hay colgado
   - Limpia todo lo que está muerto
   - Deja la base de datos lista
   ↓
9. Keycloak puede iniciar normalmente
```

## 🛡️ Prevención

Las mejoras en `docker-compose.yml` ayudan a prevenir el problema:

1. **`stop_grace_period: 30s`**
   - Da 30 segundos a Keycloak para cerrar conexiones limpiamente
   - Reduce la probabilidad de transacciones pendientes

2. **`idle_in_transaction_session_timeout=60000`**
   - Si una transacción está "idle" (sin hacer nada) por más de 60 segundos
   - PostgreSQL la termina automáticamente
   - Previene transacciones que quedan colgadas

3. **Pool de conexiones configurado**
   - Keycloak gestiona mejor sus conexiones
   - Menos probabilidad de conexiones huérfanas

## 💡 Resumen

**El script es como un "limpiador" que:**
- ✅ Encuentra conexiones y transacciones muertas
- ✅ Las elimina de forma segura
- ✅ NO toca datos ni conexiones activas
- ✅ Deja la base de datos lista para que Keycloak inicie

**Es completamente seguro y necesario cuando Keycloak no puede iniciar por transacciones pendientes.**

## ⚠️ Nota Importante sobre databasechangeloglock

Keycloak usa la tabla `databasechangeloglock` para controlar migraciones de base de datos. Si Keycloak se detiene mientras está obteniendo este lock, puede quedar colgado.

**Si Keycloak no inicia con error "Failed to retrieve lock":**

1. **Terminar la conexión huérfana:**
   ```bash
   docker exec postgres psql -U postgres -d postgres -c "
     SELECT pg_terminate_backend(pid)
     FROM pg_stat_activity
     WHERE datname = 'keycloak'
     AND state = 'active'
     AND query LIKE '%databasechangeloglock%'
     AND query_start < now() - interval '2 minutes';
   "
   ```

2. **Limpiar la tabla directamente:**
   ```bash
   docker exec postgres psql -U postgres -d keycloak -c "
     UPDATE databasechangeloglock 
     SET locked = false, lockgranted = NULL, lockedby = NULL 
     WHERE id = 1000;
   "
   ```

3. **Reiniciar Keycloak:**
   ```bash
   docker compose --profile security up -d keycloak
   ```

**El script `fix-db` ahora hace esto automáticamente**, pero si necesitas hacerlo manualmente, estos son los pasos.

---

**Última actualización**: 2025-01-07

