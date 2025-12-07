# 🔍 Guía Completa de Validación

## 📋 Índice

1. [Validación Rápida](#validación-rápida) ⚡
2. [Validación Automática](#validación-automática) 🤖
3. [Validación Paso a Paso](#validación-paso-a-paso) 📝
4. [Scripts Disponibles](#scripts-disponibles) 🛠️
5. [Troubleshooting](#troubleshooting) 🐛
6. [Interpretación de Resultados](#interpretación-de-resultados) 📊

---

## ⚡ Validación Rápida

### Opción 1: Validación Automática Completa (Recomendado)

Ejecuta un solo comando que hace todo:

```bash
./scripts/auto-validate.sh
```

Este script:
1. ✅ Valida la configuración estáticamente (sin Docker)
2. 🐳 Levanta los servicios necesarios automáticamente
3. 🔍 Verifica que todo funciona correctamente
4. 📊 Genera reporte completo

### Opción 2: Validación Estática Rápida (Sin Docker)

Si solo quieres validar la configuración sin levantar servicios:

```bash
./scripts/validate-config.sh
```

Verifica:
- ✅ Archivos de configuración creados correctamente
- ✅ Sintaxis YAML válida
- ✅ Sintaxis de docker-compose válida
- ✅ Referencias correctas en docker-compose.yml

---

## 🤖 Validación Automática

### Script: `scripts/auto-validate.sh`

**Descripción**: Ejecuta automáticamente todas las validaciones y pruebas en secuencia.

**Uso**:
```bash
./scripts/auto-validate.sh
```

**Qué hace**:
1. ✅ Validación estática de configuración (sin Docker)
2. 🐳 Levantamiento automático de servicios Docker
3. 🔍 Verificación de servicios corriendo
4. 📊 Genera reporte completo

**Ejemplo de salida**:
```
🚀 VALIDACIÓN AUTOMÁTICA COMPLETA
════════════════════════════════════════════════════════

PASO 1: VALIDACIÓN ESTÁTICA
✅ Validación estática completada

PASO 2: LEVANTAR SERVICIOS
✅ Servicios principales levantados
✅ Servicios de monitoreo levantados
✅ Servicios de seguridad levantados

PASO 3: VERIFICAR SERVICIOS
✅ Prometheus está corriendo
✅ ModSecurity está corriendo
```

---

## 📝 Validación Paso a Paso

### Paso 1: Validación Estática (Sin Docker)

```bash
./scripts/validate-config.sh
```

**Qué verifica**:
- ✅ Archivos de ModSecurity creados
- ✅ Archivos de Prometheus Alerts creados
- ✅ Referencias en docker-compose.yml
- ✅ Sintaxis YAML válida
- ✅ Sintaxis de docker-compose válida (si Docker está disponible)

**Ventajas**:
- No requiere Docker corriendo
- Rápido de ejecutar
- Útil para CI/CD

### Paso 2: Levantar Servicios

```bash
# Servicios principales
docker compose up -d

# Con monitoreo (Prometheus + Alertas)
docker compose --profile monitoring up -d

# Con seguridad (ModSecurity)
docker compose --profile security up -d

# Todo junto
docker compose --profile monitoring --profile security up -d
```

### Paso 3: Pruebas Específicas

```bash
./scripts/test-changes.sh
```

**Qué verifica**:
- ✅ Servicios corriendo correctamente
- ✅ Logs sin errores críticos
- ✅ Archivos de configuración montados
- ✅ Endpoints accesibles

**Requisitos**:
- Docker debe estar corriendo
- Servicios deben estar levantados

---

## 🛠️ Scripts Disponibles

### 1. `scripts/verify-env-variables.sh` - Verificación de Variables de Entorno

**Descripción**: Verifica que todas las variables críticas de `.env` estén configuradas correctamente y detecta variables vacías que podrían causar problemas.

**Uso**:
```bash
./scripts/verify-env-variables.sh
```

**Qué verifica**:
- ✅ Variables críticas no están vacías
- ✅ Variables que construyen URLs tienen valores o pueden construirse
- ✅ Detecta variables definidas pero vacías en `.env` (problema común)
- ✅ Valores placeholder que deben cambiarse

**Ejemplo de salida**:
```
🔍 VERIFICANDO VARIABLES DE ENTORNO CRÍTICAS
=============================================

❌ ERROR: OLLAMA_URL_INTERNAL está definida pero VACÍA en .env
   Solución: Darle un valor o eliminar/comentar la línea

RESUMEN:
Errores encontrados: 1
Advertencias: 0
```

**Cuándo ejecutarlo**:
- Antes de levantar servicios por primera vez
- Después de modificar `.env`
- Cuando un servicio no se conecta correctamente
- En CI/CD pipelines

### 2. `scripts/auto-validate.sh` - Validación Automática Completa

Ejecuta todas las validaciones en secuencia.

**Uso**:
```bash
./scripts/auto-validate.sh
```

### 3. `scripts/validate-config.sh` - Validación Estática

Valida la configuración sin necesidad de Docker corriendo.

**Uso**:
```bash
./scripts/validate-config.sh
```

### 4. `scripts/test-changes.sh` - Prueba de Cambios Recientes

Prueba específicamente los cambios recientes (ModSecurity y Prometheus Alerts).

**Uso**:
```bash
./scripts/test-changes.sh
```

---

## 🚀 Flujo de Trabajo Recomendado

### Antes de Levantar Servicios (CRÍTICO)

**Paso 0: Verificar Variables de Entorno**
```bash
./scripts/verify-env-variables.sh
```

Este paso es **crítico** porque detecta variables vacías que podrían causar problemas de conexión. Ejecútalo siempre antes de levantar servicios.

### Desarrollo Local

1. **Antes de hacer cambios**:
   ```bash
   # Verificar variables de entorno (CRÍTICO)
   ./scripts/verify-env-variables.sh
   # Validación rápida sin Docker
   ./scripts/validate-config.sh
   ```

2. **Antes de commit**:
   ```bash
   # Verificar variables de entorno (CRÍTICO)
   ./scripts/verify-env-variables.sh
   # Validación completa
   ./scripts/auto-validate.sh
   ```

3. **Después de levantar servicios**:
   ```bash
   # Pruebas específicas
   ./scripts/test-changes.sh
   ```

### CI/CD Pipeline

```yaml
# Ejemplo para GitHub Actions
- name: Validar configuración
  run: ./scripts/validate-config.sh

- name: Validar sintaxis Docker Compose
  run: docker compose config

- name: Levantar servicios y probar
  run: |
    docker compose --profile monitoring --profile security up -d
    sleep 30
    ./scripts/test-changes.sh
```

---

## 📋 Checklist de Validación

- [ ] **Variables de entorno verificadas** (`./scripts/verify-env-variables.sh`) - **CRÍTICO**
- [ ] **No hay variables vacías** que puedan causar problemas de conexión
- [ ] Script de validación estática pasa sin errores
- [ ] Docker Compose valida sin errores
- [ ] Prometheus inicia correctamente con el perfil `monitoring`
- [ ] Las alertas se cargan en Prometheus (verificar en UI)
- [ ] ModSecurity inicia correctamente con el perfil `security`
- [ ] Archivos de configuración están montados en ModSecurity
- [ ] No hay errores críticos en los logs

---

## 🐛 Troubleshooting

### Script falla con "Docker no disponible"

**Solución**: Asegúrate de que Docker esté corriendo:
```bash
sudo systemctl start docker
# O
sudo service docker start
```

### Script falla con "Permission denied"

**Solución**: Haz los scripts ejecutables:
```bash
chmod +x scripts/*.sh
```

### Validación estática falla

**Solución**: Revisa los errores específicos:
```bash
./scripts/validate-config.sh 2>&1 | grep "❌"
```

### Servicios no inician

**Solución**: Revisa los logs:
```bash
docker compose logs [nombre-servicio]
```

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

### Variables de entorno vacías causan problemas de conexión

**Problema**: Cuando una variable está definida pero vacía en `.env`, Docker Compose la pasa como cadena vacía, y `${VAR:-default}` no funciona.

**Ejemplo**:
- En `.env`: `OLLAMA_URL_INTERNAL=`
- En `docker-compose.yml`: `OLLAMA_BASE_URL=${OLLAMA_URL_INTERNAL:-http://ollama:11434}`
- Resultado: `OLLAMA_BASE_URL=http://:` (vacío, no funciona)

**Solución**:
1. Verificar variables críticas con el script de verificación:
   ```bash
   ./scripts/verify-env-variables.sh
   ```

2. Asegurar que las variables en `.env` tengan valores correctos:
   ```bash
   # ❌ MAL: Variable vacía
   OLLAMA_URL_INTERNAL=
   
   # ✅ BIEN: Variable con valor
   OLLAMA_URL_INTERNAL=http://ollama:11434
   
   # ✅ BIEN: No definir la variable si quieres usar el valor por defecto
   # (simplemente no incluir la línea)
   ```

3. Variables críticas que NO deben estar vacías:
   - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
   - `OLLAMA_HOST_INTERNAL`, `OLLAMA_PORT_INTERNAL`
   - `KEYCLOAK_ADMIN_USER`, `KEYCLOAK_ADMIN_PASSWORD`
   - `N8N_ENCRYPTION_KEY`, `N8N_USER_MANAGEMENT_JWT_SECRET`
   - Y otras variables críticas de configuración

---

## 📊 Interpretación de Resultados

### ✅ Éxito
- Todos los checks pasan
- Servicios corriendo correctamente
- Sin errores en logs

### ⚠️ Advertencias
- Docker no disponible (normal si no está corriendo)
- Servicios no levantados (normal si no se ejecutó con perfiles)
- No son errores críticos

### ❌ Errores
- Archivos faltantes
- Sintaxis inválida
- Servicios fallando
- Requieren atención inmediata

---

## 🔍 Verificación de Servicios Específicos

### Prometheus y Alertas

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

### ModSecurity

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

### Grafana

```bash
# Verificar que Grafana está corriendo
docker compose --profile monitoring ps grafana

# Acceder a Grafana
# Abre en el navegador: http://localhost:3001
# Usuario: admin / Contraseña: admin (o según configuración)
```

---

## ✅ Resultado Esperado

Si todo está correcto, deberías ver:

- ✅ Prometheus corriendo en http://localhost:9090
- ✅ Alertas visibles en la UI de Prometheus
- ✅ ModSecurity corriendo sin errores
- ✅ Archivos de configuración montados correctamente
- ✅ Sin errores críticos en los logs

---

## 📚 Referencias

- [README.md](../README.md) - Documentación principal del proyecto
- [TODO.md](../TODO.md) - Lista de tareas pendientes
- [docs/INDEX.md](INDEX.md) - Guía de lectura de documentación

---

**Última actualización**: 2025-12-07

