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

**⚠️ IMPORTANTE - Configuración del Cliente en Keycloak:**

**Nota sobre la documentación oficial de Grafana:**
La [documentación oficial de Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/keycloak/) recomienda que `roles` esté en **"Default Client Scopes"** para permitir el mapeo de roles usando `role_attribute_path`. Sin embargo, en nuestro caso específico, esta configuración causó el error "cannot remove last organization admin" porque el usuario `admin` en Keycloak tiene realm roles que Grafana intentó sincronizar.

**Nuestra configuración (solución específica para nuestro caso):**
- **`fullScopeAllowed` debe estar en `false`** (NO en `true`)
- El scope `roles` debe estar en **"Optional"** (NO en "Default")
- Esto evita que Keycloak devuelva roles automáticamente
- Grafana no recibirá roles y no intentará sincronizarlos
- Esto previene el error "cannot remove last organization admin"
- Combinado con `SKIP_ORG_ROLE_SYNC=true` en Grafana, proporciona una capa adicional de protección

**Si quieres seguir la documentación oficial de Grafana:**
- Deja `roles` en **"Default Client Scopes"**
- Configura `role_attribute_path` en Grafana para mapear roles
- NO uses `SKIP_ORG_ROLE_SYNC=true`
- Asegúrate de que los usuarios en Keycloak tengan roles específicos (`admin`, `editor`, `viewer`) asignados correctamente

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
- **`fullScopeAllowed`: `false`** (CRÍTICO - previene envío automático de roles)
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
   - ⚠️ **CRÍTICO**: En **Settings**, asegúrate de que **`fullScopeAllowed`** esté en **`false`**
   - **Valid redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - **Web origins**: `http://localhost:3001`
   - Ve a la pestaña **Credentials** y copia el **Client Secret**
   - ⚠️ **CRÍTICO**: Ve a la pestaña **Client scopes**
     - En la fila de `roles`, cambia "Assigned type" de **"Default"** a **"Optional"**
     - Esto previene el error "cannot remove last organization admin"
   
   **O usa el script automatizado** (recomendado):
   ```bash
   ./scripts/recreate-keycloak-clients.sh
   ```
   Este script configura todo automáticamente.

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

**Error: "User sync failed" / "cannot remove last organization admin"**

**Causa**: Keycloak está devolviendo roles en el token/userinfo (porque 'roles' está en Default Client Scopes), y Grafana intenta sincronizar estos roles, cambiando el rol del admin de "Admin" a "Viewer", lo cual falla porque es el último admin de la organización.

**Solución CORRECTA**:
1. **En Keycloak Admin UI**:
   - Ve a: **Clients** → **grafana** → **Settings**
   - Asegúrate de que **`fullScopeAllowed`** esté en **`false`** (NO en `true`)
   - Ve a la pestaña **Client scopes**
   - En la fila de `roles`, cambia "Assigned type" de **"Default"** a **"Optional"**
   - Esto hace que Keycloak NO incluya roles automáticamente en los tokens
   - Como Grafana no solicita explícitamente el scope `roles`, no los recibirá
   - Grafana no intentará sincronizar roles y el error desaparecerá

2. **Alternativa: Usar el script automatizado**:
   ```bash
   ./scripts/recreate-keycloak-clients.sh
   ```
   Este script configura automáticamente `fullScopeAllowed=false` y mueve `roles` a Optional.

2. **Si el usuario admin ya existe en Grafana**, vincularlo manualmente con Keycloak (solo necesario la primera vez):
   ```bash
   # Acceder a la BD de Grafana
   docker run --rm -v my-selfhosted-ai-kit_grafana_data:/var/lib/grafana -it alpine sh
   apk add sqlite
   sqlite3 /var/lib/grafana/grafana.db
   
   # Vincular usuario admin (ID 1) con auth_id de Keycloak
   INSERT INTO user_auth (user_id, auth_module, auth_id, created)
   VALUES (1, 'oauth_generic_oauth', 'd2e70cd9-7d55-499d-ab05-b355422846ff', datetime('now'));
   ```
   ⚠️ **Nota**: El `auth_id` debe obtenerse de los logs de Grafana cuando intentas hacer login.

