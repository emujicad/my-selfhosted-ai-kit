# Scripts de Prueba (Tests)

Este directorio contiene scripts de prueba y validación que **NO** ejecutan acciones reales en el sistema.

## 📋 Scripts Disponibles

### test-keycloak-roles-flow.sh
Valida la implementación de Keycloak roles sin crear roles reales.

**Uso**:
```bash
./scripts/tests/test-keycloak-roles-flow.sh
```

**Qué hace**:
- ✅ Verifica existencia de scripts
- ✅ Valida implementación del flag --setup-roles
- ✅ Verifica health check logic
- ✅ Valida recordatorios configurados
- ✅ Simula parsing de argumentos
- ✅ Verifica documentación

**NO hace**:
- ❌ NO crea roles en Keycloak
- ❌ NO modifica base de datos
- ❌ NO ejecuta acciones reales

## 🎯 Propósito

Los scripts en este directorio son para:
- Validar implementaciones antes de producción
- Verificar que el código funciona correctamente
- Detectar problemas sin afectar el sistema real
- Documentar comportamiento esperado

## 📚 Diferencia con Scripts de Acción

| Aspecto | Scripts de Acción | Scripts de Prueba |
|---------|-------------------|-------------------|
| **Ubicación** | `scripts/` | `scripts/tests/` |
| **Propósito** | Ejecutar acciones reales | Validar sin ejecutar |
| **Efecto** | Modifica sistema | Solo verifica |
| **Ejemplo** | `keycloak-roles-manager.sh` | `test-keycloak-roles-flow.sh` |

## ⚠️ Importante

Los scripts de prueba son **seguros de ejecutar** en cualquier momento porque no modifican nada.
