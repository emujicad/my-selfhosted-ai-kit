# 🔍 Explicación: URLs de Keycloak en Grafana OAuth

## 📋 Configuración Correcta

En `docker-compose.yml`, las URLs de OAuth están configuradas así:

```yaml
# AUTH_URL debe usar localhost porque el navegador del usuario necesita acceder
- GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth

# TOKEN_URL y API_URL pueden usar keycloak:8080 porque Grafana las llama desde dentro del contenedor
- GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
- GF_AUTH_GENERIC_OAUTH_API_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo

# SIGNOUT_REDIRECT_URL debe usar localhost porque el navegador del usuario necesita acceder
- GF_AUTH_SIGNOUT_REDIRECT_URL=http://localhost:8080/realms/master/protocol/openid-connect/logout
```

## ✅ ¿Por Qué Esta Configuración es Correcta?

### 1. **AUTH_URL** → `localhost:8080` ✅

**Quién la usa**: El navegador del usuario

**Por qué `localhost:8080`**:
- Cuando haces clic en "Sign in with Keycloak", Grafana redirige tu navegador
- El navegador necesita acceder a Keycloak directamente
- El navegador NO puede resolver `keycloak` (es un nombre interno de Docker)
- Por eso debe usar `localhost:8080` que está mapeado al puerto del host

**Flujo**:
```
Usuario → Grafana → Navegador redirige a localhost:8080 → Keycloak
```

### 2. **TOKEN_URL** → `keycloak:8080` ✅

**Quién la usa**: Grafana (desde dentro del contenedor)

**Por qué `keycloak:8080`**:
- Después de que el usuario se autentica, Grafana necesita intercambiar el código por un token
- Grafana hace esta llamada desde DENTRO del contenedor Docker
- Desde dentro del contenedor, Grafana puede resolver `keycloak` a través de la red Docker
- Es más eficiente usar el nombre interno `keycloak` que pasar por `localhost`

**Flujo**:
```
Grafana (contenedor) → keycloak:8080 (red Docker) → Keycloak
```

### 3. **API_URL** → `keycloak:8080` ✅

**Quién la usa**: Grafana (desde dentro del contenedor)

**Por qué `keycloak:8080`**:
- Grafana necesita obtener información del usuario autenticado
- Esta llamada también se hace desde DENTRO del contenedor
- Puede usar `keycloak` directamente a través de la red Docker

**Flujo**:
```
Grafana (contenedor) → keycloak:8080 (red Docker) → Keycloak
```

### 4. **SIGNOUT_REDIRECT_URL** → `localhost:8080` ✅

**Quién la usa**: El navegador del usuario

**Por qué `localhost:8080`**:
- Cuando cierras sesión, el navegador necesita redirigir a Keycloak
- El navegador NO puede resolver `keycloak`
- Debe usar `localhost:8080`

**Flujo**:
```
Usuario → Grafana → Navegador redirige a localhost:8080 → Keycloak logout
```

## 🔄 Flujo Completo OAuth

```
1. Usuario → Grafana (localhost:3001)
2. Usuario hace clic "Sign in with Keycloak"
3. Grafana redirige navegador → localhost:8080/auth (AUTH_URL)
4. Usuario ingresa credenciales en Keycloak
5. Keycloak redirige navegador → Grafana con código
6. Grafana (contenedor) → keycloak:8080/token (TOKEN_URL) para intercambiar código por token
7. Grafana (contenedor) → keycloak:8080/userinfo (API_URL) para obtener datos del usuario
8. Usuario queda logueado en Grafana ✅
```

## ⚠️ Errores Comunes

### ❌ Error 1: AUTH_URL con `keycloak:8080`
```
GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://keycloak:8080/...
```
**Problema**: El navegador no puede resolver `keycloak`
**Error**: `ERR_CONNECTION_REFUSED` o `ERR_NAME_NOT_RESOLVED`
**Solución**: Cambiar a `localhost:8080`

### ❌ Error 2: TOKEN_URL con `localhost:8080`
```
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://localhost:8080/...
```
**Problema**: Funciona pero es menos eficiente
**Por qué**: Pasa por el host en lugar de usar la red Docker directamente
**Solución**: Cambiar a `keycloak:8080` (opcional, pero mejor)

## 📝 Resumen

| URL | Valor Correcto | Quién la Usa | Por Qué |
|-----|---------------|--------------|---------|
| `AUTH_URL` | `localhost:8080` | Navegador | El navegador no resuelve `keycloak` |
| `TOKEN_URL` | `keycloak:8080` | Grafana (contenedor) | Grafana puede resolver `keycloak` |
| `API_URL` | `keycloak:8080` | Grafana (contenedor) | Grafana puede resolver `keycloak` |
| `SIGNOUT_REDIRECT_URL` | `localhost:8080` | Navegador | El navegador no resuelve `keycloak` |

## ✅ Tu Configuración Actual

Tu configuración en `docker-compose.yml` está **CORRECTA** ✅

- ✅ `AUTH_URL` usa `localhost:8080`
- ✅ `TOKEN_URL` usa `keycloak:8080`
- ✅ `API_URL` usa `keycloak:8080`
- ✅ `SIGNOUT_REDIRECT_URL` usa `localhost:8080`

**No necesitas cambiar nada** en las URLs. El problema del login probablemente es otro (sesiones, cookies, o configuración en Keycloak).

---

**Última actualización**: $(date)

