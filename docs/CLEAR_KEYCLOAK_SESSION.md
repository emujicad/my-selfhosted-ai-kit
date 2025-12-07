# 🧹 Cómo Limpiar Sesión de Keycloak

## 🚀 Método Más Fácil: Ventana de Incógnito

**La forma más rápida de solucionar el problema:**

1. **Cierra todas las ventanas de Grafana y Keycloak**
2. **Abre una ventana de incógnito/privada**:
   - **Chrome/Edge**: `Ctrl+Shift+N` (Windows/Linux) o `Cmd+Shift+N` (Mac)
   - **Firefox**: `Ctrl+Shift+P` (Windows/Linux) o `Cmd+Shift+P` (Mac)
3. **Ve a Grafana**: http://localhost:3001
4. **Haz clic en "Sign in with Keycloak"**
5. **Ingresa credenciales**: `admin` / `admin`

✅ **Esto debería funcionar inmediatamente**

---

## 🔧 Método Alternativo: Limpiar Cookies Manualmente

### En Chrome/Edge:

1. **Abre las herramientas de desarrollador**:
   - Presiona `F12` o `Ctrl+Shift+I` (Windows/Linux) o `Cmd+Option+I` (Mac)

2. **Ve a la pestaña "Application"** (Chrome) o "Storage" (Edge):
   - Si no ves las pestañas, haz clic en el ícono `>>` para expandir

3. **En el menú lateral izquierdo**:
   - Expande **Storage** o **Application**
   - Expande **Cookies**
   - Haz clic en `http://localhost:8080`

4. **Elimina las cookies**:
   - Verás una lista de cookies en el panel derecho
   - Haz clic derecho en cada cookie → **Delete**
   - O selecciona todas y presiona `Delete`

### En Firefox:

1. **Abre las herramientas de desarrollador**:
   - Presiona `F12` o `Ctrl+Shift+I`

2. **Ve a la pestaña "Storage"**:
   - Haz clic en "Storage" en la barra superior

3. **En el menú lateral**:
   - Expande **Cookies**
   - Haz clic en `http://localhost:8080`

4. **Elimina las cookies**:
   - Selecciona las cookies y presiona `Delete`

---

## 🎯 Método Más Simple: Cerrar Sesión en Keycloak

1. **Abre Keycloak**: http://localhost:8080
2. **Si hay una sesión activa**, busca el botón de "Sign Out" o "Logout"
3. **Haz clic en logout**
4. **Luego intenta login en Grafana**

---

## 🔄 Método de Reinicio: Limpiar Todo

Si nada funciona, reinicia los servicios:

```bash
# Reiniciar Keycloak (esto limpia todas las sesiones)
docker compose --profile security restart keycloak

# Esperar 30 segundos
sleep 30

# Reiniciar Grafana
docker compose --profile monitoring restart grafana

# Esperar 10 segundos
sleep 10

# Probar en ventana incógnito
```

---

## 📋 Pasos Visuales para Chrome

1. **Presiona F12** (o clic derecho → Inspeccionar)
2. **Busca la pestaña "Application"** en la parte superior
3. **En el panel izquierdo**, busca "Cookies"
4. **Expande "Cookies"**
5. **Haz clic en `http://localhost:8080`**
6. **En el panel derecho**, verás todas las cookies
7. **Selecciona todas** (Ctrl+A) y presiona **Delete**

---

## ✅ Recomendación Final

**Usa ventana de incógnito** - Es el método más rápido y efectivo:
- No requiere limpiar cookies manualmente
- No afecta otras sesiones
- Funciona inmediatamente

---

**Última actualización**: $(date)

