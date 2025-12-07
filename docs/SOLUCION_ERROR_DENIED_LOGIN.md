# 🔧 Solución: "Login provider denied login request"

## 🔍 Problema

Error en Grafana: **"Login provider denied login request"**

Logs muestran:
- Grafana: `error=temporarily_unavailable errorDesc=authentication_expired`
- Keycloak: `error="already_logged_in"` o `error="cookie_not_found"`

## ✅ Solución Paso a Paso

### Paso 1: Verificar Configuración en docker-compose.yml

Asegúrate de que `GF_AUTH_GENERIC_OAUTH_AUTH_URL` use `localhost:8080` (NO `keycloak:8080`):

```yaml
- GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
```

**Por qué**: El navegador del usuario necesita acceder a esta URL, no Grafana desde dentro del contenedor.

### Paso 2: Limpiar Sesiones de Keycloak

Los errores `already_logged_in` y `cookie_not_found` indican sesiones conflictivas:

**Opción A: Reiniciar Keycloak (más simple)**
```bash
docker compose --profile security restart keycloak
sleep 30  # Esperar a que Keycloak reinicie
```

**Opción B: Limpiar cookies manualmente**
1. Abre las herramientas de desarrollador (F12)
2. Ve a Application → Cookies
3. Elimina todas las cookies de:
   - `http://localhost:8080`
   - `http://localhost:3001`
4. O usa ventana incógnito

### Paso 3: Reiniciar Grafana

Después de limpiar sesiones, reinicia Grafana:

```bash
docker compose --profile monitoring restart grafana
sleep 15  # Esperar a que Grafana reinicie
```

### Paso 4: Verificar Configuración en Keycloak

1. Abre: http://localhost:8080/admin
2. Login: `admin` / `admin`
3. Ve a: **Clients** → **grafana** → **Settings**
4. Verifica:
   - ✅ **Valid redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - ✅ **Web Origins**: `http://localhost:3001`
   - ✅ **Standard flow**: Marcado
   - ✅ **Client authentication**: On
5. Haz clic en **Save**

### Paso 5: Probar Login

1. **Abre ventana incógnito** (importante para evitar cookies conflictivas)
2. Ve a: http://localhost:3001
3. Haz clic en "Sign in with Keycloak"
4. Ingresa: `admin` / `admin` (credenciales de Keycloak)
5. Deberías quedar logueado ✅

## 🐛 Si Aún No Funciona

### Verificar Logs

```bash
# Logs de Grafana
docker compose --profile monitoring logs grafana --tail 50 | grep -i oauth

# Logs de Keycloak
docker compose --profile security logs keycloak --tail 50 | grep -i grafana
```

### Verificar Variables de Entorno en Grafana

```bash
docker compose --profile monitoring exec grafana env | grep GF_AUTH_GENERIC_OAUTH
```

Debe mostrar:
- `GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/...` ✅
- NO debe mostrar `keycloak:8080` para AUTH_URL ❌

### Verificar Client Secret

```bash
# En docker-compose.yml
grep GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET docker-compose.yml

# Compara con Keycloak → Clients → grafana → Credentials → Secret
```

Deben coincidir EXACTAMENTE.

## 📋 Checklist Completo

- [ ] `GF_AUTH_GENERIC_OAUTH_AUTH_URL` usa `localhost:8080` (no `keycloak:8080`)
- [ ] Keycloak reiniciado (sesiones limpiadas)
- [ ] Grafana reiniciado
- [ ] Redirect URI en Keycloak es exactamente: `http://localhost:3001/login/generic_oauth`
- [ ] Client Secret coincide entre Keycloak y docker-compose.yml
- [ ] Pruebas en ventana incógnito

## 💡 Por Qué Ocurre Este Error

1. **Sesiones conflictivas**: Keycloak tiene sesiones antiguas que interfieren
2. **URLs incorrectas**: Si `AUTH_URL` usa `keycloak:8080`, el navegador no puede acceder
3. **Cookies corruptas**: Cookies de sesiones anteriores causan conflictos
4. **Configuración desincronizada**: Cambios en Keycloak no aplicados en Grafana

---

**Última actualización**: $(date)

