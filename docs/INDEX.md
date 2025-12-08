# 📚 Índice de Documentación

## 🎯 Guía de Lectura Recomendada

### Para Empezar (Lee en este orden)

1. **[README.md](../README.md)** - Visión general del proyecto, instalación y uso básico
2. **[ESTADO_PROYECTO.md](../ESTADO_PROYECTO.md)** - Estado actual del proyecto y tareas completadas
3. **[TODO.md](../TODO.md)** - Tareas pendientes y próximos pasos
4. **[PROXIMOS_PASOS.md](../PROXIMOS_PASOS.md)** - ⭐ **NUEVO** - Plan de acción detallado con próximos pasos recomendados

### Configuración y Setup

#### Docker y Compose
- **[DOCKER_COMPOSE_RESTART_VS_RECREATE.md](DOCKER_COMPOSE_RESTART_VS_RECREATE.md)** - Cuándo usar restart vs recreate
- **[VARIABLES_ENTORNO_DINAMICAS.md](VARIABLES_ENTORNO_DINAMICAS.md)** - Variables de entorno y archivos de configuración

#### Autenticación y Seguridad
- **[KEYCLOAK_INTEGRATION_PLAN.md](KEYCLOAK_INTEGRATION_PLAN.md)** - ⭐ **GUÍA PRINCIPAL** - Integración completa de Keycloak con todos los servicios
- **[KEYCLOAK_DB_TROUBLESHOOTING.md](KEYCLOAK_DB_TROUBLESHOOTING.md)** - Solución de problemas de base de datos de Keycloak (transacciones pendientes)
- **[KEYCLOAK_AUTO_FIX.md](KEYCLOAK_AUTO_FIX.md)** - Corrección automática integrada en stack-manager (transparente para el usuario)
  - Conceptos clave (URLs, flujos OAuth)
- **[ENV_AUTO_FIX.md](ENV_AUTO_FIX.md)** - Corrección automática de variables .env (transparente para el usuario)
- **[AUTO_FIXES_SUMMARY.md](AUTO_FIXES_SUMMARY.md)** - ⭐ **NUEVO** - Resumen de todas las correcciones automáticas
  - Credenciales y acceso
  - Grafana + Keycloak ✅ (configuración completa y troubleshooting)
  - Open WebUI + Keycloak ⚠️ (limitación conocida documentada)
  - n8n + Keycloak ⏳ (configuración lista)
  - Jenkins + Keycloak ⏳ (pendiente)
  - Troubleshooting general

#### Backup y Recuperación
- **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)** - Guía completa de backups y restauración

#### Monitoreo y Dashboards
- **[GRAFANA_MONITORING_GUIDE.md](GRAFANA_MONITORING_GUIDE.md)** - ⭐ **GUÍA COMPLETA** - Monitoreo con Grafana, dashboards y troubleshooting
  - Servicios de monitoreo (Prometheus, Grafana, exporters)
  - Dashboards disponibles
  - Configuración y uso
  - Troubleshooting completo
  - Métricas disponibles

#### Gestión del Stack
- **[STACK_MANAGER_GUIDE.md](STACK_MANAGER_GUIDE.md)** - ⭐ **NUEVO** - Script maestro para gestionar perfiles Docker Compose
  - Gestión simplificada de perfiles
  - Presets predefinidos (default, dev, production, full)
  - Validación automática integrada
  - Comandos disponibles (start, stop, restart, status, info, logs, validate, monitor)

#### Validación y Testing
- **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - ⭐ **GUÍA COMPLETA** - Validación automática, scripts y troubleshooting
  - Validación rápida
  - Validación automática completa
  - Scripts disponibles
  - Troubleshooting

### Actualizaciones
- **[N8N_UPDATE_STRATEGY.md](N8N_UPDATE_STRATEGY.md)** - Estrategia de actualización de n8n

### Diagramas
- **[DIAGRAMS_INSTRUCTIONS.md](../DIAGRAMS_INSTRUCTIONS.md)** - Cómo generar diagramas PNG desde archivos .mmd
- **[DIAGRAMS_INSTRUCTIONS.es.md](../DIAGRAMS_INSTRUCTIONS.es.md)** - Instrucciones en español

---

## 📁 Estructura de Archivos

### Documentación Principal (Raíz)
- **README.md** - Documentación principal del proyecto (inglés)
- **README.es.md** - Documentación principal del proyecto (español)
- **TODO.md** - Lista de tareas pendientes
- **ESTADO_PROYECTO.md** - Estado actual del proyecto
- **DIAGRAMS_INSTRUCTIONS.md** - Instrucciones para diagramas (inglés)
- **DIAGRAMS_INSTRUCTIONS.es.md** - Instrucciones para diagramas (español)

### Documentación Detallada (`docs/`)
- **INDEX.md** - ⭐ Este archivo - Guía de lectura
- **KEYCLOAK_INTEGRATION_PLAN.md** - ⭐ Integración Keycloak (todo consolidado aquí)
- **VALIDATION_GUIDE.md** - ⭐ Validación completa (scripts y troubleshooting)
- **BACKUP_GUIDE.md** - Backups y restauración
- **VARIABLES_ENTORNO_DINAMICAS.md** - Variables de entorno
- **DOCKER_COMPOSE_RESTART_VS_RECREATE.md** - Comandos Docker Compose
- **N8N_UPDATE_STRATEGY.md** - Estrategia de actualización de n8n

---

## 🔍 Búsqueda Rápida por Tema

