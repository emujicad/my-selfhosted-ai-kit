# 🧪 AI Kit Test Suite

Este directorio contiene la batería de pruebas automatizadas para garantizar la estabilidad del sistema.

## 🚀 Guía Rápida para el Usuario

### ¿Qué debo ejecutar?

| Situación | Comando Recomendado | Descripción |
|-----------|---------------------|-------------|
| **Quiero verificar TODO** | `./run-all-tests.sh` | Ejecuta **todas** las pruebas. Úsalo antes de hacer commit o si tienes dudas generales. |
| **Acabo de levantar el stack** | `./test-integration.sh` | Verifica que los servicios (Prometheus, Redis, Ollama) estén vivos, respondiendo y conectados. |
| **Toqué algo de Keycloak** | `./test-auth-manager.sh` | Verifica scripts de usuarios, roles y clientes. |
| **Toqué scripts bash** | `./test-stack-manager.sh` | Verifica la lógica del orquestador principal. |

---

## 📂 Catálogo de Tests

### 1. `run-all-tests.sh` (El Orquestador)
Este es el **punto de entrada principal**.
- Escanea este directorio.
- Ejecuta todo lo que empiece por `test-*.sh`.
- Genera un reporte final con ✅ PASS / ❌ FAIL.

### 2. Tests de Componentes (Unitarios/Funcionales)

#### `test-integration.sh` (Antes *test-changes*)
**Tipo:** Integración (Servicios Vivos)
- Verifica que los contenedores Docker estén realmente funcionando.
- Comprueba puertos abiertos (9090, 8080).
- Comprueba que ModSecurity esté bloqueando/permitiendo según reglas.
- Comprueba conexión Redis <-> OpenWebUI.

#### `test-auth-manager.sh`
**Tipo:** Funcional
- Verifica que la herramienta `auth-manager.sh` acepte los flags correctos.
- No necesariamente requiere Docker levantado para validar la sintaxis, pero sí para validar la conexión.

#### `test-stack-manager.sh`
**Tipo:** Funcional
- Prueba crítica del script maestro.
- Valida que `start`, `stop`, `restart` y los perfiles funcionen lógicamente.

#### `test-validate-system.sh`
**Tipo:** Estático
- Verifica que el archivo `.env` tenga las variables necesarias.
- Verifica sintaxis de archivos YAML.

#### `test-backup-manager.sh`
**Tipo:** Funcional
- Simula un backup y restauración para asegurar que no hay errores de sintaxis o rutas.

---

## 🛠️ Cómo agregar un nuevo test
1. Crea un archivo `test-nombre-del-componente.sh`.
2. Dale permisos: `chmod +x test-nombre-del-componente.sh`.
3. ¡Listo! `run-all-tests.sh` lo detectará automáticamente.
