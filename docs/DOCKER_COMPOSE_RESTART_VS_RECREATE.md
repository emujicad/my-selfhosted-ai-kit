# 🔄 Docker Compose: Restart vs Recreate

## 📚 Diferencia Entre Comandos

### 1. `docker compose restart <servicio>`

**Qué hace:**
- Solo reinicia el contenedor existente
- NO recarga variables de entorno del `docker-compose.yml`
- NO aplica cambios en la imagen
- NO aplica cambios en volúmenes, puertos, configuración

**Cuándo usar:**
- El servicio falló y solo necesitas reiniciarlo
- No has cambiado nada en `docker-compose.yml`
- Necesitas un reinicio rápido sin aplicar cambios

**Ejemplo:**
```bash
docker compose restart grafana
```

### 2. `docker compose up -d --force-recreate <servicio>`

**Qué hace:**
- Destruye y recrea el contenedor completamente
- SÍ recarga variables de entorno del `docker-compose.yml`
- SÍ aplica cambios en la imagen (si se actualizó)
- SÍ aplica cambios en volúmenes, puertos, configuración

**Cuándo usar:**
- Cambiaste variables de entorno en `docker-compose.yml`
- Actualizaste la imagen (`docker pull`)
- Cambiaste volúmenes, puertos, o configuración
- Necesitas forzar la recreación aunque Docker no detecte cambios

**Ejemplo:**
```bash
docker compose up -d --force-recreate grafana
```

### 3. `docker compose up -d <servicio>`

**Qué hace:**
- Solo recrea si Docker detecta cambios automáticamente
- Más eficiente que `--force-recreate`
- Aplica cambios cuando los detecta

**Cuándo usar:**
- Docker puede detectar los cambios automáticamente
- Es más seguro y eficiente que `--force-recreate`
- Preferido cuando no necesitas forzar la recreación

**Ejemplo:**
```bash
docker compose up -d grafana
```

## 💡 Ejemplos Prácticos

### Caso 1: Cambiaste una Variable de Entorno

**docker-compose.yml:**
```yaml
environment:
  - NEW_VAR=value
```

- ❌ `docker compose restart` → NO aplica el cambio
- ✅ `docker compose up -d --force-recreate` → SÍ aplica el cambio

### Caso 2: Actualizaste la Imagen

```bash
docker pull quay.io/keycloak/keycloak:latest
```

- ❌ `docker compose restart` → Sigue usando la imagen antigua
- ✅ `docker compose up -d --force-recreate` → Usa la nueva imagen

### Caso 3: Solo Necesitas Reiniciar por un Error

- ✅ `docker compose restart` → Es suficiente y más rápido

## 🔍 ¿Por Qué Usar `--force-recreate`?

### Razón Principal: Variables de Entorno

Cuando cambias variables de entorno en `docker-compose.yml`, necesitas recrear el contenedor para que se carguen las nuevas variables. Un simple `restart` solo reinicia el proceso dentro del contenedor, pero no recarga la configuración del `docker-compose.yml`.

**Ejemplo:**
```yaml
# Antes
environment:
  - DEBUG=false

# Después (cambiaste a true)
environment:
  - DEBUG=true
```

Con `restart`: El contenedor sigue usando `DEBUG=false`  
Con `--force-recreate`: El contenedor usa `DEBUG=true`

### Otras Razones

1. **Imágenes actualizadas**: Cuando actualizas una imagen (`docker pull`), necesitas recrear para usar la nueva versión.

2. **Cambios en configuración**: Cualquier cambio en `docker-compose.yml` (volúmenes, puertos, comandos, etc.) requiere recrear el contenedor.

3. **Forzar actualización**: A veces Docker no detecta cambios automáticamente, `--force-recreate` fuerza la recreación.

## 📋 Resumen

| Comando | Recarga Variables | Aplica Cambios Imagen | Aplica Cambios Config | Velocidad |
|---------|-------------------|----------------------|----------------------|-----------|
| `restart` | ❌ | ❌ | ❌ | ⚡ Rápido |
| `up -d` | ✅ | ✅ | ✅ | 🚀 Medio |
| `up -d --force-recreate` | ✅ | ✅ | ✅ | 🐢 Lento |

## ✅ Recomendación

- **Usa `restart`** cuando solo necesitas reiniciar sin cambios
- **Usa `up -d`** cuando Docker puede detectar cambios automáticamente
- **Usa `up -d --force-recreate`** cuando necesitas forzar la aplicación de cambios

---

**Última actualización**: 2025-12-07

