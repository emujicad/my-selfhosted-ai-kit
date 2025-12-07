# 🤖 Guía de Automatización

Esta guía documenta todos los scripts automatizados disponibles en el proyecto.

## 📋 Scripts Disponibles

### 1. Validación Automática Completa

**Script**: `scripts/auto-validate.sh`

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

### 2. Validación Estática de Configuración

**Script**: `scripts/validate-config.sh`

**Descripción**: Valida la configuración sin necesidad de Docker corriendo.

**Uso**:
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

---

### 3. Prueba de Cambios Recientes

**Script**: `scripts/test-changes.sh`

**Descripción**: Prueba específicamente los cambios recientes (ModSecurity y Prometheus Alerts).

**Uso**:
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

## 🚀 Flujo de Trabajo Recomendado

### Desarrollo Local

1. **Después de hacer cambios**:
   ```bash
   # Validación rápida sin Docker
   ./scripts/validate-config.sh
   ```

2. **Antes de commit**:
   ```bash
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

## 🔧 Personalización

### Variables de Entorno

Los scripts detectan automáticamente:
- `DOCKER_CMD`: Comando de Docker a usar (`docker` o `sudo docker`)
- `PROJECT_DIR`: Directorio del proyecto

### Timeouts

Los scripts incluyen timeouts automáticos para evitar esperas infinitas:
- Espera entre servicios: 5-10 segundos
- Timeout de endpoints: 3 segundos

### Logs

Los logs se guardan temporalmente en:
- `/tmp/validation.log`: Logs de validación estática
- `/tmp/docker-start.log`: Logs de inicio de Docker

---

## 🐛 Solución de Problemas

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

---

## 📝 Mejores Prácticas

1. **Ejecuta validación estática primero**: Es rápida y no requiere Docker
2. **Usa auto-validate.sh para validación completa**: Automatiza todo el proceso
3. **Revisa logs si hay problemas**: Los scripts muestran dónde buscar
4. **Ejecuta antes de commit**: Evita problemas en producción

---

## 🔄 Integración Continua

### GitHub Actions

```yaml
name: Validate Configuration

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Validate config
        run: ./scripts/validate-config.sh
```

### GitLab CI

```yaml
validate:
  script:
    - ./scripts/validate-config.sh
  only:
    - merge_requests
```

---

## 📚 Referencias

- [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) - Guía detallada de validación
- [README.md](README.md) - Documentación principal del proyecto
- [TODO.md](TODO.md) - Lista de tareas pendientes

---

**Última actualización**: $(date)

