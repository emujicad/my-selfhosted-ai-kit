# 📋 Próximos Pasos Detallados - My Self-Hosted AI Kit

**Última actualización**: 2026-01-24  
**Estado del proyecto**: Open WebUI + Keycloak completado, stack-manager.sh mejorado, monitoreo y dashboards completados, optimizaciones de Ollama parcialmente completadas

---

## 📊 Resumen Ejecutivo

### ✅ Completado Recientemente
- ✅ Mejoras de dashboards de Grafana (9 dashboards completos)
- ✅ Optimizaciones de Ollama (parcialmente completadas)
- ✅ Mejoras de HAProxy (health checks, rate limiting, routing mejorado)
- ✅ Exporters personalizados (nvidia, ollama, n8n, openwebui)
- ✅ Sistema de backups automático
- ✅ Integración Keycloak con Grafana

### 🎯 Próximos Pasos por Prioridad

**Prioridad Alta**: Seguridad básica (Keycloak, HTTPS/SSL, Gestión de secretos)  
**Prioridad Media**: Monitoreo avanzado (Alertas, Redis, Logging)  
**Prioridad Baja**: Optimizaciones y mejoras avanzadas

---

## 🔥 PRIORIDAD ALTA (Implementar Primero)

### 1. 🔐 Completar Integración Keycloak

**Estado Actual:**
- ✅ Grafana: Completado y funcionando
- ✅ Open WebUI: ✅ **COMPLETADO** (Emulated OIDC Environment: Fake Discovery + Fake UserInfo + SQLite user mapping)
- ✅ n8n: Configuración lista, clientes OIDC creados automáticamente por `keycloak-init`
- ✅ Jenkins: Script de inicialización listo, clientes OIDC creados automáticamente por `keycloak-init`

**Tareas Pendientes:**

#### 1.1 Probar Integración n8n con Keycloak
**Objetivo**: Validar que n8n puede autenticarse con Keycloak usando OIDC

**Pasos:**
1. Levantar servicios necesarios:
   ```bash
   ./scripts/stack-manager.sh start security automation
   ```

2. Verificar que los clientes OIDC se crearon automáticamente:
   - Acceder a Keycloak: http://localhost:8080/admin
   - Ir a Clients → Verificar que "n8n" existe
   - Verificar configuración del cliente (redirect URIs, etc.)

3. Verificar que el secret se actualizó en `.env`:
   ```bash
   grep N8N_OIDC_CLIENT_SECRET .env
   ```

4. Probar login en n8n:
   - Acceder a http://localhost:5678
   - Intentar login con OIDC
   - Verificar que redirige a Keycloak
   - Completar autenticación y verificar que regresa a n8n

**Documentación de referencia:**
- `docs/KEYCLOAK_INTEGRATION_PLAN.md` - Guía completa
- `scripts/keycloak-manager.sh help` - Comandos disponibles

#### 1.2 Probar Integración Jenkins con Keycloak
**Objetivo**: Validar que Jenkins puede autenticarse con Keycloak usando OIDC

**Pasos:**
1. Levantar servicios necesarios:
   ```bash
   ./scripts/stack-manager.sh start security ci-cd
   ```

2. Verificar que los clientes OIDC se crearon automáticamente:
   - Acceder a Keycloak: http://localhost:8080/admin
   - Ir a Clients → Verificar que "jenkins" existe
   - Verificar configuración del cliente

3. Verificar que el secret se actualizó en `.env`:
   ```bash
   grep JENKINS_OIDC_CLIENT_SECRET .env
   ```

4. Ejecutar script de inicialización (configura plugin OIDC):
   ```bash
   ./scripts/init-jenkins-oidc.sh
   ```

5. Probar login en Jenkins:
   - Acceder a http://localhost:8081
   - Intentar login con OIDC
   - Verificar que redirige a Keycloak
   - Completar autenticación y verificar que regresa a Jenkins

**Archivos relevantes:**
- `scripts/init-jenkins-oidc.sh` - Script de inicialización de Jenkins OIDC

#### 1.3 Configurar Roles y Permisos Básicos en Keycloak
**Objetivo**: Establecer un sistema de roles y permisos básico para control de acceso

