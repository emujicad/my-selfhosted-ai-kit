# 🚀 Roadmap - My Self-Hosted AI Kit

**Última actualización**: 2026-01-24

Este documento combina el plan de acción general con los próximos pasos detallados para el proyecto. Está organizado por prioridades y proporciona una guía completa para implementar todas las funcionalidades pendientes.

---

## 📊 Resumen del Estado Actual

### ✅ Completado Recientemente

1. **Sistema de Backups** ✅
   - Backup incremental y completo
   - Restauración automática
   - Verificación de integridad
   - Script consolidado: `backup-manager.sh`

2. **Integración Keycloak - Grafana** ✅
   - Grafana completamente integrado con Keycloak
   - OAuth funcionando correctamente
   - Documentación completa en `docs/KEYCLOAK_GUIDE.md`

3. **Integración Open WebUI + Keycloak** ✅ **COMPLETADO**
   - Solución "Emulated OIDC Environment" implementada
   - Fake Discovery (`oidc-config.json`) para split-horizon routing
   - Fake UserInfo (`userinfo.json`) para bypass de 401 errors
   - Autenticación SSO totalmente funcional con admin@emujicad

4. **Monitoreo Completo** ✅
   - Prometheus configurado
   - Grafana con 9 dashboards pre-configurados
   - AlertManager funcionando
   - Documentación en `docs/MONITORING_GUIDE.md`

5. **Scripts Consolidados** ✅
   - `stack-manager.sh` - Gestión completa del stack con **resolución automática de dependencias**
   - `backup-manager.sh` - Gestión de backups
   - `keycloak-manager.sh` - Gestión de Keycloak
   - Scripts de validación integrados

6. **Actualización de n8n** ✅
   - Actualizado de 1.101.2 a 1.122.5
   - Estrategia documentada en `docs/CONFIGURATION.md`

7. **Mejoras de HAProxy** ✅
   - Health checks avanzados (inter 3s, fall 3, rise 2)
   - Rate limiting (100 req/10s por IP) - Protección DDoS
   - Routing mejorado por paths
   - Timeouts optimizados, logging y estadísticas mejoradas

8. **Mejoras de Dashboards de Grafana** ✅
   - 9 dashboards completos y profesionales
   - Métricas específicas de IA, GPU/CPU, usuarios, costos
   - Executive Summary Dashboard
   - Ollama Optimization Monitoring Dashboard

9. **Optimizaciones de Ollama** ✅ **PARCIALMENTE COMPLETADO**
   - Variables de optimización configuradas
   - Shared memory configurado (shm_size=2g)
   - Límites de recursos configurados
   - Dashboard de monitoreo creado
   - ⏳ Queue de requests (pendiente)

---

## 🎯 Plan de Acción por Prioridades

### 🔥 PRIORIDAD ALTA (Semanas 1-2)

#### 1. 🔐 Completar Integración Keycloak

**Estado actual:**
- ✅ Grafana: Completado y funcionando
- ✅ Open WebUI: Completado (Emulated OIDC Environment)
- ✅ n8n: Configuración lista, clientes OIDC creados automáticamente
- ✅ Jenkins: Script de inicialización listo, clientes OIDC creados automáticamente

**Tareas pendientes:**

##### 1.1 Probar Integración n8n con Keycloak
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
- `docs/KEYCLOAK_GUIDE.md` - Guía completa
- `scripts/keycloak-manager.sh help` - Comandos disponibles

##### 1.2 Probar Integración Jenkins con Keycloak
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

##### 1.3 Configurar Roles y Permisos Básicos en Keycloak
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
- `docs/KEYCLOAK_GUIDE.md` - Guía de integración
- [Keycloak Documentation - Roles](https://www.keycloak.org/docs/latest/server_admin/#_roles)

---

#### 2. 🔒 Implementar HTTPS/SSL

**Estado actual:**
- ✅ HAProxy configurado con mejoras (health checks, rate limiting, routing)
- ⏳ SSL/HTTPS pendiente de implementar

**Tareas:**

##### 2.1 Configurar Certificados SSL
**Opción A: Let's Encrypt (Producción)**
- Instalar certbot
- Configurar dominio (si tienes uno)
- Obtener certificados SSL
-Configurar renovación automática

**Opción B: Certificados Autofirmados (Desarrollo)**
- Generar certificados autofirmados
- Configurar para desarrollo local

**Recursos:**
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/)

