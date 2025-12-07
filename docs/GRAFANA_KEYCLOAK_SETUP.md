# 🔐 Configuración de Grafana con Keycloak

## ⚠️ Importante: Grafana usa OAuth, NO credenciales directas

Grafana está configurado para usar **OAuth con Keycloak**, no acepta credenciales directas. Necesitas:

1. **Un usuario creado en Keycloak** (puede ser el admin o cualquier otro usuario)
2. **El cliente "grafana" configurado en Keycloak**
3. **Las URLs de OAuth correctas**

## 🚀 Configuración Paso a Paso

### Paso 1: Crear un Usuario en Keycloak

1. **Accede a Keycloak Admin Console**:
   - URL: http://localhost:8080/admin
   - Login: `admin` / `admin`

2. **Crear nuevo usuario**:
   - Ve a: **Users** → **Add user**
   - Completa:
     - **Username**: `grafana-user` (o el que prefieras)
     - **Email**: (opcional pero recomendado)
     - **First Name**: (opcional)
     - **Last Name**: (opcional)
   - Haz clic en **Create**

3. **Establecer contraseña**:
   - En la página del usuario, ve a la pestaña **Credentials**
   - Haz clic en **Set Password**
   - Ingresa la contraseña
   - **IMPORTANTE**: Desmarca "Temporary" si quieres que sea permanente
   - Haz clic en **Save**

### Paso 2: Configurar el Cliente "grafana" en Keycloak

1. **Ve a Clients**:
   - En el menú lateral, ve a **Clients**
   - Busca el cliente `grafana` o créalo si no existe

2. **Si el cliente NO existe, créalo**:
   - Haz clic en **Create client**
   - **Client ID**: `grafana`
   - **Client Protocol**: `openid-connect`
   - Haz clic en **Next**

3. **Configurar el cliente**:
   - **Access Type**: `confidential`
   - **Standard Flow Enabled**: ✅ (activado)
   - **Direct Access Grants Enabled**: ✅ (activado)
   - **Valid Redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - **Web Origins**: `http://localhost:3001`
   - Haz clic en **Save**

4. **Copiar el Client Secret**:
   - Ve a la pestaña **Credentials**
   - Copia el valor de **Secret**
   - Este valor debe coincidir con `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` en `docker-compose.yml`

### Paso 3: Verificar Configuración en docker-compose.yml

Verifica que estas variables estén correctas en `docker-compose.yml`:

```yaml
- GF_AUTH_GENERIC_OAUTH_ENABLED=true
- GF_AUTH_GENERIC_OAUTH_NAME=Keycloak
- GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
- GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=pr85OgKszvS0KOpVnlzYjM0c0Rp9nQXw
- GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
- GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
- GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
- GF_AUTH_GENERIC_OAUTH_API_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
```

### Paso 4: Usar Grafana

1. **Accede a Grafana**:
   - URL: http://localhost:3001

2. **Haz clic en "Sign in with Keycloak"**

3. **Serás redirigido a Keycloak**:
   - Ingresa las credenciales del usuario que creaste en Keycloak
   - **NO uses admin/admin aquí** (a menos que quieras usar el admin)

4. **Después del login**, serás redirigido de vuelta a Grafana

## 🔧 Solución Rápida: Usar el Usuario Admin de Keycloak

Si quieres usar rápidamente el usuario `admin` de Keycloak:

1. **Asegúrate de que el cliente "grafana" existe en Keycloak** (ver Paso 2)
2. **Accede a Grafana**: http://localhost:3001
3. **Haz clic en "Sign in with Keycloak"**
4. **Ingresa**: `admin` / `admin` (las credenciales de Keycloak)

## 🐛 Solución de Problemas

### Error: "Invalid redirect URI"

**Problema**: El redirect URI no coincide con el configurado en Keycloak.

**Solución**:
1. Ve a Keycloak → Clients → grafana
2. Verifica que **Valid Redirect URIs** contenga exactamente:
   ```
   http://localhost:3001/login/generic_oauth
   ```

### Error: "Invalid client credentials"

**Problema**: El Client Secret no coincide.

**Solución**:
1. Ve a Keycloak → Clients → grafana → Credentials
2. Copia el **Secret**
3. Actualiza `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` en `docker-compose.yml`
4. Reinicia Grafana: `docker compose --profile monitoring restart grafana`

### No aparece el botón "Sign in with Keycloak"

**Problema**: OAuth no está habilitado en Grafana.

**Solución**:
1. Verifica que `GF_AUTH_GENERIC_OAUTH_ENABLED=true` en docker-compose.yml
2. Verifica que `GF_AUTH_DISABLE_LOGIN_FORM=true` (opcional, pero recomendado)
3. Reinicia Grafana: `docker compose --profile monitoring restart grafana`

### El usuario no puede acceder a Grafana

**Problema**: El usuario necesita roles o permisos.

**Solución**:
1. En Keycloak, ve al usuario
2. Ve a la pestaña **Role Mappings**
3. Asigna roles si es necesario (normalmente no es necesario para Grafana básico)

## 📋 Checklist de Configuración

- [ ] Keycloak corriendo y accesible en http://localhost:8080
- [ ] Usuario creado en Keycloak (o usar admin)
- [ ] Cliente "grafana" creado en Keycloak
- [ ] Client Secret copiado y configurado en docker-compose.yml
- [ ] Valid Redirect URI configurado: `http://localhost:3001/login/generic_oauth`
- [ ] Grafana reiniciado después de cambios
- [ ] Probar login desde Grafana

## 🔑 Credenciales para Recordar

**Keycloak Admin Console**:
- URL: http://localhost:8080/admin
- Usuario: `admin`
- Contraseña: `admin`

**Grafana (vía OAuth)**:
- URL: http://localhost:3001
- Login: Usa cualquier usuario creado en Keycloak
- NO acepta credenciales directas (solo OAuth)

---

**Última actualización**: $(date)

