# 🔍 Guía de Validación de Cambios

Esta guía te ayudará a validar que los cambios recientes (ModSecurity y Prometheus Alerts) funcionan correctamente.

## ✅ Validación Estática (Sin Docker)

Ejecuta el script de validación estática que verifica la configuración:

```bash
./scripts/validate-config.sh
```

Este script verifica:
- ✅ Archivos de ModSecurity creados correctamente
- ✅ Archivos de Prometheus Alerts creados correctamente
- ✅ Referencias en docker-compose.yml
- ✅ Sintaxis YAML válida
- ✅ Sintaxis de docker-compose válida

## 🧪 Validación con Docker

Una vez que Docker esté disponible, puedes validar que los servicios funcionan:

### 1. Levantar los servicios

```bash
# Servicios principales
docker compose up -d

# Con monitoreo (incluye Prometheus con alertas)
docker compose --profile monitoring up -d

# Con seguridad (incluye ModSecurity)
docker compose --profile security up -d

# Todo junto
docker compose --profile monitoring --profile security up -d
```

### 2. Ejecutar pruebas

```bash
./scripts/test-changes.sh
```

Este script verifica:
- ✅ Servicios corriendo correctamente
- ✅ Logs sin errores críticos
- ✅ Archivos de configuración montados
- ✅ Endpoints accesibles

### 3. Verificación manual

#### Prometheus y Alertas

```bash
# Verificar que Prometheus está corriendo
docker compose --profile monitoring ps prometheus

# Verificar logs de Prometheus
docker compose --profile monitoring logs prometheus | tail -20

# Verificar que las alertas están cargadas
curl http://localhost:9090/api/v1/rules

# Acceder a la UI de Prometheus
# Abre en el navegador: http://localhost:9090
# Ve a: Status > Rules para ver las alertas cargadas
```

#### ModSecurity

```bash
# Verificar que ModSecurity está corriendo
docker compose --profile security ps modsecurity

# Verificar logs de ModSecurity
docker compose --profile security logs modsecurity | tail -20

# Verificar que los archivos están montados
docker compose --profile security exec modsecurity ls -la /etc/nginx/modsecurity/

# Verificar configuración
docker compose --profile security exec modsecurity cat /etc/nginx/modsecurity/modsecurity.conf | head -10
```

## 📋 Checklist de Validación

- [ ] Script de validación estática pasa sin errores
- [ ] Docker Compose valida sin errores
- [ ] Prometheus inicia correctamente con el perfil `monitoring`
- [ ] Las alertas se cargan en Prometheus (verificar en UI)
- [ ] ModSecurity inicia correctamente con el perfil `security`
- [ ] Archivos de configuración están montados en ModSecurity
- [ ] No hay errores críticos en los logs

## 🐛 Solución de Problemas

### Prometheus no carga las alertas

1. Verificar que el archivo existe:
   ```bash
   ls -la monitoring/prometheus/alerts.yml
   ```

2. Verificar sintaxis YAML:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('monitoring/prometheus/alerts.yml'))"
   ```

3. Verificar que está montado en docker-compose.yml:
   ```bash
   grep alerts.yml docker-compose.yml
   ```

4. Reiniciar Prometheus:
   ```bash
   docker compose --profile monitoring restart prometheus
   ```

### ModSecurity no inicia

1. Verificar que los archivos existen:
   ```bash
   ls -la modsecurity/modsecurity.conf
   ls -la modsecurity/rules/
   ```

2. Verificar logs:
   ```bash
   docker compose --profile security logs modsecurity
   ```

3. Verificar que está montado en docker-compose.yml:
   ```bash
   grep modsecurity docker-compose.yml
   ```

## 📊 Verificación de Alertas

Para verificar que las alertas funcionan:

1. Accede a Prometheus: http://localhost:9090
2. Ve a: **Alerts** (en el menú superior)
3. Deberías ver las alertas configuradas en `alerts.yml`
4. Las alertas estarán en estado "Inactive" hasta que se cumplan las condiciones

## 🔒 Verificación de ModSecurity

Para verificar que ModSecurity está funcionando:

1. Los logs de ModSecurity mostrarán las reglas cargadas
2. Las reglas están en modo "DetectionOnly" por defecto (no bloquean, solo registran)
3. Los logs se almacenan en el volumen `modsecurity_data`

## ✅ Resultado Esperado

Si todo está correcto, deberías ver:

- ✅ Prometheus corriendo en http://localhost:9090
- ✅ Alertas visibles en la UI de Prometheus
- ✅ ModSecurity corriendo sin errores
- ✅ Archivos de configuración montados correctamente
- ✅ Sin errores críticos en los logs

---

**Nota**: Si encuentras algún problema, revisa los logs con:
```bash
docker compose logs [nombre-servicio]
```

