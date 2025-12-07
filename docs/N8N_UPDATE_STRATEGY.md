# 🔄 Estrategia de Actualización de n8n

## 📊 Situación Actual

- **Versión actual**: 1.101.2
- **Versión más reciente**: 1.122.5
- **Versiones atrás**: 21
- **Tiempo sin actualizar**: 4 meses

## ⚠️ Riesgos de Actualizar

1. **Migraciones de base de datos**: n8n puede requerir migraciones de BD entre versiones
2. **Cambios breaking**: Algunas versiones pueden tener cambios incompatibles
3. **Workflows rotos**: Los workflows pueden dejar de funcionar si usan funcionalidades deprecadas
4. **Nodos desactualizados**: Algunos nodos personalizados pueden no ser compatibles

## ✅ Recomendación: Actualización Controlada

### Opción 1: Actualización Gradual (RECOMENDADO)

**Ventajas**:
- Menor riesgo de romper workflows
- Puedes probar cada versión antes de continuar
- Fácil rollback si algo falla

**Pasos**:

1. **Hacer backup completo ANTES de actualizar**:
   ```bash
   ./scripts/backup.sh --full --verify
   ```

2. **Actualizar a versión intermedia primero** (ej: 1.110):
   ```yaml
   image: docker.n8n.io/n8nio/n8n:1.110.1
   ```

3. **Reiniciar y verificar**:
   ```bash
   docker compose up -d --force-recreate n8n
   # Esperar a que inicie
   # Verificar que los workflows funcionan
   ```

4. **Si todo está bien, continuar a versión más reciente**:
   ```yaml
   image: docker.n8n.io/n8nio/n8n:1.122.5
   ```

### Opción 2: Actualización Directa a Latest

**Solo si**:
- Tienes backup reciente
- No tienes workflows críticos en producción
- Puedes permitirte downtime

**Pasos**:

1. **Backup completo**:
   ```bash
   ./scripts/backup.sh --full --verify
   ```

2. **Actualizar docker-compose.yml**:
   ```yaml
   image: docker.n8n.io/n8nio/n8n:latest
   ```

3. **Reiniciar**:
   ```bash
   docker compose up -d --force-recreate n8n
   ```

4. **Verificar migraciones automáticas**:
   n8n ejecuta migraciones automáticamente al iniciar

### Opción 3: Fijar Versión Específica (MÁS SEGURO)

**Para producción**, fija una versión estable:

```yaml
image: docker.n8n.io/n8nio/n8n:1.122.5
```

**Ventajas**:
- Control total sobre cuándo actualizar
- Evita actualizaciones automáticas inesperadas
- Puedes probar en desarrollo primero

## 🔧 Configuración Recomendada

### 1. Fijar Versión en docker-compose.yml

```yaml
x-n8n: &service-n8n
  image: docker.n8n.io/n8nio/n8n:1.122.5  # Versión específica
  # En lugar de: docker.n8n.io/n8nio/n8n (latest)
```

### 2. Deshabilitar Watchtower para n8n (si está activo)

Si tienes Watchtower activo, excluye n8n de actualizaciones automáticas:

```yaml
watchtower:
  environment:
    - WATCHTOWER_LABEL_ENABLE=false
    # O etiqueta n8n para excluirlo
```

O etiqueta n8n:
```yaml
n8n:
  labels:
    - "com.centurylinklabs.watchtower.enable=false"
```

## 📋 Checklist Antes de Actualizar

- [ ] Backup completo realizado (`./scripts/backup.sh --full --verify`)
- [ ] Verificar que PostgreSQL está corriendo y accesible
- [ ] Documentar workflows críticos (por si acaso)
- [ ] Tener plan de rollback (restaurar backup si falla)
- [ ] Probar en horario de bajo uso si es posible

## 🚨 Qué Hacer Si Algo Sale Mal

1. **Detener n8n**:
   ```bash
   docker compose stop n8n
   ```

2. **Restaurar backup**:
   ```bash
   ./scripts/restore.sh <timestamp-del-backup>
   ```

3. **Reiniciar servicios**:
   ```bash
   docker compose restart
   ```

## 💡 Recomendación Final

**Para tu caso (21 versiones atrás)**:

1. ✅ **Hacer backup completo AHORA**
2. ✅ **Actualizar gradualmente**: Primero a 1.110, luego a 1.122
3. ✅ **Fijar versión específica** en docker-compose.yml (no usar `latest`)
4. ✅ **Probar workflows críticos** después de cada actualización
5. ✅ **Actualizar manualmente** cada mes o dos (no automático)

**NO recomiendo**:
- ❌ Actualización automática con Watchtower para n8n
- ❌ Saltar directamente de 1.101 a 1.122 sin probar
- ❌ Actualizar sin backup

---

**Última actualización**: 2025-12-07