**Nota sobre `SKIP_ORG_ROLE_SYNC`**:
- `GF_AUTH_GENERIC_OAUTH_SKIP_ORG_ROLE_SYNC=true` está configurado en `docker-compose.yml` como medida de seguridad adicional
- Esto es necesario porque el usuario `admin` en Keycloak tiene realm roles (`default-roles-master`, `admin`) que Keycloak puede incluir automáticamente incluso con `fullScopeAllowed=false`
- Con `fullScopeAllowed=false` y `roles` en Optional, `SKIP_ORG_ROLE_SYNC` actúa como una capa adicional de protección
- **Nota**: La documentación oficial de Grafana no menciona `SKIP_ORG_ROLE_SYNC` porque asume que los roles se gestionan correctamente en Keycloak. En nuestro caso, usamos esta opción para evitar conflictos con usuarios existentes

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
  # Configuración OAuth (consolidado - OpenID usa variables OAUTH_ según documentación oficial)
  - ENABLE_OAUTH_SSO=${OPEN_WEBUI_ENABLE_OAUTH_SSO:-true}
  - ENABLE_OAUTH_SIGNUP=${OPEN_WEBUI_ENABLE_OAUTH_SIGNUP:-true}
  - OAUTH_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID:-open-webui}
  - OAUTH_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}
  - OAUTH_PROVIDER_NAME=${OPEN_WEBUI_OAUTH_PROVIDER_NAME:-Keycloak}
  # Configuración OpenID (usa variables OAUTH_ - consolidado según documentación oficial)
  - OPENID_ENABLED=${OPEN_WEBUI_OAUTH_ENABLED:-true}
  - OPENID_CLIENT_ID=${OPEN_WEBUI_OAUTH_CLIENT_ID:-open-webui}
  - OPENID_CLIENT_SECRET=${OPEN_WEBUI_OAUTH_CLIENT_SECRET}
  - OPENID_PROVIDER_URL=${KEYCLOAK_URL_INTERNAL:-http://keycloak:8080}/realms/${KEYCLOAK_REALM:-master}/.well-known/openid-configuration
  - OPENID_REDIRECT_URI=${OPEN_WEBUI_URL_PUBLIC:-http://localhost:3000}/oauth/oidc/callback
  - OPENID_AUTHORIZATION_ENDPOINT=${KEYCLOAK_URL_PUBLIC:-http://localhost:8080}/realms/${KEYCLOAK_REALM:-master}/protocol/openid-connect/auth
  - OPENID_TOKEN_ENDPOINT=${KEYCLOAK_URL_INTERNAL:-http://keycloak:8080}/realms/${KEYCLOAK_REALM:-master}/protocol/openid-connect/token
  - OPENID_USERINFO_ENDPOINT=${KEYCLOAK_URL_INTERNAL:-http://keycloak:8080}/realms/${KEYCLOAK_REALM:-master}/protocol/openid-connect/userinfo
  - OPENID_ISSUER=${KEYCLOAK_URL_PUBLIC:-http://localhost:8080}/realms/${KEYCLOAK_REALM:-master}
  - OPENID_SCOPES=${OPEN_WEBUI_OAUTH_SCOPES:-openid profile email}
  - OPENID_SIGN_OUT_REDIRECT_URL=${KEYCLOAK_URL_PUBLIC:-http://localhost:8080}/realms/${KEYCLOAK_REALM:-master}/protocol/openid-connect/logout
```

**⚠️ IMPORTANTE - Nomenclatura de Variables:**
- Todas las variables de configuración OAuth/OpenID en `.env` usan el prefijo `OPEN_WEBUI_OAUTH_*`
- Esto es consistente con la [documentación oficial de Open WebUI](https://docs.openwebui.com/getting-started/env-configuration/)
- OpenID Connect es una extensión de OAuth 2.0, por lo que usar el prefijo `OAUTH_` es correcto
- En `docker-compose.yml`, las variables `OPENID_*` internas de Open WebUI usan las variables `OAUTH_*` de `.env`
- **No hay variables `OPEN_WEBUI_OPENID_*` en `.env`** - todo está consolidado bajo `OPEN_WEBUI_OAUTH_*`

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

## ✅ Jenkins + Keycloak

### Estado: Configurado - Listo para usar

Jenkins está configurado para usar Keycloak como proveedor OIDC mediante el plugin "OpenId Connect Authentication".

### Configuración Automática

**Script de inicialización:**
```bash
./scripts/init-jenkins-oidc.sh
```

Este script:
1. ✅ Verifica que Jenkins y Keycloak estén corriendo
2. ✅ Instala el plugin "OpenId Connect Authentication" si no está instalado
3. ✅ Configura OIDC con Keycloak automáticamente
4. ✅ Reinicia Jenkins si es necesario

### Variables en .env

```bash
# Jenkins Configuration
JENKINS_URL_PUBLIC=http://localhost:8081
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASSWORD=admin
JENKINS_OIDC_CLIENT_ID=jenkins
JENKINS_OIDC_CLIENT_SECRET=<client_secret_from_keycloak>
JENKINS_OIDC_SCOPES=openid email profile
```

### Pasos para Configurar

1. **Crear cliente en Keycloak:**
   ```bash
   ./scripts/recreate-keycloak-clients.sh
   ```
   Esto creará el cliente `jenkins` en Keycloak y mostrará el Client Secret.

2. **Actualizar Client Secret en .env:**
   ```bash
   JENKINS_OIDC_CLIENT_SECRET=<el_secret_mostrado>
   ```

3. **Levantar Jenkins:**
   ```bash
   docker compose --profile ci-cd up -d jenkins
   ```

4. **Ejecutar script de inicialización:**
   ```bash
   ./scripts/init-jenkins-oidc.sh
   ```

5. **Probar login:**
   - Abre Jenkins: http://localhost:8081
   - Deberías ser redirigido a Keycloak para autenticarte

### Cliente en Keycloak

**Configuración automática:**
- Client ID: `jenkins`
- Client authentication: On (confidential)
- Standard flow: Enabled
- Valid redirect URIs: `http://localhost:8081/securityRealm/finishLogin`
- Web origins: `http://localhost:8081`
- fullScopeAllowed: false

### Troubleshooting

**Error: "Plugin no instalado"**
- El script instalará el plugin automáticamente
- Si falla, instálalo manualmente desde Jenkins UI: Manage Jenkins → Manage Plugins → Available → "OpenId Connect Authentication"

**Error: "Invalid redirect URI"**
- Verifica que el Redirect URI en Keycloak sea exactamente: `http://localhost:8081/securityRealm/finishLogin`
- Verifica que `JENKINS_URL_PUBLIC` en `.env` sea correcto

**Error: "Client authentication failed"**
- Verifica el Client Secret en Keycloak
- Verifica que `JENKINS_OIDC_CLIENT_SECRET` en `.env` sea correcto
- Recrea el cliente si es necesario: `./scripts/recreate-keycloak-clients.sh`

**Jenkins no reinicia después de instalar plugin**
- Espera 2-3 minutos
- Verifica logs: `docker compose --profile ci-cd logs jenkins --tail 50`
- Reinicia manualmente: `docker compose --profile ci-cd restart jenkins`

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

**Última actualización**: 2025-01-07

**Cambios recientes (2025-01-07):**
- **Consolidación de variables Open WebUI**: Todas las variables ahora usan prefijo `OAUTH_` (consolidado según [documentación oficial de Open WebUI](https://docs.openwebui.com/getting-started/env-configuration/))
- **Eliminación de duplicaciones**: Variables OAuth/OpenID duplicadas eliminadas de `.env` y `.env.example`
- **Actualización de Grafana**: `GF_AUTH_GENERIC_OAUTH_SKIP_ORG_ROLE_SYNC` ahora es variable de entorno (`GRAFANA_SKIP_ORG_ROLE_SYNC`)
- **Mejora de nomenclatura**: Variables Open WebUI renombradas de `OPENID_*` a `OAUTH_*` para consistencia y claridad