### Keycloak y Autenticación
- Ver **[KEYCLOAK_INTEGRATION_PLAN.md](KEYCLOAK_INTEGRATION_PLAN.md)** - Todo consolidado aquí
  - Configuración de Grafana
  - Configuración de Open WebUI
  - Configuración de n8n
  - Troubleshooting completo
  - Credenciales y acceso

### Validación y Testing
- Ver **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - Todo consolidado aquí

### Docker Compose
- **[DOCKER_COMPOSE_RESTART_VS_RECREATE.md](DOCKER_COMPOSE_RESTART_VS_RECREATE.md)**
- **[VARIABLES_ENTORNO_DINAMICAS.md](VARIABLES_ENTORNO_DINAMICAS.md)**

### Backups
- **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)**

### Diagramas
- **[DIAGRAMS_INSTRUCTIONS.md](../DIAGRAMS_INSTRUCTIONS.md)**
- **[DIAGRAMS_INSTRUCTIONS.es.md](../DIAGRAMS_INSTRUCTIONS.es.md)**

---

## 📋 Flujo de Lectura Recomendado

### Si eres nuevo en el proyecto:
1. Lee **[README.md](../README.md)** para entender qué es el proyecto
2. Lee **[ESTADO_PROYECTO.md](../ESTADO_PROYECTO.md)** para ver qué está hecho
3. Lee **[TODO.md](../TODO.md)** para ver qué falta por hacer
4. Consulta **[INDEX.md](INDEX.md)** (este archivo) para encontrar documentación específica

### Si quieres configurar Keycloak:
1. Lee **[KEYCLOAK_INTEGRATION_PLAN.md](KEYCLOAK_INTEGRATION_PLAN.md)** - Todo está ahí
   - Conceptos clave
   - Configuración paso a paso
   - Troubleshooting completo

### Si quieres validar cambios:
1. Lee **[VALIDATION_GUIDE.md](VALIDATION_GUIDE.md)** - Todo está ahí

### Si quieres hacer backups:
1. Lee **[BACKUP_GUIDE.md](BACKUP_GUIDE.md)**

### Si quieres usar el monitoreo y dashboards:
1. Lee **[GRAFANA_MONITORING_GUIDE.md](GRAFANA_MONITORING_GUIDE.md)** - Todo está ahí
   - Servicios de monitoreo
   - Dashboards disponibles
   - Configuración y uso
   - Troubleshooting completo

---

## 📝 Notas Importantes

### Archivos Consolidados

La información ha sido consolidada en archivos principales:

- **KEYCLOAK_INTEGRATION_PLAN.md** - Contiene TODA la información de integración de Keycloak:
  - Configuración de Grafana (paso a paso, troubleshooting)
  - Configuración de Open WebUI (limitación conocida documentada)
  - Configuración de n8n (paso a paso)
  - Credenciales y acceso
  - Conceptos clave (URLs, flujos OAuth)
  - Troubleshooting completo

- **VALIDATION_GUIDE.md** - Contiene toda la información de validación y scripts

### Archivos Eliminados (Información Consolidada)

Los siguientes archivos fueron eliminados porque su información fue consolidada en KEYCLOAK_INTEGRATION_PLAN.md:
- `GRAFANA_KEYCLOAK_SETUP.md` → Consolidado
- `HOW_TO_LOGIN_GRAFANA.md` → Consolidado
- `KEYCLOAK_CREDENTIALS.md` → Consolidado
- `KEYCLOAK_GRAFANA_FIX.md` → Consolidado
- `OPEN_WEBUI_KEYCLOAK_SETUP.md` → Consolidado
- `LIMITACION_OPEN_WEBUI_KEYCLOAK.md` → Consolidado
- `RECOMENDACION_FINAL_OPEN_WEBUI_KEYCLOAK.md` → Consolidado
- Y ~30 archivos más de troubleshooting específico → Todos consolidados

### Política de Documentación

- ✅ Consolidar información relacionada en archivos principales
- ✅ Crear archivos nuevos solo cuando sea absolutamente necesario
- ✅ Mantener este INDEX.md actualizado
- ✅ Un solo archivo por tema principal
- ✅ README.md y README.es.md sincronizados
- ❌ No crear archivos .md muy específicos o temporales

---

## 🗂️ Archivos por Categoría

### Documentación General
- README.md / README.es.md
- ESTADO_PROYECTO.md
- TODO.md
- PROXIMOS_PASOS.md - ⭐ **NUEVO** - Plan de acción detallado con próximos pasos recomendados

### Configuración
- docs/KEYCLOAK_INTEGRATION_PLAN.md (TODO Keycloak)
- docs/BACKUP_GUIDE.md
- docs/VARIABLES_ENTORNO_DINAMICAS.md
- docs/DOCKER_COMPOSE_RESTART_VS_RECREATE.md
- docs/GRAFANA_MONITORING_GUIDE.md (Monitoreo y dashboards)
- docs/STACK_MANAGER_GUIDE.md (Gestión de perfiles)
- docs/ENV_AUTO_FIX.md - ⭐ **NUEVO** - Corrección automática de variables .env (transparente para el usuario)

### Monitoreo
- docs/GRAFANA_MONITORING_GUIDE.md

### Validación y Testing
- docs/VALIDATION_GUIDE.md

### Utilidades
- DIAGRAMS_INSTRUCTIONS.md / DIAGRAMS_INSTRUCTIONS.es.md
- docs/N8N_UPDATE_STRATEGY.md

---

**Última actualización**: 2025-12-07
