# ✅ Solución Simple: Grafana + Keycloak Login

## 🎯 El Problema

No puedes hacer login en Grafana usando Keycloak OAuth.

## 🔧 Solución en 3 Pasos (SIN COMPLICACIONES)

### Paso 1: Verificar Cliente en Keycloak (2 minutos)

1. Abre: http://localhost:8080/admin
2. Login: `admin` / `admin`
3. Ve a: **Clients** → busca **"grafana"**
4. Si NO existe, créalo:
   - Click "Create client"
   - Client ID: `grafana`
   - Protocol: `openid-connect`
   - Click "Next"
   - Access Type: `confidential`
   - Standard Flow: ✅
   - Direct Access Grants: ✅
   - Redirect URI: `http://localhost:3001/login/generic_oauth`
   - Web Origins: `http://localhost:3001`
   - Click "Save"

5. Si YA existe, solo verifica:
   - Ve a Settings
   - Verifica que "Standard flow" esté marcado ✅ (esto es suficiente)
   - Verifica Redirect URI: `http://localhost:3001/login/generic_oauth`
   - Click "Save"

### Paso 2: Copiar Client Secret (1 minuto)

1. En el cliente "grafana", ve a la pestaña **"Credentials"**
2. Copia el valor de **"Secret"**
3. Verifica que coincida con `docker-compose.yml`:
   ```bash
   grep GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET docker-compose.yml
   ```
4. Si NO coincide, actualiza `docker-compose.yml` con el Secret correcto

### Paso 3: Probar Login (30 segundos)

1. Abre: http://localhost:3001
2. Click "Sign in with Keycloak"
3. Usa: `admin` / `admin` (credenciales de Keycloak)
4. Deberías quedar logueado ✅

## 🐛 Si Aún No Funciona

### Opción A: Reiniciar Servicios
```bash
docker compose --profile security restart keycloak
docker compose --profile monitoring restart grafana
sleep 10
```

### Opción B: Usar Ventana Incógnito
- Abre una ventana de incógnito
- Ve a http://localhost:3001
- Prueba login

### Opción C: Verificar Logs
```bash
# Ver errores de Grafana
docker compose --profile monitoring logs grafana | tail -50

# Ver errores de Keycloak
docker compose --profile security logs keycloak | tail -50
```

## 📋 Checklist Rápido

- [ ] Cliente "grafana" existe en Keycloak
- [ ] "Direct access grants" está marcado ✅
- [ ] Redirect URI es exactamente: `http://localhost:3001/login/generic_oauth`
- [ ] Client Secret coincide en Keycloak y docker-compose.yml
- [ ] Keycloak está corriendo (puerto 8080)
- [ ] Grafana está corriendo (puerto 3001)
- [ ] Usas credenciales de Keycloak (admin/admin), NO de Grafana

## 💡 Por Qué Era Más Fácil Antes

Probablemente antes:
- ✅ El cliente ya estaba creado correctamente
- ✅ "Direct access grants" ya estaba habilitado
- ✅ No había problemas de cookies/sesiones

Ahora necesitamos verificar que todo esté configurado correctamente.

---

**Consejo**: Si sigues teniendo problemas, comparte los logs de Grafana y Keycloak para diagnosticar mejor.