##### 2.2 Configurar HAProxy con SSL Termination
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

##### 2.3 Actualizar Servicios para HTTPS
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

#### 3. 🔐 Gestión de Secretos (Opcional pero Recomendado)

**Objetivo**: Migrar credenciales sensibles de `.env` a un sistema de gestión de secretos más seguro

**Tareas:**

##### 3.1 Configurar HashiCorp Vault
1. Agregar Vault al `docker-compose.yml`
2. Configurar persistencia de datos de Vault
3. Inicializar Vault
4. Configurar políticas de acceso
5. Configurar autenticación (AppRole, Token, etc.)

**Recursos:**
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Docker Image](https://hub.docker.com/_/vault)

##### 3.2 Migrar Credenciales a Vault
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

##### 3.3 Configurar Rotación Automática de Secretos
1. Configurar políticas de rotación
2. Automatizar renovación de secretos
3. Configurar notificaciones cuando se roten secretos

**Documentación:**
- `docs/CONFIGURATION.md` - Guía de variables de entorno

---

### ⚡ PRIORIDAD MEDIA (Semanas 3-6)

#### 4. 📊 Alertas Inteligentes en Grafana

**Estado actual:**
- ✅ Dashboards de Grafana completados (9 dashboards)
- ✅ Alertas básicas en Prometheus configuradas
- ⏳ Alertas visuales en Grafana pendientes

**Tareas:**

##### 4.1 Configurar Grafana Alerting
1. Habilitar Grafana Alerting
2. Configurar canales de notificación:
   - Email
   - Slack (opcional)
   - Webhook (opcional)

##### 4.2 Crear Alertas Basadas en Paneles
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
- `docs/MONITORING_GUIDE.md` - Guía de monitoreo
- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)

---

#### 5. 💾 Implementar Redis

**Estado actual:**
- ✅ Redis disponible en el perfil `infrastructure`
- ⏳ Configuración e integración pendiente

**Tareas:**

##### 5.1 Configurar Redis
1. Configurar persistencia de Redis:
   - Habilitar AOF (Append Only File)
   - Configurar snapshots (RDB)
   - Configurar directorio de persistencia

2. Configurar memoria máxima:
   - Establecer límite de memoria
   - Configurar política de evicción (LRU, etc.)

**Archivos a modificar:**
- `docker-compose.yml` - Configurar Redis con persistencia

##### 5.2 Integrar con Open WebUI
**Tareas:**
1. Configurar cache de sesiones de usuario
2. Configurar cache de respuestas frecuentes
3. Actualizar configuración de Open WebUI para usar Redis

**Beneficios:**
- Sesiones más rápidas
- Menor carga en la base de datos
- Mejor rendimiento general

##### 5.3 Integrar con n8n
**Tareas:**
1. Configurar cache de resultados de workflows
2. Configurar cache de datos frecuentes
3. Actualizar configuración de n8n para usar Redis

**Beneficios:**
- Workflows más rápidos
- Menor procesamiento redundante
- Mejor escalabilidad

##### 5.4 Cache de Embeddings
**Tareas:**
1. Configurar cache de embeddings generados
2. Reducir recálculo de embeddings similares

