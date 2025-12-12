# 📊 Guía de Monitoreo con Grafana

## 📋 Índice

1. [Resumen General](#resumen-general)
2. [Servicios de Monitoreo](#servicios-de-monitoreo)
3. [Dashboards Disponibles](#dashboards-disponibles)
4. [Configuración](#configuración)
5. [Troubleshooting](#troubleshooting)
6. [Métricas Disponibles](#métricas-disponibles)

---

## 📊 Resumen General

El stack incluye un sistema completo de monitoreo basado en Prometheus y Grafana que permite visualizar el estado y rendimiento de todos los servicios.

### Componentes del Sistema de Monitoreo

- **Prometheus**: Recolector de métricas
- **Grafana**: Visualización y dashboards
- **AlertManager**: Gestión de alertas
- **node-exporter**: Métricas del sistema operativo
- **cAdvisor**: Métricas de contenedores Docker
- **postgres-exporter**: Métricas de PostgreSQL

---

## 🔧 Servicios de Monitoreo

### Prometheus

**Puerto**: `9090`  
**URL**: http://localhost:9090

**Función**: Recolecta y almacena métricas de todos los servicios.

**Configuración**:
- Archivo de configuración: `monitoring/prometheus.yml`
- Reglas de alertas: `monitoring/prometheus/alerts.yml`
- Reglas personalizadas: Volumen `prometheus_rules_data`

**Métricas recolectadas**:
- Métricas del sistema (node-exporter)
- Métricas de contenedores (cAdvisor)
- Métricas de PostgreSQL (postgres-exporter)
- Métricas de servicios (Ollama, n8n, Open WebUI, etc.)

### Grafana

**Puerto**: `3001`  
**URL**: http://localhost:3001

**Función**: Visualización de métricas mediante dashboards interactivos.

**Autenticación**: Integrado con Keycloak (ver [KEYCLOAK_INTEGRATION_PLAN.md](KEYCLOAK_INTEGRATION_PLAN.md))

**Configuración**:
- Archivo de configuración: `monitoring/grafana/config/grafana.ini`
- Datasources: `monitoring/grafana/provisioning/datasources/`
- Dashboards: `monitoring/grafana/provisioning/dashboards/`

### node-exporter

**Puerto**: `9100`

**Función**: Expone métricas del sistema operativo del host.

**Métricas incluidas**:
- CPU usage
- Memory usage
- Disk I/O
- Network traffic
- Load average

### cAdvisor

**Puerto**: `8082`

**Función**: Expone métricas de contenedores Docker.

**Métricas incluidas**:
- CPU usage por contenedor
- Memory usage por contenedor
- Network traffic por contenedor
- Container start time
- Container status

**Nota importante**: cAdvisor expone métricas con el label `id` en formato `/system.slice/docker-<hash>.scope`, no con nombres de contenedores directamente.

### postgres-exporter

**Puerto**: `9187`

**Función**: Expone métricas de PostgreSQL.

**Métricas incluidas**:
- Conexiones activas
- Queries por segundo
- Tamaño de base de datos
- Estado de replicación

**Estado actual**: ⚠️ Tiene problemas de conexión (ver [Troubleshooting](#troubleshooting))

---

## 📈 Dashboards Disponibles

### System Overview Dashboard

**Ubicación**: Grafana → Dashboards → System Overview Dashboard
**UID**: `system-overview`

**Paneles incluidos**:
- **System CPU Usage**: Uso de CPU del sistema
- **System Memory Usage**: Uso de memoria del sistema
- **Disk Usage**: Uso de disco por dispositivo
- **Network Traffic**: Tráfico de red por interfaz
- **Disk I/O**: I/O de disco por dispositivo
- **Container CPU Usage**: Uso de CPU de contenedores Docker
- **Container Memory Usage**: Uso de memoria de contenedores Docker
- **PostgreSQL Status**: Estado de conexiones PostgreSQL
- **Container Status Overview**: Tabla con información de contenedores
- **System Load Average**: Carga promedio del sistema

**Notas**:
- Los paneles de contenedores muestran IDs en lugar de nombres (formato `/system.slice/docker-xxx.scope`)
- PostgreSQL Status muestra "Exporter Not Connected" si postgres-exporter no está conectado

### Ollama AI Models Dashboard

**Ubicación**: Grafana → Dashboards → Ollama AI Models Dashboard
**UID**: `ollama-dashboard`

**Paneles incluidos**:
- **Container Status Overview**: Resumen de contenedores activos
- **Ollama Container CPU Usage**: Uso de CPU de contenedores
- **Ollama Container Memory Usage**: Uso de memoria de contenedores
- **Ollama Container Network Traffic**: Tráfico de red de redes Docker
- **System CPU Usage**: Uso de CPU del sistema
- **System Memory Usage**: Uso de memoria del sistema
- **Container Status Table**: Tabla con tiempos de inicio de contenedores
- **Container Uptime**: Tiempo de actividad de contenedores

**Notas**:
- Network Traffic muestra tráfico de interfaces Docker (`br-*`), no por contenedor individual
- Container Status Table muestra cuándo se iniciaron los contenedores (formato "hace X tiempo")

### GPU/CPU Performance Dashboard ⭐ **NUEVO**

**Ubicación**: Grafana → Dashboards → GPU/CPU Performance Dashboard  
**UID**: `gpu-cpu-performance`

**Paneles incluidos**:
- **GPU Usage (if available)**: Uso de GPU (nota: requiere nvidia-smi exporter para métricas directas)
- **Ollama Container CPU Usage**: Uso de CPU específico de contenedores Ollama
- **Ollama Container Memory Usage**: Uso de memoria de contenedores Ollama en GB
- **CPU Usage by Service**: Desglose de uso de CPU por servicio (bar chart)
- **System Load Average**: Carga promedio del sistema (1m, 5m, 15m)
- **Memory Usage by Service**: Desglose de uso de memoria por servicio (bar chart)
- **Total System Memory Usage**: Uso total de memoria del sistema

**Características**:
- Métricas específicas de GPU/CPU para modelos de IA
- Visualización clara de recursos por servicio
- Alertas visuales con umbrales (verde/amarillo/rojo)

### Users & Sessions Dashboard ⭐ **NUEVO**

**Ubicación**: Grafana → Dashboards → Users & Sessions Dashboard  
**UID**: `users-sessions`

**Paneles incluidos**:
- **PostgreSQL Active Connections**: Conexiones activas por base de datos
- **Total PostgreSQL Connections**: Total de conexiones activas
- **PostgreSQL Transactions**: Tasas de commit y rollback
- **Active Connections Over Time**: Conexiones activas a lo largo del tiempo
- **Keycloak Container Status**: Estado de contenedores Keycloak
- **Keycloak Container CPU**: Uso de CPU de Keycloak
- **Grafana Container Status**: Estado de contenedores Grafana
- **Grafana Container CPU**: Uso de CPU de Grafana
- **PostgreSQL Cache Hit Ratio**: Ratio de aciertos de cache (target: >95%)
- **Service Container Status**: Tabla con estado de todos los contenedores de servicios

**Características**:
- Monitoreo de usuarios activos y sesiones
- Métricas de autenticación (Keycloak, Grafana)
- Métricas de base de datos (PostgreSQL)
- Indicadores de salud de servicios de autenticación

### Cost Estimation Dashboard ⭐ **NUEVO**

**Ubicación**: Grafana → Dashboards → Cost Estimation Dashboard  
**UID**: `cost-estimation`

**Paneles incluidos**:
- **Estimated Hourly Cost (CPU)**: Costo estimado por hora basado en CPU ($0.10/CPU-hr)
- **Estimated Hourly Cost (Memory)**: Costo estimado por hora basado en memoria ($0.05/GB-hr)
- **Total Estimated Hourly Cost**: Costo total por hora (CPU + Memory)
- **Cost Over Time**: Desglose de costos a lo largo del tiempo
- **Cost by Service**: Costo por servicio (bar chart)
- **Estimated Daily Cost**: Costo estimado diario
- **Estimated Monthly Cost**: Costo estimado mensual
- **Resource Usage Summary**: Tabla resumen de uso de recursos por servicio

**Características**:
- Cálculo automático de costos basado en uso de recursos
- Desglose por servicio para identificar servicios costosos
- Proyecciones diarias y mensuales
- **Nota**: Los precios son estimaciones y pueden ajustarse según tu infraestructura

### AI Models Performance Dashboard ⭐ **NUEVO**

**Ubicación**: Grafana → Dashboards → AI Models Performance Dashboard  
**UID**: `ai-models-performance`

**Paneles incluidos**:
- **Ollama Container Status**: Estado de contenedores Ollama
- **Ollama CPU Usage**: Uso de CPU de Ollama
- **Ollama Memory Usage**: Uso de memoria de Ollama
- **Ollama Network I/O**: I/O de red de Ollama
- **Ollama CPU Usage Over Time**: Uso de CPU a lo largo del tiempo (indica actividad de procesamiento)
- **Ollama Memory Usage Over Time**: Uso de memoria a lo largo del tiempo (indica carga de modelos)
- **Estimated Throughput (Requests/Hour)**: Throughput estimado basado en actividad de CPU
- **Estimated Latency (ms)**: Latencia estimada basada en actividad de CPU
- **Open WebUI Container Status**: Estado de contenedores Open WebUI
- **Open WebUI CPU Usage**: Uso de CPU de Open WebUI (indica actividad de usuarios)
- **Open WebUI Memory Usage**: Uso de memoria de Open WebUI
- **AI Services Summary**: Tabla resumen de servicios de IA

**Características**:
- Métricas específicas de rendimiento de modelos de IA
- Estimaciones de throughput y latencia
- Monitoreo de actividad de usuarios (Open WebUI)
- Indicadores de carga de modelos (memoria)

**Notas**:
- Las métricas de throughput y latencia son **estimaciones** basadas en actividad de CPU
- Para métricas precisas de tokens/s, se requiere integración directa con Ollama API
- La latencia estimada es inversamente proporcional a la actividad de CPU

---

## ⚙️ Configuración

### Levantar Servicios de Monitoreo

```bash
# Levantar todos los servicios de monitoreo
docker compose --profile monitoring up -d

# O levantar servicios específicos
docker compose --profile monitoring up -d prometheus grafana node-exporter cadvisor postgres-exporter
```

### Verificar Estado de Servicios

```bash
# Ver estado de servicios de monitoreo
docker compose --profile monitoring ps

# Ver logs de un servicio específico
docker compose logs prometheus
docker compose logs grafana
docker compose logs node-exporter
docker compose logs cadvisor
docker compose logs postgres-exporter
```

### Acceder a Grafana

1. Abre http://localhost:3001
2. Inicia sesión con Keycloak (ver [KEYCLOAK_INTEGRATION_PLAN.md](KEYCLOAK_INTEGRATION_PLAN.md))
3. Navega a Dashboards → Selecciona un dashboard
4. Refresca el dashboard (botón Refresh) para ver datos actualizados

---

## 🔍 Troubleshooting

### Problema: Dashboards muestran "No data"

**Causas posibles**:
1. Los exporters no están corriendo
2. Prometheus no está scrapeando las métricas
3. El time range es incorrecto

**Solución**:

```bash
# 1. Verificar que los exporters estén corriendo
docker compose --profile monitoring ps node-exporter cadvisor postgres-exporter

# 2. Si no están corriendo, levantarlos
docker compose --profile monitoring up -d node-exporter cadvisor postgres-exporter

# 3. Verificar que Prometheus esté scrapeando
# Abre http://localhost:9090/targets
# Deberías ver los exporters como "UP"

# 4. En Grafana:
# - Cambia el time range a "Last 5 minutes" o "Last 15 minutes"
# - Refresca el dashboard
# - Espera 1-2 minutos para que se acumulen métricas históricas
```

### Problema: Container Status Table muestra valores 0

**Causa**: La consulta usa `container_tasks_state` que cuenta tareas, no muestra el estado del contenedor.

**Solución**: Ya corregido. El dashboard ahora usa `container_start_time_seconds` que muestra cuándo se iniciaron los contenedores.

### Problema: Network Traffic no muestra datos

**Causa**: Las métricas de red no están disponibles por contenedor individual en cAdvisor.

**Solución**: Ya corregido. El dashboard ahora muestra tráfico de interfaces Docker (`br-*`) que es lo que está disponible.

### Problema: PostgreSQL Status muestra "Exporter Not Connected"

**Causa**: postgres-exporter no puede conectarse a PostgreSQL debido a problemas de autenticación.

**Estado**: ⚠️ Problema conocido. El exporter tiene problemas de autenticación con PostgreSQL.

**Solución temporal**: El dashboard muestra "Exporter Not Connected" en lugar de solo "0", lo cual es más informativo.

**Para resolver completamente**:
1. Verificar que la contraseña en `.env` coincida con la de PostgreSQL
2. Verificar que postgres-exporter esté en la misma red que postgres (`genai-network`)
3. Verificar configuración de autenticación de PostgreSQL (`pg_hba.conf`)

### Problema: Los paneles muestran IDs de contenedores en lugar de nombres

**Causa**: cAdvisor expone métricas con el label `id` en formato `/system.slice/docker-<hash>.scope`, no con nombres de contenedores.

**Solución**: Esto es normal y esperado. Los IDs son los identificadores reales que usa cAdvisor.

**Nota**: Si necesitas nombres de contenedores, puedes:
1. Usar `docker ps` para mapear IDs a nombres
2. O crear transformaciones en Grafana para mapear IDs a nombres

### Problema: Prometheus muestra targets como "DOWN"

**Solución**:

```bash
# 1. Verificar que los servicios estén corriendo
docker compose ps

# 2. Verificar conectividad de red
docker compose exec prometheus ping -c 1 cadvisor
docker compose exec prometheus ping -c 1 node-exporter

# 3. Verificar configuración de Prometheus
docker compose exec prometheus cat /etc/prometheus/prometheus.yml

# 4. Recargar configuración de Prometheus
curl -X POST http://localhost:9090/-/reload
```

---

## 📊 Métricas Disponibles

### Métricas del Sistema (node-exporter)

- `node_cpu_seconds_total`: Tiempo de CPU por modo
- `node_memory_MemTotal_bytes`: Memoria total
- `node_memory_MemAvailable_bytes`: Memoria disponible
- `node_disk_read_bytes_total`: Bytes leídos de disco
- `node_disk_written_bytes_total`: Bytes escritos en disco
- `node_network_receive_bytes_total`: Bytes recibidos por interfaz
- `node_network_transmit_bytes_total`: Bytes transmitidos por interfaz
- `node_load1`, `node_load5`, `node_load15`: Carga promedio del sistema

### Métricas de Contenedores (cAdvisor)

- `container_cpu_usage_seconds_total`: Uso de CPU por contenedor
- `container_memory_usage_bytes`: Uso de memoria por contenedor
- `container_network_receive_bytes_total`: Bytes recibidos por contenedor
- `container_network_transmit_bytes_total`: Bytes transmitidos por contenedor
- `container_start_time_seconds`: Tiempo de inicio del contenedor
- `container_tasks_state`: Estado de tareas del contenedor

**Nota**: Todas las métricas de contenedores usan el label `id` con formato `/system.slice/docker-<hash>.scope`.

### Métricas de PostgreSQL (postgres-exporter)

- `pg_up`: Estado de conexión (1 = conectado, 0 = desconectado)
- `pg_stat_database_numbackends`: Número de conexiones activas por base de datos
- `pg_stat_database_xact_commit`: Transacciones commitadas
- `pg_stat_database_xact_rollback`: Transacciones revertidas
- `pg_stat_database_blks_read`: Bloques leídos
- `pg_stat_database_blks_hit`: Bloques encontrados en cache

**Estado**: ⚠️ Actualmente no disponible debido a problemas de conexión del exporter.

---

## 🔄 Actualización de Dashboards

Los dashboards están provisionados automáticamente desde:
- `monitoring/grafana/provisioning/dashboards/system-overview.json` - System Overview Dashboard
- `monitoring/grafana/provisioning/dashboards/ollama-dashboard.json` - Ollama AI Models Dashboard
- `monitoring/grafana/provisioning/dashboards/gpu-cpu-performance.json` - GPU/CPU Performance Dashboard ⭐ **NUEVO**
- `monitoring/grafana/provisioning/dashboards/users-sessions.json` - Users & Sessions Dashboard ⭐ **NUEVO**
- `monitoring/grafana/provisioning/dashboards/cost-estimation.json` - Cost Estimation Dashboard ⭐ **NUEVO**
- `monitoring/grafana/provisioning/dashboards/ai-models-performance.json` - AI Models Performance Dashboard ⭐ **NUEVO**

**Para aplicar cambios**:
1. Edita los archivos JSON de los dashboards
2. Reinicia Grafana: `docker compose restart grafana`
3. Refresca el dashboard en Grafana

**Nota**: Los cambios se aplican automáticamente al reiniciar Grafana.

**Para agregar nuevos dashboards**:
1. Crea un archivo JSON en `monitoring/grafana/provisioning/dashboards/`
2. Asegúrate de que tenga un `uid` único
3. Reinicia Grafana para que se provisione automáticamente

---

## 📚 Referencias

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor Documentation](https://github.com/google/cadvisor)
- [node-exporter Documentation](https://github.com/prometheus/node_exporter)
- [postgres-exporter Documentation](https://github.com/prometheus-community/postgres_exporter)

---

**Última actualización**: 2025-12-07