**Tareas:**
1. **Crear roles en Keycloak:**
   - `admin`: Acceso completo a todos los servicios
   - `editor`: Puede modificar configuraciones y datos
   - `viewer`: Solo lectura, puede ver dashboards y métricas

2. **Asignar roles a usuarios:**
   - Asignar roles a usuarios existentes
   - Crear usuarios nuevos con roles apropiados
   - Documentar qué usuarios tienen qué roles

3. **Configurar mapeo de roles en servicios:**
   - Grafana: Configurar mapeo de roles de Keycloak a roles de Grafana
   - n8n: Configurar permisos basados en roles
   - Jenkins: Configurar permisos basados en roles

**Comandos útiles:**
```bash
# Ver usuarios en Keycloak
./scripts/keycloak-manager.sh show-users

# Crear usuario
./scripts/keycloak-manager.sh create-user <username> <email> <password>

# Ver clientes OIDC
./scripts/keycloak-manager.sh show-clients
```

**Documentación:**
- `docs/KEYCLOAK_INTEGRATION_PLAN.md` - Guía de integración
- [Keycloak Documentation - Roles](https://www.keycloak.org/docs/latest/server_admin/#_roles)

---

### 2. 🔒 Implementar HTTPS/SSL

**Estado Actual:**
- ✅ HAProxy configurado con mejoras (health checks, rate limiting, routing)
- ⏳ SSL/HTTPS pendiente de implementar

**Tareas:**

#### 2.1 Configurar Certificados SSL
**Opción A: Let's Encrypt (Producción)**
- Instalar certbot
- Configurar dominio (si tienes uno)
- Obtener certificados SSL
- Configurar renovación automática

**Opción B: Certificados Autofirmados (Desarrollo)**
- Generar certificados autofirmados
- Configurar para desarrollo local

**Recursos:**
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/)

#### 2.2 Configurar HAProxy con SSL Termination
**Tareas:**
1. Actualizar `haproxy/haproxy.cfg`:
   - Agregar configuración SSL en frontend
   - Montar certificados en contenedor HAProxy
   - Configurar bind con SSL en puerto 443

2. Configurar redirección HTTP → HTTPS:
   - Redirigir todo el tráfico HTTP (puerto 80) a HTTPS (puerto 443)
   - Configurar redirect en HAProxy

**Archivos a modificar:**
- `haproxy/haproxy.cfg` - Agregar configuración SSL
- `docker-compose.yml` - Montar certificados en HAProxy

**Ejemplo de configuración SSL en HAProxy:**
```haproxy
frontend https_frontend
    bind *:443 ssl crt /etc/ssl/certs/haproxy.pem
    http-request redirect scheme https unless { ssl_fc }
    default_backend http_back
```

#### 2.3 Actualizar Servicios para HTTPS
**Tareas:**
1. Actualizar URLs en configuraciones:
   - Actualizar redirect URIs en Keycloak para usar HTTPS
   - Actualizar URLs en Grafana, n8n, Jenkins
   - Verificar que todos los servicios funcionen con HTTPS

2. Verificar certificados:
   - Verificar que los certificados se renuevan automáticamente
   - Configurar alertas para certificados próximos a expirar

**Servicios a actualizar:**
- Keycloak: Redirect URIs de clientes OIDC
- Grafana: Root URL
- n8n: Webhook URLs
- Jenkins: Root URL

---

### 3. 🔐 Gestión de Secretos (Opcional pero Recomendado)

**Objetivo**: Migrar credenciales sensibles de `.env` a un sistema de gestión de secretos más seguro

**Tareas:**

#### 3.1 Configurar HashiCorp Vault
1. Agregar Vault al `docker-compose.yml`
2. Configurar persistencia de datos de Vault
3. Inicializar Vault
4. Configurar políticas de acceso
5. Configurar autenticación (AppRole, Token, etc.)

