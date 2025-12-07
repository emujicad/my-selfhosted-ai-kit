# 🔧 Solución: "Login provider denied login request"

## 🔍 Problema Identificado

Los logs muestran dos problemas principales:

1. **`error="already_logged_in"`** en Keycloak
   - Hay una sesión activa de Keycloak que está causando conflictos
   - Keycloak piensa que ya estás logueado

2. **`error="authentication_expired"`** en Grafana
   - La autenticación expiró antes de completarse
   - El flujo OAuth se interrumpió

## ✅ Soluciones Paso a Paso

### Solución 1: Limpiar Sesiones de Keycloak (RECOMENDADO)

El problema más común es tener sesiones activas conflictivas.

**Opción A: Limpiar cookies del navegador**
1. Abre las herramientas de desarrollador (F12)
2. Ve a la pestaña **Application** (Chrome) o **Storage** (Firefox)
3. En el menú lateral, expande **Cookies**
4. Selecciona `http://localhost:8080`
5. Elimina todas las cookies (especialmente las relacionadas con sesión)
6. Cierra y vuelve a abrir el navegador
7. Intenta login nuevamente

**Opción B: Usar ventana de incógnito**
1. Abre una ventana de incógnito/privada
2. Ve a http://localhost:3001
3. Haz clic en "Sign in with Keycloak"
4. Ingresa credenciales

**Opción C: Cerrar sesión en Keycloak primero**
1. Ve a http://localhost:8080
2. Si hay una sesión activa, haz logout
3. Luego intenta login en Grafana

### Solución 2: Verificar y Crear Usuario en Keycloak

Si no recuerdas qué usuario usabas:

1. **Ver usuarios existentes**:
   - Accede a: http://localhost:8080/admin
   - Login: `admin` / `admin`
   - Ve a: **Users**
   - Verás todos los usuarios disponibles

2. **Crear un nuevo usuario**:
   - En Keycloak Admin: **Users** → **Add user**
   - **Username**: `grafana-user` (o el que prefieras)
   - **Email**: (opcional)
   - Haz clic en **Create**
   - Ve a la pestaña **Credentials**
   - Haz clic en **Set Password**
   - Ingresa contraseña
   - ⚠️ **DESMARCA "Temporary"** (muy importante)
   - Haz clic en **Save**

3. **Usar el nuevo usuario**:
   - Ve a Grafana: http://localhost:3001
   - Haz clic en "Sign in with Keycloak"
   - Ingresa las credenciales del usuario que acabas de crear

### Solución 3: Verificar Configuración del Cliente Grafana

Asegúrate de que el cliente "grafana" esté configurado correctamente:

1. **En Keycloak Admin**: http://localhost:8080/admin
2. **Ve a**: Clients → grafana → Settings
3. **Verifica**:
   - ✅ **Client authentication**: `On`
   - ✅ **Standard flow**: Marcado
   - ✅ **Valid Redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - ✅ **Web Origins**: `http://localhost:3001`
4. **Haz clic en Save**

5. **Ve a la pestaña Credentials**:
   - Copia el **Client Secret**
   - Verifica que coincida con `docker-compose.yml`:
     ```bash
     grep GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET docker-compose.yml
     ```
   - Si no coincide, actualiza `docker-compose.yml` y reinicia Grafana:
     ```bash
     docker compose --profile monitoring restart grafana
     ```

### Solución 4: Reiniciar Servicios

A veces un reinicio limpia problemas de sesión:

```bash
# Reiniciar Keycloak
docker compose --profile security restart keycloak

# Esperar 30 segundos
sleep 30

# Reiniciar Grafana
docker compose --profile monitoring restart grafana

# Esperar 10 segundos
sleep 10

# Probar login nuevamente
```

## 🔍 Verificación de Usuarios

### Ver usuarios desde la línea de comandos:

```bash
docker compose --profile security exec keycloak /opt/keycloak/bin/kcadm.sh get users -r master
```

### Ver usuarios desde la UI:

1. http://localhost:8080/admin
2. Login: `admin` / `admin`
3. Ve a: **Users**
4. Verás la lista completa de usuarios

## 📋 Checklist de Verificación

Antes de intentar login, verifica:

- [ ] Keycloak está corriendo: `docker compose --profile security ps keycloak`
- [ ] Grafana está corriendo: `docker compose --profile monitoring ps grafana`
- [ ] Cliente "grafana" existe en Keycloak
- [ ] Redirect URI está configurado: `http://localhost:3001/login/generic_oauth`
- [ ] Client Secret coincide entre Keycloak y docker-compose.yml
- [ ] Hay al menos un usuario creado en Keycloak (además de admin)
- [ ] Las cookies de Keycloak están limpias (o usar ventana incógnito)

## 🎯 Pasos Recomendados (En Orden)

1. **Limpia cookies de Keycloak** (Solución 1)
2. **Verifica usuarios en Keycloak** (Solución 2)
3. **Crea un usuario nuevo si es necesario** (Solución 2)
4. **Verifica configuración del cliente** (Solución 3)
5. **Reinicia servicios si es necesario** (Solución 4)
6. **Prueba login en ventana incógnito**

## 🐛 Si Nada Funciona

Ejecuta el script de diagnóstico:

```bash
./scripts/fix-grafana-keycloak.sh
```

Este script te mostrará:
- Estado de los servicios
- Configuración actual
- Logs recientes
- Soluciones específicas

---

**Última actualización**: $(date)

