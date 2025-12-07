# 🔧 Solución: "Restart login cookie not found"

## 🔍 Problema

El error **"Restart login cookie not found"** en Keycloak indica que el flujo OAuth se está interrumpiendo. Keycloak pierde el estado de la sesión durante el proceso de autenticación.

## ✅ Soluciones (En Orden de Prioridad)

### Solución 1: Habilitar "Direct Access Grants" en Keycloak

Esto permite un flujo de autenticación más directo:

1. **Accede a Keycloak Admin**: http://localhost:8080/admin
2. **Login**: `admin` / `admin`
3. **Ve a**: Clients → grafana → Settings
4. **Busca la sección "Capability config"**
5. **Marca la casilla**: ✅ **"Direct access grants"**
6. **Haz clic en Save**

Esto permite que Grafana use un flujo de autenticación más simple.

### Solución 2: Verificar Redirect URI Exacto

El Redirect URI debe coincidir **EXACTAMENTE**:

1. **En Keycloak Admin**: Clients → grafana → Settings
2. **Busca**: "Valid redirect URIs"
3. **Debe contener EXACTAMENTE** (sin espacios, sin trailing slash):
   ```
   http://localhost:3001/login/generic_oauth
   ```
4. **NO debe tener**:
   - Espacios al inicio o final
   - Trailing slash: `http://localhost:3001/login/generic_oauth/` ❌
   - Protocolo diferente: `https://localhost:3001/...` ❌
5. **Haz clic en Save**

### Solución 3: Verificar Configuración de Keycloak

Asegúrate de que estas configuraciones estén correctas:

**En Keycloak Admin → Clients → grafana → Settings:**

- ✅ **Client authentication**: `On`
- ✅ **Standard flow**: Marcado
- ✅ **Direct access grants**: Marcado (habilitar si no está)
- ✅ **Valid Redirect URIs**: `http://localhost:3001/login/generic_oauth`
- ✅ **Web Origins**: `http://localhost:3001`
- ✅ **Root URL**: `http://localhost:3001`
- ✅ **Home URL**: `http://localhost:3001`

### Solución 4: Reiniciar Servicios Completamente

A veces un reinicio completo ayuda:

```bash
# Detener servicios
docker compose --profile security stop keycloak
docker compose --profile monitoring stop grafana

# Esperar 5 segundos
sleep 5

# Levantar servicios
docker compose --profile security up -d keycloak
docker compose --profile monitoring up -d grafana

# Esperar 30-60 segundos para que Keycloak inicie completamente
sleep 30

# Verificar que están corriendo
docker compose --profile security ps keycloak
docker compose --profile monitoring ps grafana
```

### Solución 5: Crear Usuario Nuevo y Probar

1. **En Keycloak Admin**: Users → Add user
2. **Username**: `test-user` (o el que prefieras)
3. **Email**: `test@example.com` (opcional)
4. **Haz clic en Create**
5. **Ve a Credentials**:
   - Haz clic en **Set Password**
   - Ingresa contraseña
   - ⚠️ **DESMARCA "Temporary"**
   - Haz clic en **Save**
6. **Prueba login en Grafana con este nuevo usuario**

### Solución 6: Verificar Configuración en docker-compose.yml

Asegúrate de que estas variables estén correctas:

```yaml
- GF_AUTH_GENERIC_OAUTH_ENABLED=true
- GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
- GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=pr85OgKszvS0KOpVnlzYjM0c0Rp9nQXw
- GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
- GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
- GF_AUTH_GENERIC_OAUTH_API_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
```

Si cambias algo, reinicia Grafana:
```bash
docker compose --profile monitoring restart grafana
```

## 🔍 Diagnóstico Detallado

### Ver logs en tiempo real:

```bash
# Logs de Keycloak
docker compose --profile security logs -f keycloak

# Logs de Grafana
docker compose --profile monitoring logs -f grafana
```

### Verificar que el cliente existe:

1. Accede a: http://localhost:8080/admin
2. Ve a: Clients
3. Busca: `grafana`
4. Si no existe, créalo siguiendo las instrucciones en `docs/GRAFANA_KEYCLOAK_SETUP.md`

## 🎯 Checklist de Verificación

Antes de intentar login, verifica:

- [ ] Keycloak está corriendo y saludable
- [ ] Grafana está corriendo
- [ ] Cliente "grafana" existe en Keycloak
- [ ] "Direct access grants" está habilitado
- [ ] "Standard flow" está habilitado
- [ ] Redirect URI es exactamente: `http://localhost:3001/login/generic_oauth`
- [ ] Client Secret coincide entre Keycloak y docker-compose.yml
- [ ] Hay al menos un usuario creado en Keycloak
- [ ] El usuario tiene contraseña establecida (no temporal)

## 🚀 Solución Rápida Recomendada

1. **Habilita "Direct access grants"** en Keycloak (Solución 1)
2. **Verifica Redirect URI** exacto (Solución 2)
3. **Reinicia Grafana**: `docker compose --profile monitoring restart grafana`
4. **Espera 10 segundos**
5. **Prueba en ventana incógnito**: http://localhost:3001

---

**Última actualización**: $(date)