**Recursos:**
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Docker Image](https://hub.docker.com/_/vault)

#### 3.2 Migrar Credenciales a Vault
**Credenciales a migrar:**
- Contraseñas de bases de datos (PostgreSQL, Keycloak)
- Secrets de OIDC (Grafana, n8n, Jenkins, Open WebUI)
- API keys y tokens
- Certificados SSL

**Proceso:**
1. Identificar todas las credenciales en `.env`
2. Migrar a Vault
3. Actualizar servicios para leer de Vault
4. Mantener `.env` solo para configuración no sensible

#### 3.3 Configurar Rotación Automática de Secretos
1. Configurar políticas de rotación
2. Automatizar renovación de secretos
3. Configurar notificaciones cuando se roten secretos

**Documentación:**
- `docs/VARIABLES_ENTORNO_DINAMICAS.md` - Guía de variables de entorno

---

## ⚡ PRIORIDAD MEDIA (Implementar Después)

### 4. 📊 Alertas Inteligentes en Grafana

**Estado Actual:**
- ✅ Dashboards de Grafana completados (9 dashboards)
- ✅ Alertas básicas en Prometheus configuradas
- ⏳ Alertas visuales en Grafana pendientes

**Tareas:**

#### 4.1 Configurar Grafana Alerting
1. Habilitar Grafana Alerting
2. Configurar canales de notificación:
   - Email
   - Slack (opcional)
   - Webhook (opcional)

#### 4.2 Crear Alertas Basadas en Paneles
**Alertas a configurar:**
- **CPU Usage > 80%** por más de 5 minutos
- **Memoria Usage > 85%** por más de 5 minutos
- **Disco lleno** (< 15% disponible)
- **Servicios caídos** (Ollama, Keycloak, PostgreSQL, etc.)
- **GPU Temperature > 80°C** (sobrecalentamiento)
- **GPU Memory > 90%** (memoria GPU casi llena)
- **Ollama no responde** (health check fallido)
- **Alta latencia** en respuestas de Ollama (> 10s)

**Documentación:**
- `docs/MONITORING_NEXT_STEPS.md` - Guía de próximos pasos de monitoreo
- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)

---

### 5. 💾 Implementar Redis

**Estado Actual:**
- ✅ Redis disponible en el perfil `infrastructure`
- ⏳ Configuración e integración pendiente

**Tareas:**

#### 5.1 Configurar Redis
1. Configurar persistencia de Redis:
   - Habilitar AOF (Append Only File)
   - Configurar snapshots (RDB)
   - Configurar directorio de persistencia

2. Configurar memoria máxima:
   - Establecer límite de memoria
   - Configurar política de evicción (LRU, etc.)

**Archivos a modificar:**
- `docker-compose.yml` - Configurar Redis con persistencia

#### 5.2 Integrar con Open WebUI
**Tareas:**
1. Configurar cache de sesiones de usuario
2. Configurar cache de respuestas frecuentes
3. Actualizar configuración de Open WebUI para usar Redis

**Beneficios:**
- Sesiones más rápidas
- Menor carga en la base de datos
- Mejor rendimiento general

#### 5.3 Integrar con n8n
**Tareas:**
1. Configurar cache de resultados de workflows
2. Configurar cache de datos frecuentes
3. Actualizar configuración de n8n para usar Redis

**Beneficios:**
- Workflows más rápidos
- Menor procesamiento redundante
- Mejor escalabilidad

#### 5.4 Cache de Embeddings
**Tareas:**
1. Configurar cache de embeddings generados
2. Reducir recálculo de embeddings similares

