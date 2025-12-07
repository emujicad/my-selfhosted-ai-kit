# ⚡ Inicio Rápido - Validación

Guía rápida para validar que todo funciona correctamente.

## 🚀 Validación Automática (Recomendado)

Ejecuta un solo comando que hace todo:

```bash
./scripts/auto-validate.sh
```

Este script:
1. ✅ Valida la configuración estáticamente
2. 🐳 Levanta los servicios necesarios
3. 🔍 Verifica que todo funciona

## 📋 Validación Paso a Paso

### Paso 1: Validación Estática (Sin Docker)

```bash
./scripts/validate-config.sh
```

Verifica que todos los archivos estén en su lugar y la configuración sea válida.

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

### Paso 3: Verificar Servicios

```bash
./scripts/test-changes.sh
```

O manualmente:

```bash
# Verificar Prometheus
curl http://localhost:9090/-/healthy

# Verificar ModSecurity
docker compose --profile security ps modsecurity

# Ver logs
docker compose --profile monitoring logs prometheus
docker compose --profile security logs modsecurity
```

## ✅ Resultado Esperado

Si todo está bien, deberías ver:

- ✅ Validación estática: Sin errores
- ✅ Prometheus: Corriendo en http://localhost:9090
- ✅ ModSecurity: Corriendo sin errores
- ✅ Alertas: Cargadas en Prometheus
- ✅ Configuración: Archivos montados correctamente

## 🐛 Problemas Comunes

### "Docker no disponible"
```bash
sudo systemctl start docker
# O
sudo service docker start
```

### "Permission denied"
```bash
chmod +x scripts/*.sh
```

### Servicios no inician
```bash
# Ver logs
docker compose logs [nombre-servicio]

# Verificar configuración
docker compose config
```

## 📚 Más Información

- [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) - Guía detallada
- [AUTOMATION.md](AUTOMATION.md) - Documentación de scripts
- [README.md](README.md) - Documentación principal

---

**💡 Tip**: Ejecuta `./scripts/auto-validate.sh` después de cada cambio importante.

