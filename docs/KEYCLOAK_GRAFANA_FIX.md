# 🔧 Solución: Error de Conexión Keycloak en Grafana

## Problema

Cuando intentas iniciar sesión en Grafana usando Keycloak, aparece el error:
```
ERR_CONNECTION_REFUSED
keycloak refused to connect
```

## Causa

Grafana estaba configurado para usar `http://keycloak:8080` en las URLs de OAuth. El problema es que:

1. **`keycloak` es un hostname interno de Docker** - Solo funciona dentro de la red Docker
2. **El navegador del usuario** intenta resolver `keycloak` como hostname y falla porque no existe en el DNS del sistema
3. **Keycloak debe estar corriendo** con el perfil `security`

## Solución Aplicada

Se actualizó la configuración de Grafana en `docker-compose.yml`:

### URLs que el navegador necesita acceder → `localhost:8080`
- `GF_AUTH_GENERIC_OAUTH_AUTH_URL`: Cambiado a `http://localhost:8080/...`
- `GF_AUTH_SIGNOUT_REDIRECT_URL`: Cambiado a `http://localhost:8080/...`

### URLs que Grafana usa internamente → `keycloak:8080`
- `GF_AUTH_GENERIC_OAUTH_TOKEN_URL`: Mantiene `http://keycloak:8080/...`
- `GF_AUTH_GENERIC_OAUTH_API_URL`: Mantiene `http://keycloak:8080/...`

## Pasos para Aplicar

1. **Levantar Keycloak**:
   ```bash
   docker compose --profile security up -d keycloak
   ```

2. **Reiniciar Grafana** para aplicar cambios:
   ```bash
   docker compose --profile monitoring restart grafana
   ```

3. **Verificar que Keycloak está accesible**:
   ```bash
   curl http://localhost:8080/health
   # O abrir en navegador: http://localhost:8080
   ```

4. **Probar login en Grafana**:
   - Ir a http://localhost:3001
   - Hacer clic en "Sign in with Keycloak"
   - Debería redirigir correctamente a Keycloak

## Verificación

### Verificar que Keycloak está corriendo:
```bash
docker compose --profile security ps keycloak
```

### Verificar logs de Keycloak:
```bash
docker compose --profile security logs keycloak | tail -20
```

### Verificar logs de Grafana:
```bash
docker compose --profile monitoring logs grafana | grep -i oauth
```

## Notas Importantes

1. **Keycloak tarda en iniciar**: Puede tomar 30-60 segundos en estar completamente listo
2. **Primera vez**: La primera vez que Keycloak inicia, crea la base de datos y puede tardar más
3. **Credenciales por defecto**: 
   - Usuario: `admin`
   - Contraseña: `admin` (cambiar en producción)

## Configuración de Cliente OIDC en Keycloak

Si necesitas configurar el cliente `grafana` en Keycloak:

1. Acceder a Keycloak Admin Console: http://localhost:8080
2. Login con admin/admin
3. Ir a: **Clients** → **grafana**
4. Verificar configuración:
   - **Valid Redirect URIs**: `http://localhost:3001/login/generic_oauth`
   - **Web Origins**: `http://localhost:3001`
   - **Client Secret**: Debe coincidir con `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` en docker-compose.yml

## Alternativa: Usar /etc/hosts (Workaround Temporal)

Si prefieres usar el workaround anterior mencionado en `KEYCLOAK_CONTEXT.txt`:

```bash
echo "127.0.0.1 keycloak" | sudo tee -a /etc/hosts
```

Pero la solución con `localhost` es más limpia y no requiere modificar archivos del sistema.

---

**Última actualización**: $(date)

