# 🔑 Credenciales de Keycloak

## Credenciales por Defecto

Las credenciales por defecto configuradas en `docker-compose.yml` son:

- **Usuario**: `admin`
- **Contraseña**: `admin`

⚠️ **IMPORTANTE**: Estas son credenciales por defecto y **deben cambiarse en producción**.

## Cómo Acceder a Keycloak Admin Console

1. **Asegúrate de que Keycloak esté corriendo**:
   ```bash
   docker compose --profile security ps keycloak
   ```

2. **Accede a la consola de administración**:
   - URL: http://localhost:8080
   - O directamente: http://localhost:8080/admin

3. **Inicia sesión con las credenciales por defecto**:
   - Usuario: `admin`
   - Contraseña: `admin`

## Cambiar las Credenciales

### Opción 1: Cambiar desde docker-compose.yml

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

### Opción 2: Cambiar desde la UI de Keycloak

1. Accede a http://localhost:8080/admin
2. Login con admin/admin
3. Ve a: **Administration Console** → **User** (arriba a la derecha)
4. Selecciona el usuario `admin`
5. Ve a la pestaña **Credentials**
6. Establece una nueva contraseña
7. Desmarca "Temporary" si quieres que sea permanente

## Si Olvidaste las Credenciales

### Método 1: Verificar en docker-compose.yml

Las credenciales están hardcodeadas en `docker-compose.yml`:

```bash
grep KEYCLOAK_ADMIN docker-compose.yml
```

### Método 2: Resetear usando variables de entorno

Si tienes un archivo `.env` con las credenciales:

```bash
cat .env | grep KEYCLOAK
```

### Método 3: Resetear completamente Keycloak

⚠️ **ADVERTENCIA**: Esto eliminará todos los datos de Keycloak.

1. Detén Keycloak:
   ```bash
   docker compose --profile security stop keycloak
   ```

2. Elimina el volumen de datos:
   ```bash
   docker volume rm my-selfhosted-ai-kit_keycloak_data
   ```

3. Levanta Keycloak nuevamente:
   ```bash
   docker compose --profile security up -d keycloak
   ```

4. Espera 30-60 segundos y accede con admin/admin

### Método 4: Crear un nuevo usuario administrador

Si puedes acceder a la base de datos PostgreSQL:

1. Conecta a PostgreSQL:
   ```bash
   docker exec -it postgres psql -U postgres -d keycloak
   ```

2. Busca usuarios existentes:
   ```sql
   SELECT username, email FROM user_entity WHERE realm_id = 'master';
   ```

3. Para resetear contraseña del admin (requiere conocimiento avanzado):
   ```sql
   -- Esto es solo para referencia, mejor usar la UI
   UPDATE credential SET secret_data = '...' WHERE user_id = '...';
   ```

## Verificar Credenciales Actuales

### Desde docker-compose.yml:
```bash
grep -A 1 "KEYCLOAK_ADMIN" docker-compose.yml
```

### Desde variables de entorno (si usas .env):
```bash
cat .env | grep KEYCLOAK
```

### Desde el contenedor:
```bash
docker compose --profile security exec keycloak env | grep KEYCLOAK
```

## Crear Usuarios para Grafana

Una vez que tengas acceso al admin de Keycloak:

1. Accede a http://localhost:8080/admin
2. Ve a: **Users** → **Add user**
3. Completa:
   - **Username**: (ej: grafana-user)
   - **Email**: (opcional)
   - **First Name**: (opcional)
   - **Last Name**: (opcional)
4. Ve a la pestaña **Credentials**
5. Establece una contraseña
6. Desmarca "Temporary"
7. Haz clic en **Set Password**

## Configurar el Cliente Grafana en Keycloak

Para que Grafana funcione con Keycloak:

1. Accede a http://localhost:8080/admin
2. Ve a: **Clients** → **grafana** (o créalo si no existe)
3. Configura:
   - **Client ID**: `grafana`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
   - **Valid Redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - **Web Origins**: `http://localhost:3001`
   - **Client Secret**: Copia este valor y úsalo en `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` en docker-compose.yml

## Mejores Prácticas de Seguridad

1. **Cambia las credenciales por defecto inmediatamente**
2. **Usa contraseñas seguras** (mínimo 12 caracteres, mezcla de mayúsculas, minúsculas, números y símbolos)
3. **No compartas las credenciales** en el código
4. **Usa variables de entorno** para credenciales sensibles
5. **Habilita HTTPS** en producción
6. **Configura 2FA** para usuarios administrativos

## Variables de Entorno Recomendadas

Crea un archivo `.env` con:

```bash
KEYCLOAK_ADMIN=tu_usuario_admin_seguro
KEYCLOAK_ADMIN_PASSWORD=tu_contraseña_muy_segura_min_16_caracteres
```

Y actualiza `docker-compose.yml` para usar:

```yaml
environment:
  - KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN}
  - KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
```

---

**Última actualización**: $(date)