**Recursos:**
- [Redis Documentation](https://redis.io/docs/)
- [Redis Persistence](https://redis.io/docs/management/persistence/)

---

### 6. 📝 Logging Centralizado (ELK Stack)

**Objetivo**: Centralizar todos los logs del sistema para facilitar debugging y monitoreo

**Tareas:**

#### 6.1 Configurar ELK Stack
1. **Elasticsearch:**
   - Configurar cluster de Elasticsearch
   - Configurar índices para logs
   - Configurar políticas de retención

2. **Logstash:**
   - Configurar pipelines de procesamiento
   - Configurar parsers para diferentes tipos de logs
   - Configurar filtros y transformaciones

3. **Kibana:**
   - Configurar dashboards de logs
   - Configurar visualizaciones
   - Configurar búsquedas guardadas

**Archivos a crear/modificar:**
- `docker-compose.yml` - Agregar servicios ELK
- `elk/logstash/pipeline/` - Pipelines de Logstash
- `elk/kibana/dashboards/` - Dashboards de Kibana

#### 6.2 Configurar Recolección de Logs
1. Configurar Docker logging driver:
   - Configurar todos los servicios para enviar logs a Logstash
   - Usar syslog o gelf driver

2. Recolectar logs de todos los servicios:
   - Ollama
   - Open WebUI
   - n8n
   - Keycloak
   - Grafana
   - PostgreSQL
   - HAProxy
   - Prometheus

#### 6.3 Configurar Log Rotation y Retención
1. Configurar políticas de retención:
   - Logs de aplicación: 30 días
   - Logs de sistema: 7 días
   - Logs de acceso: 90 días

2. Configurar rotación automática:
   - Rotar logs diariamente
   - Comprimir logs antiguos
   - Eliminar logs expirados

#### 6.4 Crear Dashboards de Logs
**Dashboards a crear:**
- Errores por servicio
- Patrones de uso
- Tendencias de errores
- Logs de acceso
- Logs de seguridad

#### 6.5 Configurar Alertas Basadas en Logs
**Alertas a configurar:**
- Errores críticos en logs
- Patrones sospechosos
- Intentos de acceso no autorizados
- Errores repetidos de servicios

**Recursos:**
- [ELK Stack Documentation](https://www.elastic.co/elk-stack)
- [Logstash Documentation](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)

---

## 🎯 PRIORIDAD BAJA (Implementar al Final)

### 7. ⚡ Completar Optimizaciones de Ollama

**Estado Actual:**
- ✅ Variables de optimización configuradas (OLLAMA_MAX_LOADED_MODELS=2, OLLAMA_NUM_THREAD=8, OLLAMA_KEEP_ALIVE=10m)
- ✅ Shared memory configurado (shm_size=2g)
- ✅ Límites de recursos configurados
- ✅ Dashboard de monitoreo creado
- ⏳ Queue de requests pendiente

**Tareas Pendientes:**

#### 7.1 Implementar Queue de Requests
**Objetivo**: Gestionar mejor la carga de requests concurrentes a Ollama

**Tareas:**
1. Implementar sistema de cola para requests
2. Configurar límites de requests concurrentes
3. Implementar priorización de requests
4. Monitorear cola de requests

**Recursos:**
- `docs/OLLAMA_OPTIMIZATION_MONITORING.md` - Monitoreo de optimizaciones
- `docs/TESTING_OLLAMA_OPTIMIZATIONS.md` - Testing de optimizaciones

---

### 8. 🎨 Panel de Administración Unificado

**Objetivo**: Crear una interfaz web unificada para administrar todo el sistema

**Tareas:**

#### 8.1 Dashboard Principal
1. Estado de todos los servicios en tiempo real
2. Métricas clave (CPU, memoria, disco, GPU)
3. Alertas y notificaciones
4. Enlaces rápidos a servicios

#### 8.2 Gestión de Usuarios y Permisos
1. Interfaz para gestionar usuarios de Keycloak
2. Asignación de roles
3. Permisos por servicio
4. Historial de cambios

#### 8.3 Configuración de Servicios
1. Configuración de servicios desde interfaz web
2. Cambios de configuración sin editar archivos manualmente
3. Validación de configuraciones
4. Rollback de cambios

**Tecnologías sugeridas:**
- React o Vue.js para frontend
- API REST para backend
- Integración con Keycloak para autenticación

---

### 9. 🔧 Otras Tareas Pendientes

#### 9.1 Resolver PostgreSQL Exporter
**Problema**: PostgreSQL Exporter muestra "Exporter Not Connected"  
**Tareas:**
- Revisar configuración de autenticación
- Verificar conexión a PostgreSQL
- Corregir configuración del exporter

#### 9.2 Implementar CI/CD Básico
**Estado**: Jenkins ya está configurado  
**Tareas:**
- Configurar pipelines básicos
- Testing automático
- Deployment automático
- Notificaciones de deployment

#### 9.3 Mejorar Open WebUI
**Tareas:**
- Tema oscuro/claro
- Soporte multiidioma
- Historial de conversaciones mejorado
- Exportación de chats

#### 9.4 API RESTful Unificada
**Tareas:**
- Documentación con Swagger
- Autenticación JWT
- Rate limiting por usuario
- Webhooks para notificaciones

---

## 📅 Plan de Implementación Recomendado

### Semana 1-2: Seguridad Básica
1. **Completar integración Keycloak**
   - Probar n8n con Keycloak
   - Probar Jenkins con Keycloak
   - Configurar roles y permisos

2. **Implementar HTTPS/SSL**
   - Configurar certificados
   - Configurar HAProxy con SSL
   - Actualizar servicios para HTTPS

### Semana 3-4: Monitoreo y Optimización
3. **Alertas inteligentes en Grafana**
   - Configurar alertas visuales
   - Configurar notificaciones
   - Crear alertas para recursos y servicios

4. **Implementar Redis**
   - Configurar Redis
   - Integrar con Open WebUI
   - Integrar con n8n

### Semana 5-6: Logging y Mejoras
5. **Logging centralizado (ELK Stack)**
   - Configurar ELK Stack
   - Configurar recolección de logs
   - Crear dashboards de logs

6. **Completar optimizaciones de Ollama**
   - Implementar queue de requests
   - Mejorar gestión de carga

### Semana 7+: Mejoras Avanzadas
7. **Panel de administración unificado**
   - Dashboard principal
   - Gestión de usuarios
   - Configuración de servicios

8. **Otras tareas pendientes**
   - Resolver PostgreSQL Exporter
   - Implementar CI/CD básico
   - Mejorar Open WebUI
   - API RESTful unificada

---

## 📚 Documentación de Referencia

### Documentos Principales
- `README.md` / `README.es.md` - Visión general del proyecto
- `ESTADO_PROYECTO.md` - Estado actual del proyecto
- `TODO.md` - Lista de tareas pendientes
- `PROXIMOS_PASOS.md` - Plan de acción recomendado
- `docs/INDEX.md` - Índice de toda la documentación

### Guías Específicas
- `docs/KEYCLOAK_INTEGRATION_PLAN.md` - Integración completa de Keycloak
- `docs/BACKUP_GUIDE.md` - Guía de backups y restauración
- `docs/GRAFANA_MONITORING_GUIDE.md` - Guía de monitoreo
- `docs/STACK_MANAGER_GUIDE.md` - Gestión del stack
- `docs/VALIDATION_GUIDE.md` - Validación y testing
- `docs/MONITORING_NEXT_STEPS.md` - Próximos pasos de monitoreo
- `docs/TESTING_OLLAMA_OPTIMIZATIONS.md` - Testing de optimizaciones
- `docs/OLLAMA_OPTIMIZATION_MONITORING.md` - Monitoreo de optimizaciones

### Scripts Disponibles
- `./scripts/stack-manager.sh` - Gestión completa del stack
- `./scripts/backup-manager.sh` - Gestión de backups
- `./scripts/keycloak-manager.sh` - Gestión de Keycloak
- `./scripts/validate-config.sh` - Validación de configuración
- `./scripts/init-jenkins-oidc.sh` - Inicialización de Jenkins OIDC
- `./scripts/test-ollama-quick.sh` - Testing rápido de Ollama
- `./scripts/test-ollama-performance.sh` - Testing de rendimiento de Ollama
- `./scripts/test-ollama-advanced.sh` - Testing avanzado de Ollama

---

## 💡 Recomendaciones Finales

1. **Priorizar seguridad**: Completar HTTPS/SSL y gestión de secretos antes de optimizaciones
2. **Probar incrementalmente**: No implementar todo de una vez, probar cada cambio
3. **Documentar todo**: Mantener documentación actualizada
4. **Hacer backups**: Siempre hacer backup antes de cambios importantes
5. **Usar scripts**: Usar los scripts consolidados en lugar de comandos manuales
6. **Monitorear cambios**: Verificar que los cambios no afecten el rendimiento
7. **Tener plan de rollback**: Tener plan de rollback para cada cambio importante

---

**Última actualización**: 2026-01-24  
**Próxima revisión**: Después de completar tareas de Prioridad Alta

