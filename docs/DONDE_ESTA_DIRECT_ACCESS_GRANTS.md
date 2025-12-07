# 📍 Dónde Encontrar "Direct Access Grants" en Keycloak 26.3.1

## 🎯 Ubicación Exacta (Paso a Paso Visual)

### Paso 1: Accede a Keycloak Admin
- URL: http://localhost:8080/admin
- Login: `admin` / `admin`

### Paso 2: Ve a Clients
- En el menú lateral izquierdo, haz clic en **"Clients"**
- Verás una lista de clientes

### Paso 3: Abre el Cliente "grafana"
- Busca el cliente llamado **"grafana"** en la lista
- Haz clic en él (puede ser el nombre o el Client ID)

### Paso 4: Ve a la Pestaña "Settings"
- Una vez dentro del cliente, verás varias pestañas arriba:
  - **Settings** ← **HAZ CLIC AQUÍ**
  - Credentials
  - Roles
  - etc.

### Paso 5: Desplázate Hacia Abajo
- En la página de Settings, desplázate hacia abajo
- Busca la sección que dice **"Capability config"** o **"Capabilities"**

### Paso 6: Busca "Direct access grants"
- En la sección "Capability config", verás varias casillas:
  - ✅ **Client authentication** (puede estar marcado)
  - ✅ **Standard flow** (debe estar marcado)
  - ⬜ **Direct access grants** ← **ESTA ES LA QUE BUSCAS**
  - ⬜ Implicit flow
  - ⬜ Direct access grants (puede aparecer dos veces en algunas versiones)

### Paso 7: Marca la Casilla
- Haz clic en la casilla para marcar ✅ **"Direct access grants"**
- Haz clic en **"Save"** (botón abajo de la página)

## 🖼️ Ruta Visual Completa

```
Keycloak Admin Console
  └─ Menú Lateral: "Clients"
      └─ Cliente: "grafana"
          └─ Pestaña: "Settings"
              └─ Sección: "Capability config"
                  └─ Casilla: "Direct access grants" ✅
                      └─ Botón: "Save"
```

## 🔍 Si No Encuentras "Capability config"

En algunas versiones de Keycloak, puede estar en:

### Opción A: En "Access settings"
- Busca la sección **"Access settings"**
- Puede estar ahí junto con "Standard flow"

### Opción B: En la Parte Superior
- A veces está en la parte superior de Settings
- Busca casillas con nombres como:
  - "Standard flow enabled"
  - "Direct access grants enabled"
  - "Implicit flow enabled"

### Opción C: Buscar con Ctrl+F
- Presiona `Ctrl+F` (o `Cmd+F` en Mac)
- Busca: `direct access`
- Te llevará directamente a la opción

## ⚠️ Importante

- **NO confundas** con "Client authentication" (esa es diferente)
- **NO confundas** con "Standard flow" (esa ya debe estar marcada)
- La que necesitas es específicamente **"Direct access grants"**

## ✅ Verificación Rápida

Después de marcar y guardar:
1. La casilla debe quedar marcada ✅
2. Debe aparecer un mensaje verde "Client updated" o similar
3. Espera 5-10 segundos
4. Prueba login en Grafana nuevamente

---

**Versión de Keycloak**: 26.3.1
**Última actualización**: $(date)

