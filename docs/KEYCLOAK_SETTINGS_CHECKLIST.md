# ✅ Checklist de Configuración Keycloak-Grafana

## 🔍 Verificación Paso a Paso en Keycloak Admin

Accede a: http://localhost:8080/admin (login: admin / admin)

### 1. Cliente "grafana" → Settings

**General settings:**
- [ ] Client ID: `grafana`
- [ ] Name: `grafana` (o cualquier nombre)

**Access settings:**
- [ ] Root URL: `http://localhost:3001`
- [ ] Home URL: `http://localhost:3001`
- [ ] **Valid redirect URIs**: `http://localhost:3001/login/generic_oauth` ⚠️ **EXACTO, sin espacios**
- [ ] Web Origins: `http://localhost:3001`
- [ ] Admin URL: `http://localhost:3001` (opcional)

**Capability config:**
- [ ] ✅ **Client authentication**: `On`
- [ ] ✅ **Standard flow**: Marcado ⚠️ **ESTE ES EL QUE USA GRAFANA**
- [ ] ⬜ **Direct access grants**: NO es necesario para Grafana (solo para otros flujos)
- [ ] ❌ Implicit flow: Desmarcado (no necesario)

**Login settings:**
- [ ] Consent required: `Off` (normalmente)
- [ ] Display client on screen: `Off` (normalmente)

### 2. Cliente "grafana" → Credentials

- [ ] Client Authenticator: `Client Id and Secret`
- [ ] **Client Secret**: Copia este valor
- [ ] Verifica que coincida con `docker-compose.yml`:
  ```bash
  grep GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET docker-compose.yml
  ```

### 3. Usuarios

- [ ] Hay al menos un usuario creado (además de admin)
- [ ] El usuario tiene contraseña establecida
- [ ] La contraseña NO es temporal (campo "Temporary" desmarcado)

## 🔧 Configuración en docker-compose.yml

Verifica estas variables en `docker-compose.yml`:

```yaml
- GF_AUTH_GENERIC_OAUTH_ENABLED=true
- GF_AUTH_GENERIC_OAUTH_NAME=Keycloak
- GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
- GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=pr85OgKszvS0KOpVnlzYjM0c0Rp9nQXw
- GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
- GF_AUTH_GENERIC_OAUTH_AUTH_URL=http://localhost:8080/realms/master/protocol/openid-connect/auth
- GF_AUTH_GENERIC_OAUTH_TOKEN_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token
- GF_AUTH_GENERIC_OAUTH_API_URL=http://keycloak:8080/realms/master/protocol/openid-connect/userinfo
- GF_AUTH_SIGNOUT_REDIRECT_URL=http://localhost:8080/realms/master/protocol/openid-connect/logout
```

## 🐛 Problemas Comunes y Soluciones

### "Restart login cookie not found"
- ✅ Habilita "Direct access grants"
- ✅ Verifica Redirect URI exacto
- ✅ Reinicia Keycloak y Grafana

### "Login provider denied login request"
- ✅ Verifica Client Secret coincide
- ✅ Verifica Redirect URI exacto
- ✅ Limpia cookies o usa ventana incógnito

### "Invalid redirect URI"
- ✅ Redirect URI debe ser EXACTAMENTE: `http://localhost:3001/login/generic_oauth`
- ✅ Sin espacios
- ✅ Sin trailing slash
- ✅ Protocolo correcto (http, no https)

### "Invalid client credentials"
- ✅ Copia Client Secret de Keycloak
- ✅ Actualiza en docker-compose.yml
- ✅ Reinicia Grafana

## 📋 Orden de Verificación

1. ✅ Keycloak corriendo
2. ✅ Grafana corriendo
3. ✅ Cliente "grafana" existe
4. ✅ "Direct access grants" habilitado
5. ✅ Redirect URI exacto
6. ✅ Client Secret coincide
7. ✅ Usuario creado con contraseña no temporal
8. ✅ Servicios reiniciados después de cambios

---

**Última actualización**: $(date)