**Recursos:**
- [Redis Documentation](https://redis.io/docs/)
- [Redis Persistence](https://redis.io/docs/management/persistence/)

---

#### 6. 📝 Logging Centralizado (ELK Stack)

**Objetivo**: Centralizar todos los logs del sistema para facilitar debugging y monitoreo

**Tareas:**

##### 6.1 Configurar ELK Stack
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

##### 6.2 Configurar Recolección de Logs
1. Configurar Docker logging driver:
   - Configurar todos los servicios para enviar logs a Logstash
   - Usar syslog o gelf driver

2. Recolectar logs de todos los servicios:
   - Ollama, Open WebUI, n8n, Keycloak, Grafana, PostgreSQL, HAProxy, Prometheus

##### 6.3 Configurar Log Rotation y Retención
1. Configurar políticas de retención:
   - Logs de aplicación: 30 días
   - Logs de sistema: 7 días
   - Logs de acceso: 90 días

2. Configurar rotación automática:
   - Rotar logs diariamente
   - Comprimir logs antiguos
   - Eliminar logs expirados

##### 6.4 Crear Dashboards de Logs y Alertas
**Dashboards:**
- Errores por servicio
- Patrones de uso
- Tendencias de errores
- Logs de acceso
- Logs de seguridad

**Alertas:**
- Errores críticos en logs
- Patrones sospechosos
- Intentos de acceso no autorizados
- Errores repetidos de servicios

**Recursos:**
- [ELK Stack Documentation](https://www.elastic.co/elk-stack)
- [Logstash Documentation](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)

---

### 🎯 PRIORIDAD BAJA (Semanas 7+)

#### 7. ⚡ Completar Optimizaciones de Ollama

**Estado actual:**
- ✅ Variables de optimización configuradas
- ✅ Shared memory configurado (shm_size=2g)
- ✅ Límites de recursos configurados
- ✅ Dashboard de monitoreo creado
- ⏳ Queue de requests pendiente

**Tareas pendientes:**

##### 7.1 Implementar Queue de Requests
**Objetivo**: Gestionar mejor la carga de requests concurrentes a Ollama

**Tareas:**
1. Implementar sistema de cola para requests
2. Configurar límites de requests concurrentes
3. Implementar priorización de requests
4. Monitorear cola de requests

**Recursos:**
- `docs/OLLAMA_GUIDE.md` - Optimización y monitoreo de Ollama

---

#### 8. 🎨 Panel de Administración Unificado

**Objetivo**: Crear una interfaz web unificada para administrar todo el sistema

**Tareas:**

##### 8.1 Dashboard Principal
1. Estado de todos los servicios en tiempo real
2. Métricas clave (CPU, memoria, disco, GPU)
3. Alertas y notificaciones
4. Enlaces rápidos a servicios

##### 8.2 Gestión de Usuarios y Permisos
1. Interfaz para gestionar usuarios de Keycloak
2. Asignación de roles
3. Permisos por servicio
4. Historial de cambios

##### 8.3 Configuración de Servicios
1. Configuración de servicios desde interfaz web
2. Cambios de configuración sin editar archivos manualmente
3. Validación de configuraciones
4. Rollback de cambios

**Tecnologías sugeridas:**
- React o Vue.js para frontend
- API REST para backend
- Integración con Keycloak para autenticación

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
   - Implementar CI/CD básico
   - Mejorar Open WebUI
   - API RESTful unificada

---

## 📋 Checklist de Implementación

### Antes de Empezar

- [ ] Revisar `PROJECT_STATUS.md` para estado actual
- [ ] Hacer backup completo: `./scripts/backup-manager.sh backup --full --verify`
- [ ] Validar configuración: `./scripts/stack-manager.sh validate`

### Para Cada Tarea

- [ ] Leer documentación relevante en `docs/`
- [ ] Hacer backup antes de cambios importantes
- [ ] Probar en entorno de desarrollo si es posible
- [ ] Documentar cambios realizados
- [ ] Actualizar `PROJECT_STATUS.md` al completar
- [ ] Marcar tareas completadas en este archivo

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

## 📚 Documentación de Referencia

### Documentos Principales
- `README.md` / `README.es.md` - Visión general del proyecto
- `PROJECT_STATUS.md` - Estado actual del proyecto
- `docs/INDEX.md` - Índice de toda la documentación

### Guías Específicas
- `docs/KEYCLOAK_GUIDE.md` - Integración completa de Keycloak
- `docs/BACKUP_GUIDE.md` - Guía de backups y restauración
- `docs/MONITORING_GUIDE.md` - Guía de monitoreo
- `docs/STACK_MANAGER_GUIDE.md` - Gestión del stack
- `docs/VALIDATION_GUIDE.md` - Validación y testing
- `docs/OLLAMA_GUIDE.md` - Optimización y monitoreo de Ollama
- `docs/CONFIGURATION.md` - Variables de entorno y configuración

### Scripts Disponibles
- `./scripts/stack-manager.sh` - Gestión completa del stack
- `./scripts/backup-manager.sh` - Gestión de backups
- `./scripts/keycloak-manager.sh` - Gestión de Keycloak
- `./scripts/validate-config.sh` - Validación de configuración
- `./scripts/init-jenkins-oidc.sh` - Inicialización de Jenkins OIDC

---

**Última actualización**: 2026-01-24  
**Próxima revisión**: Después de completar tareas de Prioridad Alta
