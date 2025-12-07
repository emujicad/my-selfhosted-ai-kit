# 🔐 Cómo Acceder a Grafana con Keycloak

## 📋 Resumen Rápido

**Grafana usa OAuth con Keycloak**. Necesitas usar las credenciales de **Keycloak**, no de Grafana.

## 🚀 Pasos para Acceder

### Paso 1: Abre Grafana
- URL: http://localhost:3001

### Paso 2: Haz clic en "Sign in with Keycloak"
- Verás un botón que dice "Sign in with Keycloak"
- Haz clic en él

### Paso 3: Serás redirigido a Keycloak
- El navegador te llevará automáticamente a Keycloak
- URL: http://localhost:8080/realms/master/protocol/openid-connect/auth

### Paso 4: Ingresa credenciales de Keycloak
- **Usuario**: `admin` (o cualquier usuario que tengas en Keycloak)
- **Contraseña**: `admin` (o la contraseña del usuario de Keycloak)

⚠️ **IMPORTANTE**: Estas son las credenciales de **Keycloak**, no de Grafana.

### Paso 5: Autoriza el acceso
- Keycloak te pedirá autorizar que Grafana acceda a tu información
- Haz clic en "Allow" o "Permitir"

### Paso 6: Redirección automática
- Keycloak te redirige automáticamente de vuelta a Grafana
- Ya estarás logueado en Grafana

## 🔍 Tu Configuración Actual

Basándome en las capturas de pantalla que compartiste:

✅ **Cliente "grafana" configurado correctamente**:
- Client ID: `grafana`
- Client Secret: `pr85OgKszvS0KOpVnlzYjM0c0Rp9nQXw`
- Valid Redirect URIs: `http://localhost:3001/login/generic_oauth`
- Web Origins: `http://localhost:3001`
- Standard flow: ✅ Activado
- Direct access grants: ❌ Desactivado

✅ **Configuración en docker-compose.yml**:
- Client Secret coincide con Keycloak ✅
- URLs configuradas correctamente ✅

## 🔑 Credenciales que Usar

### Para Keycloak Admin Console:
- URL: http://localhost:8080/admin
- Usuario: `admin`
- Contraseña: `admin`

### Para Grafana (vía OAuth):
- URL: http://localhost:3001
- Login: Usa cualquier usuario de Keycloak
- Ejemplo: `admin` / `admin` (credenciales de Keycloak)

## 🐛 Solución de Problemas

### Problema: "Sign in with Keycloak" no aparece

**Solución**:
1. Verifica que Grafana esté corriendo:
   ```bash
   docker compose --profile monitoring ps grafana
   ```

2. Verifica la configuración OAuth:
   ```bash
   grep GF_AUTH_GENERIC_OAUTH docker-compose.yml
   ```

3. Reinicia Grafana:
   ```bash
   docker compose --profile monitoring restart grafana
   ```

### Problema: Error "Invalid redirect URI"

**Solución**:
1. Ve a Keycloak → Clients → grafana → Settings
2. Verifica que **Valid redirect URIs** contenga exactamente:
   ```
   http://localhost:3001/login/generic_oauth
   ```
3. Haz clic en **Save**

### Problema: Error "Invalid client credentials"

**Solución**:
1. Ve a Keycloak → Clients → grafana → Credentials
2. Copia el **Client Secret**
3. Actualiza en `docker-compose.yml`:
   ```yaml
   - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=tu_secret_aqui
   ```
4. Reinicia Grafana:
   ```bash
   docker compose --profile monitoring restart grafana
   ```

### Problema: No recuerdo qué usuario usar

**Solución**:
1. Accede a Keycloak Admin: http://localhost:8080/admin
2. Login: `admin` / `admin`
3. Ve a: **Users**
4. Verás todos los usuarios disponibles
5. Puedes usar cualquiera de ellos para login en Grafana

O crea un nuevo usuario:
1. En Keycloak Admin → Users → Add user
2. Completa el formulario
3. Ve a Credentials → Set Password
4. Usa ese usuario para login en Grafana

## 📝 Flujo OAuth Explicado

```
Usuario → Grafana → Keycloak → Usuario ingresa credenciales → Keycloak → Grafana (logueado)
```

1. **Usuario va a Grafana** (http://localhost:3001)
2. **Hace clic en "Sign in with Keycloak"**
3. **Grafana redirige a Keycloak** con parámetros OAuth
4. **Usuario ingresa usuario/contraseña en Keycloak**
5. **Keycloak valida credenciales**
6. **Keycloak redirige de vuelta a Grafana** con un código de autorización
7. **Grafana intercambia el código por un token** (usando Client Secret)
8. **Grafana obtiene información del usuario** de Keycloak
9. **Usuario queda logueado en Grafana**

## ✅ Verificación Rápida

Para verificar que todo está bien:

```bash
# Verificar que Keycloak está corriendo
docker compose --profile security ps keycloak

# Verificar que Grafana está corriendo
docker compose --profile monitoring ps grafana

# Ver logs de Grafana para ver errores OAuth
docker compose --profile monitoring logs grafana | grep -i oauth
```

## 🎯 Resumen

- ✅ **SÍ usas usuario y contraseña** (de Keycloak, no de Grafana)
- ✅ **El flujo es OAuth** (redirección del navegador)
- ✅ **Tu configuración está correcta** según las capturas
- ✅ **Usa admin/admin de Keycloak** para probar

---

**Última actualización**: $(date)

