# Keycloak Roles Setup - Guía de Uso

## 📋 ¿Cuándo se ejecutan los scripts de roles?

Los scripts de configuración de roles de Keycloak **NO se ejecutan automáticamente**. Debes ejecutarlos manualmente en las siguientes situaciones:

### 🔄 Cuándo Ejecutar

1. **Primera vez que configuras el sistema**
   - Después de levantar Keycloak por primera vez
   - Comando: `./scripts/setup-all-keycloak-roles.sh`

2. **Después de `./scripts/stack-manager.sh clean all`**
   - Este comando elimina TODA la base de datos de Keycloak
   - Los roles se pierden y deben recrearse
   - Comando: `./scripts/setup-all-keycloak-roles.sh`

3. **Después de eliminar el volumen de Keycloak manualmente**
   - Si eliminas `keycloak_data` volume
   - Comando: `./scripts/setup-all-keycloak-roles.sh`

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

## 🚀 Uso Manual

### Opción 1: Script Consolidado (Recomendado)

Configura **todos** los roles y grupos de una vez:

```bash
./scripts/setup-all-keycloak-roles.sh
```

**Qué hace**:
- ✅ Crea grupos (super-admins, admins, users, viewers)
- ✅ Crea roles de Grafana (admin, editor, viewer)
- ✅ Crea roles de Open WebUI (admin, user)
- ✅ Crea roles de n8n (admin, user)
- ✅ Crea roles de Jenkins (admin, user)
- ✅ Configura role mappers para OAuth

**Tiempo**: ~30 segundos

**Seguro**: Detecta roles existentes y los omite (puedes ejecutarlo múltiples veces)

### Opción 2: Scripts Individuales

Si solo necesitas configurar un servicio específico:

```bash
# Solo grupos
./scripts/keycloak-setup-roles-cli.sh groups

# Solo Grafana
./scripts/keycloak-setup-roles-cli.sh grafana

# Solo Open WebUI
./scripts/keycloak-setup-openwebui-roles.sh

# Solo n8n
./scripts/keycloak-setup-n8n-roles.sh

# Solo Jenkins
./scripts/keycloak-setup-jenkins-roles.sh
```

---

## 📖 Flujo Completo de Configuración

### Primera Vez

```bash
# 1. Levantar servicios
./scripts/stack-manager.sh start

# 2. Esperar a que Keycloak esté listo (~30 segundos)
# Verificar en: http://localhost:8080

# 3. Configurar roles (UNA SOLA VEZ)
./scripts/setup-all-keycloak-roles.sh

# 4. Listo! Los roles están configurados
```

### Después de Clean All

```bash
# 1. Limpiar todo (elimina base de datos)
./scripts/stack-manager.sh clean all

# 2. Levantar servicios de nuevo
./scripts/stack-manager.sh start

# 3. Reconfigurar roles (porque se perdieron)
./scripts/setup-all-keycloak-roles.sh
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
2. Login con `emujicad` / `TempPass123!`
3. Ir a **Clients** → **grafana** → **Roles**
4. Deberías ver: `grafana-admin`, `grafana-editor`, `grafana-viewer`

### Método 2: Script de Verificación

```bash
# Ver si Keycloak está corriendo
docker ps | grep keycloak

# Ver si los roles existen (ejemplo para Grafana)
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master \
  --user emujicad --password TempPass123!

docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients \
  -r master -q clientId=grafana --fields id --format csv --noquotes
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

**Solución**: Verificar que `KEYCLOAK_ADMIN_PASSWORD=TempPass123!` en `.env`

### Error: "Client 'grafana' not found"

**Causa**: El cliente de Grafana no está configurado en Keycloak

**Solución**: Ejecutar primero:
```bash
./scripts/keycloak-manager.sh setup grafana
```

### Roles duplicados

**No es un problema**: Los scripts detectan roles existentes y los omiten automáticamente

---

## 📝 Resumen Rápido

| Situación | ¿Ejecutar scripts de roles? | Comando |
|-----------|----------------------------|---------|
| Primera vez | ✅ SÍ | `./scripts/setup-all-keycloak-roles.sh` |
| Después de `clean all` | ✅ SÍ | `./scripts/setup-all-keycloak-roles.sh` |
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

- **Script consolidado**: [`scripts/setup-all-keycloak-roles.sh`](file:///mnt/backups/emujicad/Documents/ai/my-selfhosted-ai-kit/scripts/setup-all-keycloak-roles.sh)
- **Script CLI base**: [`scripts/keycloak-setup-roles-cli.sh`](file:///mnt/backups/emujicad/Documents/ai/my-selfhosted-ai-kit/scripts/keycloak-setup-roles-cli.sh)
- **Open WebUI roles**: [`scripts/keycloak-setup-openwebui-roles.sh`](file:///mnt/backups/emujicad/Documents/ai/my-selfhosted-ai-kit/scripts/keycloak-setup-openwebui-roles.sh)
- **n8n roles**: [`scripts/keycloak-setup-n8n-roles.sh`](file:///mnt/backups/emujicad/Documents/ai/my-selfhosted-ai-kit/scripts/keycloak-setup-n8n-roles.sh)
- **Jenkins roles**: [`scripts/keycloak-setup-jenkins-roles.sh`](file:///mnt/backups/emujicad/Documents/ai/my-selfhosted-ai-kit/scripts/keycloak-setup-jenkins-roles.sh)
