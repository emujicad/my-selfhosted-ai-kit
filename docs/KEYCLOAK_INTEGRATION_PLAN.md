# 🔐 Integración Keycloak con Servicios

## 📋 Índice

1. [Resumen General](#resumen-general)
2. [Conceptos Clave](#conceptos-clave)
3. [Credenciales y Acceso](#credenciales-y-acceso)
4. [Grafana + Keycloak](#grafana--keycloak) ✅
5. [Open WebUI + Keycloak](#open-webui--keycloak) ⚠️
6. [n8n + Keycloak](#n8n--keycloak) ⏳
7. [Jenkins + Keycloak](#jenkins--keycloak) ⏳
8. [Troubleshooting General](#troubleshooting-general)
9. [Referencias](#referencias)

---

## 📊 Resumen General

### Estado de Integraciones

| Servicio | Estado | Notas |
|----------|--------|-------|
| **Grafana** | ✅ Completado | Funciona perfectamente |
| **Open WebUI** | ⚠️ Limitación conocida | No funciona debido a limitación de Open WebUI |
| **n8n** | ⏳ Configurado | Pendiente probar |
| **Jenkins** | ⏳ Pendiente | No iniciado |

---

## 🔑 Conceptos Clave

### URLs en Docker

**Regla fundamental:**
- `localhost:8080` → Para acceso desde el navegador (usuario)
- `keycloak:8080` → Para acceso desde contenedores Docker (interno)

**Por qué:**
- El navegador del usuario NO puede resolver `keycloak` (es un nombre interno de Docker)
- Los contenedores SÍ pueden resolver `keycloak` a través de la red Docker
- Es más eficiente usar `keycloak:8080` para comunicación interna

### Flujo OAuth/OIDC Estándar

```
1. Usuario hace clic en "Sign in with Keycloak"
2. Navegador redirige a Keycloak (localhost:8080) → Usuario se autentica
3. Keycloak redirige navegador de vuelta con código
4. Aplicación (contenedor) intercambia código por token (keycloak:8080)
5. Aplicación obtiene información del usuario (keycloak:8080)
```

### Diferencias: Grafana vs Open WebUI

| Aspecto | Grafana | Open WebUI |
|---------|---------|------------|
| **Tipo de OAuth** | Generic OAuth (estándar) | OIDC nativo (propio) |
| **Madurez** | Alta (muy probado) | Media (menos probado) |
| **Configuración** | Simple | Compleja |
| **Manejo de usuarios** | Automático | Requiere configuración |
| **Discovery document** | No necesario | Puede causar problemas |
| **URLs internas** | Funciona bien | Problemas con localhost |

**Por qué Grafana funciona mejor:**
- Generic OAuth es más maduro y robusto
- Maneja correctamente las diferencias entre URLs del navegador e internas
- Crea usuarios automáticamente sin configuración adicional
- No depende tanto del discovery document

---

## 🔐 Credenciales y Acceso

### Credenciales por Defecto

**Keycloak Admin Console:**
- URL: http://localhost:8080/admin
- Usuario: `admin`
- Contraseña: `admin`

⚠️ **IMPORTANTE**: Estas son credenciales por defecto y **deben cambiarse en producción**.

### Cómo Acceder a Keycloak

1. **Asegúrate de que Keycloak esté corriendo**:
   ```bash
   docker compose --profile security ps keycloak
   ```

2. **Accede a la consola de administración**:
   - URL: http://localhost:8080/admin
   - O directamente: http://localhost:8080

3. **Inicia sesión con las credenciales por defecto**:
   - Usuario: `admin`
   - Contraseña: `admin`

### Cambiar las Credenciales

**Opción 1: Cambiar desde docker-compose.yml**
1. Edita `docker-compose.yml` y modifica:
   ```yaml
   environment:
     - KEYCLOAK_ADMIN=tu_nuevo_usuario
     - KEYCLOAK_ADMIN_PASSWORD=tu_nueva_contraseña_segura
   ```
2. Reinicia Keycloak:
   ```bash
   docker compose --profile security restart keycloak
   ```

**Opción 2: Cambiar desde la UI de Keycloak**
1. Accede a http://localhost:8080/admin
2. Login con admin/admin
3. Ve a: **Administration Console** → **User** (arriba a la derecha)
4. Selecciona el usuario `admin`
5. Ve a la pestaña **Credentials**
6. Establece una nueva contraseña
7. Desmarca "Temporary" si quieres que sea permanente

### Si Olvidaste las Credenciales

**Método 1: Verificar en docker-compose.yml**
```bash
grep KEYCLOAK_ADMIN docker-compose.yml
```

**Método 2: Resetear completamente Keycloak**
⚠️ **ADVERTENCIA**: Esto eliminará todos los datos de Keycloak.

```bash
# Detén Keycloak
docker compose --profile security stop keycloak

# Elimina el volumen de datos
docker volume rm my-selfhosted-ai-kit_keycloak_data

# Levanta Keycloak nuevamente
docker compose --profile security up -d keycloak

# Espera 30-60 segundos y accede con admin/admin
```

---

## ✅ Grafana + Keycloak

### Estado: Completado y Funcionando

Grafana tiene excelente soporte para OAuth/OIDC y funciona perfectamente con Keycloak.

### Configuración

**Variables en docker-compose.yml:**
```yaml
environment:
  - GF_AUTH_GENERIC_OAUTH_ENABLED=true
  - GF_AUTH_GENERIC_OAUTH_NAME=Keycloak
  - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
  - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${GRAFANA_OAUTH_CLIENT_SECRET}
  - GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
  - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
  - GF_AUTH_GENERIC_OAUTH_API_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
  - GF_AUTH_SIGNOUT_REDIRECT_URL=http://localhost:8080/realms/master/protocol/openid-connect/logout
  - GF_AUTH_DISABLE_LOGIN_FORM=true
```

**Explicación de URLs:**
- `AUTH_URL` usa `localhost:8080` porque el navegador necesita acceder
- `TOKEN_URL` usa `keycloak:8080` porque Grafana lo llama desde el contenedor
- `API_URL` usa `keycloak:8080` porque Grafana lo llama desde el contenedor
- `SIGNOUT_REDIRECT_URL` usa `localhost:8080` porque el navegador necesita acceder

**Cliente en Keycloak:**
- Client ID: `grafana`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Direct access grants: NO necesario (Grafana usa Standard flow)
- Valid redirect URIs: `http://localhost:3001/login/generic_oauth`
- Web origins: `http://localhost:3001`

**Configuración adicional:**
- `grafana.ini` montado como volumen para deshabilitar login directo

### Pasos para Configurar

1. **Crear un Usuario en Keycloak** (opcional, puedes usar admin):
   - Accede a Keycloak Admin: http://localhost:8080/admin
   - Ve a: **Users** → **Add user**
   - Completa: Username, Email (opcional)
   - Ve a la pestaña **Credentials** → **Set Password**
   - ⚠️ **DESMARCA "Temporary"** si quieres que sea permanente

2. **Configurar el Cliente "grafana" en Keycloak**:
   - Ve a: **Clients** → **Create client** (o edita si existe)
   - **Client ID**: `grafana`
   - **Client Protocol**: `openid-connect`
   - **Client authentication**: `On`
   - **Standard flow**: ✅ Marcado
   - **Direct access grants**: ⬜ NO necesario
   - **Valid redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - **Web origins**: `http://localhost:3001`
   - Ve a la pestaña **Credentials** y copia el **Client Secret**

3. **Configurar Client Secret en docker-compose.yml**:
   - Actualiza `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` con el secret copiado

4. **Recrear Grafana**:
   ```bash
   docker compose --profile monitoring up -d --force-recreate grafana
   ```

### Cómo Usar

1. Abre Grafana: http://localhost:3001
2. Haz clic en "Sign in with Keycloak"
3. Ingresa credenciales de Keycloak (ej: admin/admin)
4. Serás redirigido de vuelta a Grafana autenticado

⚠️ **IMPORTANTE**: Usas credenciales de **Keycloak**, no de Grafana. Grafana no acepta credenciales directas cuando OAuth está habilitado.

### Troubleshooting Grafana

**Error: "Login provider denied login request"**

**Causas comunes:**
- Sesiones conflictivas en Keycloak
- Redirect URI incorrecto
- Client Secret no coincide

**Soluciones:**
1. **Limpia cookies de Keycloak**:
   - Usa ventana incógnito (más fácil)
   - O limpia cookies manualmente: F12 → Application → Cookies → `http://localhost:8080`

2. **Reinicia servicios**:
   ```bash
   docker compose --profile security restart keycloak
   docker compose --profile monitoring restart grafana
   ```

3. **Verifica Redirect URI**:
   - En Keycloak → Clients → grafana → Settings
   - Debe ser exactamente: `http://localhost:3001/login/generic_oauth`
   - Sin espacios, sin trailing slash

4. **Verifica Client Secret**:
   - En Keycloak → Clients → grafana → Credentials
   - Debe coincidir con `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` en docker-compose.yml

**Error: "ERR_CONNECTION_REFUSED"**

**Causa**: `AUTH_URL` usa `keycloak:8080` en lugar de `localhost:8080`

**Solución**:
- Verifica que `GF_AUTH_GENERIC_OAUTH_AUTH_URL` use `localhost:8080`
- Recrea Grafana: `docker compose --profile monitoring up -d --force-recreate grafana`

**Error: "Restart login cookie not found"**

**Causa**: Flujo OAuth interrumpido, sesiones conflictivas

**Soluciones**:
1. Habilita "Direct access grants" en Keycloak (aunque no es necesario, puede ayudar)
2. Verifica Redirect URI exacto
3. Reinicia Keycloak y Grafana
4. Usa ventana incógnito

**No aparece el botón "Sign in with Keycloak"**

**Causa**: OAuth no está habilitado o configuración incorrecta

**Solución**:
1. Verifica que `GF_AUTH_GENERIC_OAUTH_ENABLED=true` en docker-compose.yml
2. Verifica que `GF_AUTH_DISABLE_LOGIN_FORM=true` (opcional pero recomendado)
3. Recrea Grafana: `docker compose --profile monitoring up -d --force-recreate grafana`

### Checklist de Configuración Grafana

- [ ] Keycloak corriendo y accesible en http://localhost:8080
- [ ] Usuario creado en Keycloak (o usar admin)
- [ ] Cliente "grafana" creado en Keycloak
- [ ] Client authentication: On
- [ ] Standard flow: Enabled
- [ ] Valid redirect URIs: `http://localhost:3001/login/generic_oauth`
- [ ] Web origins: `http://localhost:3001`
- [ ] Client Secret copiado y configurado en docker-compose.yml
- [ ] Grafana recreado después de cambios
- [ ] Probar login desde Grafana

---

## ⚠️ Open WebUI + Keycloak

### Estado: Limitación Conocida - No Funciona

**Problema Identificado:**
Open WebUI tiene una limitación que hace que no funcione correctamente con Keycloak en Docker:

1. Necesita `OPENID_PROVIDER_URL` (discovery document) para mostrar el botón
2. Cuando hay discovery document, Open WebUI **ignora las URLs explícitas** configuradas
3. Usa las URLs del discovery document que tienen `localhost:8080`
4. Desde el contenedor, `localhost:8080` no funciona (apunta al propio contenedor)
5. Resultado: Error 405 `Method Not Allowed`

### Configuración Actual

**Variables en docker-compose.yml:**
```yaml
environment:
  - OPENID_ENABLED=true
  - OPENID_CLIENT_ID=open-webui
  - OPENID_CLIENT_SECRET=p6pj69pYezNrrmT8VcQRon3BrsR0OP9s
  - OPENID_PROVIDER_URL=http://keycloak:8080/realms/master/.well-known/openid-configuration
  - OPENID_REDIRECT_URI=http://localhost:3000/oauth/oidc/callback
  - OPENID_AUTHORIZATION_ENDPOINT=http://localhost:8080/realms/master/protocol/openid-connect/auth
  - OPENID_TOKEN_ENDPOINT=http://keycloak:8080/realms/master/protocol/openid-connect/token
  - OPENID_USERINFO_ENDPOINT=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
  - OPENID_ISSUER=http://localhost:8080/realms/master
  - OPENID_SCOPES=openid profile email
  - ENABLE_OAUTH_SSO=true
  - ENABLE_OAUTH_SIGNUP=true
```

**Cliente en Keycloak:**
- Client ID: `open-webui`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Valid redirect URIs: `http://localhost:3000/oauth/oidc/callback`
- Web origins: `http://localhost:3000`

### Soluciones Intentadas (Sin Éxito)

1. ✅ Configurar URLs explícitas → Open WebUI las ignora cuando hay discovery document
2. ✅ Eliminar discovery document → El botón desaparece
3. ✅ Actualizar Open WebUI de 0.6.13 a 0.6.41 → Mismo problema
4. ✅ Actualizar Keycloak de 26.3.1 a 26.4.7 → Mismo problema
5. ✅ Configurar Keycloak con `KC_HOSTNAME_STRICT_BACKCHANNEL` → No cambia el discovery document
6. ✅ Configurar "Use 'at+jwt' as access token header type" → No resuelve el problema

### Error en Logs

```
POST http://localhost:8080/realms/master/protocol/openid-connect/token "HTTP/1.1 405 Method Not Allowed"
UnsupportedTokenTypeError: unsupported_token_type: Unsupported token_type: 'access_token'
```

### Recomendación

**Opción 1: Usar Autenticación Local (Recomendado)**
- Usar autenticación local de Open WebUI por ahora
- Crear usuarios directamente en Open WebUI
- Esperar a una actualización de Open WebUI que mejore el soporte OIDC

**Opción 2: Monitorear Actualizaciones**
- Monitorear [Open WebUI GitHub Issues](https://github.com/open-webui/open-webui/issues)
- Buscar issues relacionados con "OIDC", "Keycloak", "discovery document", "405 error"

### Troubleshooting Open WebUI

**Error: "Invalid parameter: redirect_uri"**

**Causa**: El Redirect URI en Keycloak no coincide exactamente.

**Solución**:
- En Keycloak → Clients → open-webui → Settings
- **Valid redirect URIs** debe ser exactamente: `http://localhost:3000/oauth/oidc/callback`
- Sin espacios, sin trailing slash
- Puede que también necesites: `http://localhost:3000/auth/oidc/callback` (agrega ambos si es necesario)

**Error: "Unsupported token_type: 'access_token'"**

**Causa**: Keycloak está devolviendo solo `access_token` pero Open WebUI espera `id_token`.

**Soluciones intentadas (sin éxito)**:
1. Verificar que `openid` scope esté en la solicitud
2. Verificar Default Client Scopes incluyan `profile` y `email`
3. Verificar Standard flow esté habilitado
4. Verificar Access Token Type en Advanced settings
5. Deshabilitar "OAuth 2.0 Compatibility Mode"

**No aparece el botón de Keycloak**

**Causa**: `OPENID_PROVIDER_URL` no está configurado o es incorrecto.

**Solución**:
- Verifica que `OPENID_PROVIDER_URL` esté configurado
- Verifica que `OPENID_ENABLED=true`
- Recrea Open WebUI: `docker compose up -d --force-recreate open-webui`

**Error: "You do not have permission to access this resource"**

**Causa**: Usuario autenticado pero no autorizado.

**Solución**:
- Asegúrate de que `ENABLE_OAUTH_SIGNUP=true` esté configurado
- Esto permite registro automático de usuarios OAuth

---

## ⏳ n8n + Keycloak

### Estado: Configurado - Pendiente Probar

n8n tiene mejor soporte para OIDC que Open WebUI y debería funcionar correctamente, similar a Grafana.

### Configuración

**Variables en docker-compose.yml:**
```yaml
environment:
  - N8N_AUTH_TYPE=oidc
  - N8N_OIDC_ISSUER=http://localhost:8080/realms/master
  - N8N_OIDC_CLIENT_ID=n8n
  - N8N_OIDC_CLIENT_SECRET=${N8N_OIDC_CLIENT_SECRET}
  - N8N_OIDC_AUTHORIZATION_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
  - N8N_OIDC_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
  - N8N_OIDC_USER_INFO_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
  - N8N_OIDC_REDIRECT_URI=http://localhost:5678/rest/oauth2-credential/callback
  - N8N_OIDC_SCOPES=openid profile email
```

**Cliente en Keycloak:**
- Client ID: `n8n`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Valid redirect URIs: `http://localhost:5678/rest/oauth2-credential/callback`
- Web origins: `http://localhost:5678`

### Pasos para Configurar

1. **Configurar cliente en Keycloak:**
   ```bash
   ./scripts/keycloak-manager.sh setup n8n
   ```
   O manualmente:
   - Abre Keycloak: http://localhost:8080
   - Clients → Create client
   - Client ID: `n8n`
   - Client authentication: On
   - Standard flow: Enabled
   - Valid redirect URIs: `http://localhost:5678/rest/oauth2-credential/callback`
   - Web origins: `http://localhost:5678`
   - Copia el Client Secret

2. **Agregar secret a .env:**
   ```bash
   N8N_OIDC_CLIENT_SECRET=<el_secret_de_keycloak>
   ```

3. **Recrear contenedor:**
   ```bash
   docker compose up -d --force-recreate n8n
   ```

4. **Probar:**
   - Abre n8n: http://localhost:5678
   - Deberías ver opción de login con Keycloak

### Troubleshooting

**Error: "Invalid redirect URI"**
- Verifica que el Redirect URI en Keycloak sea exactamente: `http://localhost:5678/rest/oauth2-credential/callback`

**Error: "Client authentication failed"**
- Verifica el Client Secret en Keycloak
- Verifica que `N8N_OIDC_CLIENT_SECRET` en `.env` sea correcto
- Recrea el contenedor

---

## ⏳ Jenkins + Keycloak

### Estado: Pendiente

Jenkins requiere plugin de Keycloak para autenticación.

### Plan de Implementación

1. Instalar plugin "Keycloak Authentication" en Jenkins
2. Configurar plugin con datos de Keycloak
3. Crear cliente "jenkins" en Keycloak
4. Probar login

---

## 🔍 Troubleshooting General

### Problemas Comunes

**1. Error: "Invalid redirect URI"**
- Verifica que el Redirect URI en Keycloak coincida exactamente con el configurado en la aplicación
- Incluye protocolo (`http://`), host (`localhost`), puerto y ruta completa
- Sin espacios, sin trailing slash

**2. Error: "Client authentication failed"**
- Verifica que el Client Secret en Keycloak coincida con el configurado en la aplicación
- Verifica que el cliente tenga "Client authentication: On" si es confidential

**3. Error: "Connection refused" al obtener token**
- Verifica que Keycloak esté corriendo
- Verifica que la aplicación esté en la misma red Docker que Keycloak
- Verifica que las URLs de token/userinfo usen `keycloak:8080` (no `localhost:8080`)

**4. Error: "ERR_CONNECTION_REFUSED" en navegador**
- Verifica que Keycloak esté corriendo
- Verifica que las URLs de autorización/logout usen `localhost:8080` (no `keycloak:8080`)

**5. Error: "Login provider denied login request"**
- Limpia cookies de Keycloak del navegador (usa ventana incógnito)
- Reinicia Keycloak para limpiar sesiones
- Verifica que el usuario exista en Keycloak

### Verificar Configuración

**Verificar Keycloak:**
```bash
docker compose --profile security ps keycloak
docker compose --profile security logs keycloak --tail 50
```

**Verificar cliente en Keycloak:**
1. Abre Keycloak: http://localhost:8080
2. Clients → [nombre-del-cliente]
3. Verifica:
   - Client authentication: On (si es confidential)
   - Standard flow: Enabled
   - Valid redirect URIs: Correcto
   - Web origins: Correcto
   - Client Secret: Copiado correctamente

**Verificar variables de entorno:**
```bash
docker compose exec [servicio] env | grep -E "OIDC|OAUTH|KEYCLOAK"
```

### Limpiar Sesiones

Si hay problemas con sesiones:
1. **Usa ventana incógnito** (más fácil)
2. O limpia cookies manualmente: F12 → Application → Cookies → `http://localhost:8080`
3. O reinicia Keycloak: `docker compose --profile security restart keycloak`

### Checklist General de Cliente Keycloak

Para cualquier cliente OIDC/OAuth en Keycloak:

**Settings:**
- [ ] Client ID: Correcto
- [ ] Client authentication: On (si es confidential)
- [ ] Standard flow: Enabled
- [ ] Valid redirect URIs: Exacto (sin espacios, sin trailing slash)
- [ ] Web origins: Correcto

**Credentials:**
- [ ] Client Secret copiado y configurado en la aplicación

**Client Scopes:**
- [ ] Default Client Scopes incluyen: `profile`, `email`
- [ ] El scope `openid` se solicita automáticamente (no necesita asignarse)

---

## 📚 Referencias

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Grafana OAuth Documentation](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/)
- [n8n OAuth Documentation](https://docs.n8n.io/hosting/authentication/oauth/)
- [Open WebUI GitHub Issues](https://github.com/open-webui/open-webui/issues)

---

**Última actualización**: 2025-12-07
