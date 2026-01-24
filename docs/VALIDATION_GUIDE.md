# 🔍 Guía Completa de Validación

## 📋 Índice

1. [Validación Rápida](#validación-rápida) ⚡
2. [Validación del Sistema (Unified)](#validación-del-sistema-unified) 🛠️
3. [Flujos de Trabajo](#flujos-de-trabajo) 🚀
4. [Troubleshooting](#troubleshooting) 🐛
5. [Interpretación de Resultados](#interpretación-de-resultados) 📊

---

## ⚡ Validación Rápida

### Opción 1: Validación Automática Completa (Recomendado)

Ejecuta un solo comando que hace todo: validación estática y despliegue de prueba.

```bash
./scripts/stack-manager.sh auto-validate
# O directamente:
./scripts/validate-system.sh --all --deploy-check
```

### Opción 2: Solo Configuración (Sin Docker)

Si solo quieres validar variables y archivos de configuración sin tocar Docker:

```bash
./scripts/stack-manager.sh validate
# O directamente:
./scripts/validate-system.sh --config
```

---

## 🛠️ Validación del Sistema (Unified)

Hemos unificado todas las herramientas de validación en un solo script maestro: **`scripts/validate-system.sh`**.

### Uso General

```bash
./scripts/validate-system.sh [FLAGS]
```

### Flags Disponibles

| Flag | Descripción | Reemplaza a |
|------|-------------|-------------|
| `--env` | Verifica variables de entorno en `.env`. Critico antes de iniciar. | `verify-env-variables.sh` |
| `--config` | Valida existencia de archivos y sintaxis YAML. No requiere Docker. | `validate-config.sh` |
| `--models` | Verifica estado de Ollama y lista modelos disponibles. | `verifica_modelos.sh` |
| `--deploy-check` | **Activo**: Levanta servicios, espera y prueba endpoints en vivo. | `auto-validate.sh` |
| `--all` | Ejecuta `--env`, `--config` y `--models` (Validación pasiva completa). | N/A |

### Ejemplos

1. **Verificar solo variables de entorno (al cambiar .env):**
   ```bash
   ./scripts/validate-system.sh --env
   ```

2. **Verificar configuración estática:**
   ```bash
   ./scripts/validate-system.sh --config
   ```

3. **Verificar estado de modelos IA:**
   ```bash
   ./scripts/validate-system.sh --models
   ```

4. **Ciclo completo de despliegue y prueba:**
   ```bash
   ./scripts/validate-system.sh --all --deploy-check
   ```

---

## 🚀 Flujos de Trabajo Recomendado

### Desarrollo Local

1. **Antes de hacer cambios**:
   ```bash
   ./scripts/validate-system.sh --env
   ```

2. **Al editar configuraciones**:
   ```bash
   ./scripts/validate-system.sh --config
   ```

3. **Antes de commit (Safety Check)**:
   ```bash
   ./scripts/tests/run-all-tests.sh
   ```

### CI/CD Pipeline

El sistema unificado facilita la integración continua:

```yaml
# Ejemplo para GitHub Actions
steps:
  - name: Validate Environment & Config
    run: ./scripts/validate-system.sh --env --config

  - name: Full Deployment Check
    run: ./scripts/validate-system.sh --deploy-check
```

---

## 🐛 Troubleshooting

### `Docker not found`
Asegúrate de que Docker esté corriendo si usas flags como `--models` o `--deploy-check`. Los flags `--env` y `--config` funcionan sin Docker.

### Fallo en `--deploy-check`
Si el despliegue falla, revisa los logs de los servicios específicos:
```bash
./scripts/stack-manager.sh logs prometheus
./scripts/stack-manager.sh logs modsecurity
```

### Fallo en `--models` con "Container not running"
Asegúrate de que el servicio `ollama` esté en estado `Up`. El validador ignorará el chequeo (con Warning) si el contenedor está detenido, para no romper pipelines.

---

## 📊 Interpretación de Resultados

- **✅ PASSED**: Todo correcto.
- **⚠️ PASSED WITH WARNINGS**: El sistema funciona, pero hay detalles no críticos (ej. Ollama apagado en un check opcional, o variables con valores por defecto).
- **❌ FAILED**: Error crítico. Configuración inválida o servicio esencial caído.
