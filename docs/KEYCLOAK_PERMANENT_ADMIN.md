# Keycloak Permanent Admin User - Quick Start Guide

## 🎯 Objetivo

Reemplazar el usuario administrador temporal de Keycloak con un usuario permanente para mejorar la seguridad.

---

## ⚡ Uso Rápido

### Opción 1: Configuración Automática (Recomendada)

```bash
# 1. Configurar credenciales en .env
nano .env

# Añadir estas líneas:
KEYCLOAK_PERMANENT_ADMIN_USERNAME=emujicad
KEYCLOAK_PERMANENT_ADMIN_EMAIL=emujicad@gmail.com
KEYCLOAK_PERMANENT_ADMIN_PASSWORD=tu_contraseña_segura_aquí

# 2. Ejecutar el script
./scripts/keycloak-create-permanent-admin.sh

# 3. Seguir las instrucciones en pantalla
```

### Opción 2: Configuración Interactiva

```bash
# Ejecutar sin configurar .env
# El script te pedirá la contraseña interactivamente
./scripts/keycloak-create-permanent-admin.sh
```

---

## 📋 Qué Hace el Script

1. ✅ **Conecta a Keycloak** usando el admin temporal
2. ✅ **Crea nuevo usuario** con tus credenciales
3. ✅ **Establece contraseña** permanente (no temporal)
4. ✅ **Asigna rol admin** al nuevo usuario
5. ✅ **Verifica login** del nuevo usuario
6. ⚠️ **Pregunta antes de eliminar** el usuario temporal
7. ✅ **Elimina usuario temporal** (si confirmas)

---

## 🔒 Seguridad

### Requisitos de Contraseña Recomendados

- Mínimo 12 caracteres
- Incluir mayúsculas y minúsculas
- Incluir números
- Incluir caracteres especiales
- No usar contraseñas comunes

### Ejemplo de Contraseña Segura

```
MyS3cur3P@ssw0rd!2026
```

---

## ✅ Verificación Post-Ejecución

### 1. Probar Login con Nuevo Usuario

```bash
# Acceder a Keycloak
http://localhost:8080

# Credenciales
Username: emujicad
Password: <tu_contraseña>
```

### 2. Verificar que NO Aparece la Advertencia

Antes:
```
⚠️ You are logged in as a temporary admin user.
```

Después:
```
✅ No warning message
```

### 3. Actualizar .env

Después de verificar que funciona, actualiza `.env`:

```bash
# Cambiar de:
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=<old_password>

# A:
KEYCLOAK_ADMIN=emujicad
KEYCLOAK_ADMIN_PASSWORD=<new_password>
```

---

## 🚨 Troubleshooting

### Error: "Failed to get access token"

**Causa**: Credenciales incorrectas del admin temporal

**Solución**:
```bash
# Verificar credenciales en .env
grep KEYCLOAK_ADMIN .env

# Probar login manual
curl -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -d "username=admin" \
  -d "password=<tu_password>" \
  -d "grant_type=password" \
  -d "client_id=admin-cli"
```

### Error: "User already exists"

**Causa**: El usuario permanente ya fue creado anteriormente

**Solución**:
- El script te preguntará si quieres actualizar la contraseña
- Responde `y` para actualizar
- O elimina el usuario manualmente desde Keycloak Admin Console

### Error: "New admin user cannot login"

**Causa**: Problema al crear el usuario o asignar permisos

**Solución**:
- El script NO eliminará el usuario temporal por seguridad
- Revisa los logs del script
- Verifica manualmente en Keycloak Admin Console

---

## 🔐 Configurar 2FA (Opcional)

### ¿Qué es 2FA?

Autenticación de dos factores usando una app móvil (Google Authenticator, Microsoft Authenticator, Authy).

### Cómo Habilitar

1. **Acceder a Keycloak** con tu nuevo usuario
2. **Ir a tu perfil** (click en tu nombre → Account)
3. **Ir a "Signing In"**
4. **Click en "Set up Authenticator application"**
5. **Escanear QR** con tu app de autenticación
6. **Ingresar código** de verificación

### Apps Recomendadas

- **Google Authenticator** (iOS/Android)
- **Microsoft Authenticator** (iOS/Android)
- **Authy** (iOS/Android/Desktop)
- **FreeOTP** (Open Source)

### Resultado

Después de habilitar 2FA:
- Login requiere contraseña + código de 6 dígitos
- Código cambia cada 30 segundos
- Mayor seguridad contra acceso no autorizado

---

## 📝 Próximos Pasos

Después de crear el usuario permanente:

1. ✅ **Configurar políticas de contraseña** (opcional)
   - Ir a: Authentication → Policies → Password Policy
   - Configurar requisitos mínimos

2. ✅ **Configurar roles y grupos** (siguiente fase)
   - Ejecutar: `./scripts/keycloak-roles-manager.sh all`

3. ✅ **Habilitar 2FA** (recomendado)
   - Seguir pasos arriba

4. ✅ **Hacer backup** de la configuración
   - Ejecutar: `./scripts/backup-manager.sh backup`

---

## 🎓 Conceptos Clave

### Usuario Temporal vs Permanente

| Aspecto | Temporal | Permanente |
|---------|----------|------------|
| **Propósito** | Setup inicial | Uso diario |
| **Seguridad** | Baja (credenciales por defecto) | Alta (credenciales personalizadas) |
| **Advertencia** | ⚠️ Muestra warning | ✅ Sin warning |
| **Recomendación** | Eliminar después del setup | Mantener |

### ¿Por qué Eliminar el Temporal?

1. **Seguridad**: Credenciales conocidas/predecibles
2. **Mejores prácticas**: Keycloak lo recomienda explícitamente
3. **Auditoría**: Saber quién hace qué
4. **Compliance**: Requisito en muchos estándares de seguridad

---

## 📚 Referencias

- [Keycloak Admin CLI](https://www.keycloak.org/docs/latest/server_admin/#admin-cli)
- [Keycloak Security Hardening](https://www.keycloak.org/docs/latest/server_admin/#_hardening)
- [OWASP Password Guidelines](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
