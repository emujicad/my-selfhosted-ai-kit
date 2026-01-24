# Keycloak Roles Setup - Guía de Uso

## 📋 ¿Cuándo se ejecutan los scripts de roles?

Los scripts de configuración de roles de Keycloak **NO se ejecutan automáticamente por defecto**. Tienes dos opciones:

### Opción 1: Manual (Recomendado)
Ejecutar el script manualmente cuando sea necesario.

### Opción 2: Automático
Usar el flag `--setup-roles` al levantar servicios.

---

## 🔄 Cuándo Ejecutar

1. **Primera vez que configuras el sistema**
   - Después de levantar Keycloak por primera vez
   - Comando: `./scripts/auth-manager.sh --setup-roles`

2. **Después de `./scripts/stack-manager.sh clean all`**
   - Este comando elimina TODA la base de datos de Keycloak
   - Los roles se pierden y deben recrearse
   - Comando: `./scripts/auth-manager.sh --setup-roles`

3. **Después de eliminar el volumen de Keycloak manualmente**
   - Si eliminas `keycloak_data` volume
   - Comando: `./scripts/auth-manager.sh --setup-roles`

### ✅ Cuándo NO Ejecutar

1. **Al hacer `./scripts/stack-manager.sh start`**
   - Los roles YA ESTÁN en la base de datos
   - No es necesario recrearlos

2. **Al hacer `./scripts/stack-manager.sh restart`**
   - Los roles persisten en la base de datos
   - No es necesario recrearlos

3. **Al hacer `./scripts/stack-manager.sh stop`**
   - Los roles se mantienen en el volumen
   - No es necesario recrearlos

---

## 🚀 Uso del Script Unificado

### Script Principal: auth-manager.sh

**Un solo script para todo**. Comandos disponibles:

```bash
# Configurar TODOS los roles (recomendado)
./scripts/auth-manager.sh --setup-roles

# Ver estado
./scripts/auth-manager.sh --status

# Ver ayuda
./scripts/auth-manager.sh --help
```

**Qué hace `--setup-roles`**:
- ✅ Crea grupos (super-admins, admins, users, viewers)
- ✅ Crea roles de Grafana (admin, editor, viewer)
- ✅ Crea roles de Open WebUI (admin, user)
- ✅ Crea roles de n8n (admin, user)
- ✅ Crea roles de Jenkins (admin, user)
- ✅ Configura role mappers para OAuth

**Tiempo**: ~30 segundos

**Seguro**: Detecta roles existentes y los omite (puedes ejecutarlo múltiples veces).

---

## 📖 Flujo Completo de Configuración

### Primera Vez (Manual)

```bash
# 1. Levantar servicios
./scripts/stack-manager.sh start

# 2. Esperar a que Keycloak esté listo (~30 segundos)
# Verificar en: http://localhost:8080

# 3. Configurar roles (UNA SOLA VEZ)
./scripts/auth-manager.sh --setup-roles

# 4. Listo! Los roles están configurados
```

### Primera Vez (Automático)

```bash
# Todo en un comando
./scripts/stack-manager.sh start --setup-roles

# Esto hace:
# 1. Levanta servicios
# 2. Espera a que Keycloak esté listo
# 3. Ejecuta automáticamente auth-manager.sh --setup-roles
```

### Después de Clean All

```bash
# 1. Limpiar todo (elimina base de datos)
./scripts/stack-manager.sh clean all

# 2. Levantar servicios y configurar roles automáticamente
./scripts/stack-manager.sh start --setup-roles

# O manualmente:
./scripts/stack-manager.sh start
./scripts/auth-manager.sh --setup-roles
```

### Uso Normal (Sin Clean)

```bash
# 1. Levantar servicios
./scripts/stack-manager.sh start

# 2. Los roles YA ESTÁN configurados
# NO necesitas ejecutar nada más
```

---

## 🔍 Verificar si los Roles Existen

### Método 1: Interfaz Web

1. Ir a http://localhost:8080
2. Login con `emujicad` / (Tu contraseña)
3. Ir a **Clients** → **grafana** → **Roles**
4. Deberías ver: `grafana-admin`, `grafana-editor`, `grafana-viewer`
```

---

## ⚠️ Problemas Comunes

### Error: "Keycloak is not running"

**Causa**: Keycloak no está levantado

**Solución**:
```bash
./scripts/stack-manager.sh start security
```

### Error: "Failed to authenticate"

**Causa**: Password incorrecto en `.env`

**Solución**: Verificar que `KEYCLOAK_ADMIN_PASSWORD` en `.env` es correcto.

### Error: "Client 'grafana' not found"

**Causa**: El cliente de Grafana no está configurado en Keycloak

**Solución**: 
```bash
./scripts/auth-manager.sh --fix-clients
```

### Roles duplicados

**No es un problema**: El script detecta roles existentes y los omite automáticamente.

---

## 📝 Resumen Rápido

| Situación | ¿Ejecutar script? | Comando |
|-----------|-------------------|---------|
| Primera vez (manual) | ✅ SÍ | `./scripts/auth-manager.sh --setup-roles` |
| Primera vez (auto) | ✅ SÍ | `./scripts/stack-manager.sh start --setup-roles` |
| Después de `clean all` | ✅ SÍ | `./scripts/auth-manager.sh --setup-roles` |
| Después de `start` | ❌ NO | (ya están configurados) |
| Después de `stop` | ❌ NO | (se mantienen en volumen) |
| Después de `restart` | ❌ NO | (se mantienen en volumen) |

---

## 🎯 Próximos Pasos Después de Configurar Roles

1. **Asignar roles a grupos** (manual via Keycloak UI)
   - Ir a **Groups** → **super-admins** → **Role Mapping**
   - Asignar roles de admin de todos los servicios

2. **Agregar usuarios a grupos** (manual via Keycloak UI)
   - Ir a **Users** → **emujicad** → **Groups**
   - Unirse a grupo `super-admins`

3. **Probar OAuth** en cada servicio
   - Grafana: http://localhost:3001
   - Open WebUI: http://localhost:3000
   - n8n: http://localhost:5678

---

## 📚 Archivos Relacionados

- **Script unificado**: [`scripts/auth-manager.sh`](../scripts/auth-manager.sh)
- **Stack manager**: [`scripts/stack-manager.sh`](../scripts/stack-manager.sh)
- **Test de validación**: [`scripts/tests/test-auth-manager.sh`](../scripts/tests/test-auth-manager.sh)
