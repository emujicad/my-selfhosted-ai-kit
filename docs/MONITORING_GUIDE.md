# 📊 Monitoring and Observability Guide

Complete guide for monitoring the entire stack with Prometheus, Grafana, exporters, and alerting.

**Last updated**: 2026-01-25

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Monitoring Services](#monitoring-services)
3. [Grafana Dashboards](#grafana-dashboards)
4. [Configuration](#configuration)
5. [Troubleshooting](#troubleshooting)
6. [Available Metrics](#available-metrics)
7. [Next Steps](#next-steps)

---

## 📊 Overview

The stack includes a complete monitoring system based on Prometheus and Grafana that allows visualizing state and performance of all services.

### Monitoring Components

- **Prometheus**: Metrics collector
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert management
- **node-exporter**: Operating system metrics
- **cAdvisor**: Docker container metrics
- **postgres-exporter**: PostgreSQL metrics
- **redis-exporter**: Redis cache metrics
- **qdrant-metrics**: Vector database metrics (native)
- **nvidia-exporter**: NVIDIA GPU metrics
- **ollama-exporter**: Ollama-specific metrics
- **n8n-exporter**: n8n workflow metrics
- **openwebui-exporter**: Open WebUI metrics

---

## 🔧 Monitoring Services

### Prometheus

**Port**: `9090`  
**URL**: http://localhost:9090

**Function**: Collects and stores metrics from all services.

**Configuration**:
- Configuration file: `monitoring/prometheus.yml`
- Alert rules: `monitoring/ prometheus/alerts.yml`
- Custom rules: Volume `prometheus_rules_data`

**Collected metrics**:
- System metrics (node-exporter)
- Container metrics (cAdvisor)
- PostgreSQL metrics (postgres-exporter)
- Service metrics (Ollama, n8n, Open WebUI, etc.)
- GPU metrics (nvidia-exporter)

### Grafana

**Port**: `3001`  
**URL**: http://localhost:3001

**Function**: Metric visualization via interactive dashboards.

**Authentication**: Integrated with Keycloak (see [`KEYCLOAK_GUIDE.md`](KEYCLOAK_GUIDE.md))

**Configuration**:
- Configuration file: `monitoring/grafana/config/grafana.ini`
- Datasources: `monitoring/grafana/provisioning/datasources/`
- Dashboards: `monitoring/grafana/provisioning/dashboards/`

### node-exporter

**Port**: `9100`

**Function**: Exposes host operating system metrics.

**Included metrics**:
- CPU usage
- Memory usage
- Disk I/O
- Network traffic
- Load average

### cAdvisor

**Port**: `8082`

**Function**: Exposes Docker container metrics.

**Included metrics**:
- CPU usage per container
- Memory usage per container
- Network traffic per container
- Container start time
- Container status

**Important note**: cAdvisor exposes metrics with label `id` in `/system.slice/docker-<hash>.scope` format, not with container names directly.

### postgres-exporter

**Port**: `9187`

**Function**: Exposes PostgreSQL metrics.

**Included metrics**:
- Active connections
- Queries per second
- Database size
- Replication status

**Current status**: ⚠️ Has connection problems (see [Troubleshooting](#troubleshooting))

### redis-exporter

**Port**: `9121`

**Function**: Exposes Redis metrics.

**Included metrics**:
- Connected clients
- Memory usage
- Commands processed
- Cache hit/miss ratio

**Note**: Requires `infrastructure` profile (Redis must be running).

### qdrant-metrics

**Port**: `6333` (native Prometheus endpoint)

**Function**: Exposes Qdrant vector database metrics.

**Included metrics**:
- Collections count
- Points count per collection
- Search latency
- Memory usage

**Note**: Qdrant exposes metrics natively at `/metrics` endpoint.

### nvidia-exporter

**Port**: `9400`

**Function**: Exposes NVIDIA GPU metrics using DCGM.

**Included metrics**:
- GPU utilization (%)
- GPU memory usage
- GPU temperature
- GPU power consumption

**Note**: Only applies if you have NVIDIA GPU.

### ollama-exporter

**Port**: `9888`

**Function**: Exposes Ollama-specific metrics via API.

**Included metrics**:
- `ollama_up`: Ollama service status
- `ollama_models_total`: Number of available models
- `ollama_total_size_bytes`: Total size of all models
- `ollama_model_size_bytes{model="..."}`: Size per individual model

**Source**: `scripts/utils/exporters/ollama-exporter.py`

### Custom Python Exporters

The stack includes custom Python exporters located in `scripts/utils/exporters/`:

| Exporter | Port | Function |
|----------|------|----------|
| `ollama-exporter.py` | 9888 | Ollama model metrics (size, count, status) |
| `n8n-exporter.py` | 9889 | n8n workflow metrics (executions, status) |
| `openwebui-exporter.py` | 9890 | Open WebUI metrics (users, chats, models) |

These exporters query the respective service APIs and expose metrics in Prometheus format.

---

## 📈 Grafana Dashboards

### System Overview Dashboard

**Location**: Grafana → Dashboards → System Overview Dashboard  
**UID**: `system-overview`

**Included panels**:
- **System CPU Usage**: System CPU usage
- **System Memory Usage**: System memory usage
- **Disk Usage**: Disk usage by device
- **Network Traffic**: Network traffic by interface
- **Disk I/O**: Disk I/O by device
- **Container CPU Usage**: Docker container CPU usage
- **Container Memory Usage**: Docker container memory usage
- **PostgreSQL Status**: PostgreSQL connections status
- **Container Status Overview**: Table with container information
- **System Load Average**: System load average

### Ollama AI Models Dashboard

**Location**: Grafana → Dashboards → Ollama AI Models Dashboard  
**UID**: `ollama-dashboard`

**Included panels**:
- **Container Status Overview**: Summary of active containers
- **Ollama Container CPU Usage**: Container CPU usage
- **Ollama Container Memory Usage**: Container memory usage
- **Ollama Container Network Traffic**: Docker network traffic
- **System CPU Usage**: System CPU usage
- **System Memory Usage**: System memory usage
- **Container Status Table**: Table with container start times
- **Container Uptime**: Container uptime

### GPU/CPU Performance Dashboard ⭐ **UPDATED**

**Location**: Grafana → Dashboards → GPU/CPU Performance Dashboard  
**UID**: `gpu-cpu-performance`

**Included panels**:
- **GPU Usage**: GPU usage with real NVIDIA metrics
- **GPU Memory Usage**: GPU memory (used/total)
- **GPU Temperature**: GPU temperature in real-time
- **GPU Power Usage**: GPU power consumption in Watts
- **Ollama Container CPU Usage**: Ollama-specific CPU usage
- **Ollama Container Memory Usage**: Ollama memory usage in GB
- **CPU Usage by Service**: CPU usage breakdown by service (bar chart)
- **System Load Average**: System load average (1m, 5m, 15m)
- **Memory Usage by Service**: Memory usage breakdown by service (bar chart)
- **Total System Memory Usage**: Total system memory usage

**Features**:
- Real GPU metrics (not estimates)
- GPU/CPU specific metrics for AI models
- Clear resource visualization by service
- Visual alerts with thresholds (green/yellow/red)

### Users & Sessions Dashboard ⭐ **NEW**

**Location**: Grafana → Dashboards → Users & Sessions Dashboard  
**UID**: `users-sessions`

**Included panels**:
- **PostgreSQL Active Connections**: Active connections by database
- **Total PostgreSQL Connections**: Total active connections
- **PostgreSQL Transactions**: Commit and rollback rates
- **Active Connections Over Time**: Active connections over time
- **Keycloak Container Status**: Keycloak container status
- **Keycloak Container CPU**: Keycloak CPU usage
- **Grafana Container Status**: Grafana container status
- **Grafana Container CPU**: Grafana CPU usage
- **PostgreSQL Cache Hit Ratio**: Cache hit ratio (target: >95%)
- **Service Container Status**: Table with all service container status

### Cost Estimation Dashboard ⭐ **NEW**

**Location**: Grafana → Dashboards → Cost Estimation Dashboard  
**UID**: `cost-estimation`

**Included panels**:
- **Estimated Hourly Cost (CPU)**: Estimated hourly cost based on CPU ($0.10/CPU-hr)
- **Estimated Hourly Cost (Memory)**: Estimated hourly cost based on memory ($0.05/GB-hr)
- **Total Estimated Hourly Cost**: Total hourly cost (CPU + Memory)
- **Cost Over Time**: Cost breakdown over time
- **Cost by Service**: Cost per service (bar chart)
- **Estimated Daily Cost**: Estimated daily cost
- **Estimated Monthly Cost**: Estimated monthly cost
- **Resource Usage Summary**: Resource usage summary table by service

**Note**: Prices are estimates and can be adjusted according to your infrastructure.

### AI Models Performance Dashboard ⭐ **UPDATED**

**Location**: Grafana → Dashboards → AI Models Performance Dashboard  
**UID**: `ai-models-performance`

**Included panels**:
- **Ollama Container Status**: Ollama container status
- **Ollama Status**: Real Ollama service status
- **Total Models**: Number of models available
- **Total Models Size**: Total size in GB
- **Model Sizes**: Bar chart per model
- **Ollama CPU Usage**: Ollama CPU usage
- **Ollama Memory Usage**: Ollama memory usage
- **Ollama Network I/O**: Ollama network I/O
- **Estimated Throughput (Requests/Hour)**: Estimated throughput based on CPU activity
- **Estimated Latency (ms)**: Estimated latency based on CPU activity
- **Open WebUI Container Status**: Open WebUI container status
- **Open WebUI CPU Usage**: Open WebUI CPU usage (indicates user activity)
- **AI Services Summary**: AI services summary table

**Features**:
- Real Ollama metrics (not estimates for status and models)
- AI model-specific performance metrics
- Throughput and latency estimates
- User activity monitoring (Open WebUI)
- Model load indicators (memory)

### Executive Summary Dashboard ⭐ **NEW**

**Location**: Grafana → Dashboards → Executive Summary  
**UID**: `executive-summary`

**Description**: Executive dashboard with main system KPIs.

**Included panels**:
- **System Uptime**: System uptime
- **CPU Usage**: Real-time CPU usage
- **Memory Usage**: Real-time memory usage
- **Disk Usage**: System disk usage
- **GPU Utilization**: GPU utilization (if available)
- **Ollama Status**: Ollama service status
- **Ollama Models**: Number of available models
- **Active Containers**: Number of active containers
- **Resource Usage Trends (24h)**: CPU, memory and GPU trends
- **Service Status Overview**: Monitoring services status table
- **Estimated Daily Cost**: Estimated daily cost
- **Network I/O (24h)**: Network traffic

**Features**:
- Auto-refresh every 30 seconds
- Dark theme by default
- Layout optimized for large screens
- 24-hour trend graphs

### Ollama Optimization Monitoring ⭐ **NEW**

**Location**: Grafana → Dashboards → Ollama Optimization Monitoring  
**UID**: `ollama-optimization-monitoring`

**Description**: Complete dashboard for tracking Ollama optimization improvements over time.

See [`OLLAMA_GUIDE.md`](OLLAMA_GUIDE.md) for details.

---

## ⚙️ Configuration

### Start Monitoring Services

```bash
# Start all monitoring services
docker compose --profile monitoring up -d

# Or start specific services
docker compose --profile monitoring up -d prometheus grafana node-exporter cadvisor postgres-exporter nvidia-exporter ollama-exporter
```

### Verify Service Status

```bash
# View monitoring service status
docker compose --profile monitoring ps

# View specific service logs
docker compose logs prometheus
docker compose logs grafana
docker compose logs node-exporter
docker compose logs cadvisor
docker compose logs postgres-exporter  
docker compose logs nvidia-exporter
docker compose logs ollama-exporter
```

### Access Grafana

1. Open http://localhost:3001
2. Sign in with Keycloak (see [`KEYCLOAK_GUIDE.md`](KEYCLOAK_GUIDE.md))
3. Navigate to Dashboards → Select a dashboard
4. Refresh dashboard (Refresh button) to see updated data

---

## 🔍 Troubleshooting

### Problem: Dashboards show "No data"

**Possible causes**:
1. Exporters are not running
2. Prometheus is not scraping metrics
3. Time range is incorrect

**Solution**:

```bash
# 1. Verify exporters are running
docker compose --profile monitoring ps node-exporter cadvisor postgres-exporter nvidia-exporter ollama-exporter

# 2. If not running, start them
docker compose --profile monitoring up -d node-exporter cadvisor postgres-exporter nvidia-exporter ollama-exporter

# 3. Verify Prometheus is scraping
# Open http://localhost:9090/targets
# You should see exporters as "UP"

# 4. In Grafana:
# - Change time range to "Last 5 minutes" or "Last 15 minutes"
# - Refresh dashboard
# - Wait 1-2 minutes for historical metrics to accumulate
```

### Problem: Container Status Table shows 0 values

**Cause**: Query used `container_tasks_state` which counts tasks, not container status.

**Solution**: Already fixed. Dashboard now uses `container_start_time_seconds` showing when containers started.

### Problem: Network Traffic shows no data

**Cause**: Network metrics are not available per individual container in cAdvisor.

**Solution**: Already fixed. Dashboard now shows Docker interface traffic (`br-*`) which is what's available.

### Problem: PostgreSQL Status shows "Exporter Not Connected"

**Cause**: postgres-exporter cannot connect to PostgreSQL due to authentication problems.

**Current status**: ⚠️ Known issue. Exporter has authentication problems with PostgreSQL.

**Temporary solution**: Dashboard shows "Exporter Not Connected" instead of just "0", which is more informative.

**To completely resolve**:
1. Verify password in `.env` matches PostgreSQL's
2. Verify postgres-exporter is in same network as postgres (`genai-network`)
3. Verify PostgreSQL authentication configuration (`pg_hba.conf`)

### Problem: Panels show container IDs instead of names

**Cause**: cAdvisor exposes metrics with label `id` in `/system.slice/docker-<hash>.scope` format, not with container names.

**Solution**: This is normal and expected. IDs are the real identifiers cAdvisor uses.

**Note**: If you need container names, you can:
1. Use `docker ps` to map IDs to names
2. Or create transformations in Grafana to map IDs to names

### Problem: Prometheus shows targets as "DOWN"

**Solution**:

```bash
# 1. Verify services are running
docker compose ps

# 2. Verify network connectivity
docker compose exec prometheus ping -c 1 cadvisor
docker compose exec prometheus ping -c 1 node-exporter

# 3. Verify Prometheus configuration
docker compose exec prometheus cat /etc/prometheus/prometheus.yml

# 4. Reload Prometheus configuration
curl -X POST http://localhost:9090/-/reload
```

### Problem: Keycloak Metrics Missing

**Cause**: Prometheus configuration points to port 9000, but Keycloak uses 8080.

**Status**: ⚠️ Known Issue.

**Workaround**: Update `prometheus.yml` to use port 8080 for the Keycloak job.


---

## 📊 Available Metrics

### System Metrics (node-exporter)

- `node_cpu_seconds_total`: CPU time by mode
- `node_memory_MemTotal_bytes`: Total memory
- `node_memory_MemAvailable_bytes`: Available memory
- `node_disk_read_bytes_total`: Bytes read from disk
- `node_disk_written_bytes_total`: Bytes written to disk
- `node_network_receive_bytes_total`: Bytes received by interface
- `node_network_transmit_bytes_total`: Bytes transmitted by interface
- `node_load1`, `node_load5`, `node_load15`: System load average

### Container Metrics (cAdvisor)

- `container_cpu_usage_seconds_total`: CPU usage by container
- `container_memory_usage_bytes`: Memory usage by container
- `container_network_receive_bytes_total`: Bytes received by container
- `container_network_transmit_bytes_total`: Bytes transmitted by container
- `container_start_time_seconds`: Container start time
- `container_tasks_state`: Container task status

**Note**: All container metrics use label `id` with format `/system.slice/docker-<hash>.scope`.

### PostgreSQL Metrics (postgres-exporter)

- `pg_up`: Connection status (1 = connected, 0 = disconnected)
- `pg_stat_database_numbackends`: Active connections by database
- `pg_stat_database_xact_commit`: Committed transactions
- `pg_stat_database_xact_rollback`: Rolled back transactions
- `pg_stat_database_blks_read`: Blocks read
- `pg_stat_database_blks_hit`: Blocks found in cache

**Status**: ⚠️ Currently unavailable due to exporter connection problems.

### GPU Metrics (nvidia-exporter)

- `DCGM_FI_DEV_GPU_UTIL`: GPU utilization %
- `DCGM_FI_DEV_FB_USED`: Used GPU memory
- `DCGM_FI_DEV_FB_FREE`: Free GPU memory
- `DCGM_FI_DEV_GPU_TEMP`: GPU temperature
- `DCGM_FI_DEV_POWER_USAGE`: GPU power usage

**Note**: Only available if you have NVIDIA GPU.

### Ollama Metrics (ollama-exporter)

- `ollama_up`: Ollama service status (1 = up, 0 = down)
- `ollama_models_total`: Total number of available models
- `ollama_total_size_bytes`: Total size of all models
- `ollama_model_size_bytes{model="..."}`: Size per individual model

---

## 🎯 Next Steps

### 🔥 High Priority

#### 1. Grafana Alerts ⭐ **RECOMMENDED FIRST**

**Status**: Prometheus alerts configured, Grafana integration pending

**Tasks**:
- [ ] Configure Grafana Alerting for visual alerts in dashboards
- [ ] Create alerts based on specific panels:
  - CPU usage >80% for more than 5 minutes
  - Memory usage >85% for more than 5 minutes
  - Services down (Ollama, Keycloak, PostgreSQL)
  - Disk full (<15% available)
  - GPU temperature >85°C
- [ ] Configure notifications:
  - Email (SMTP)
  - Slack/Discord (webhooks) - optional
  - Custom webhooks
- [ ] Create active alerts dashboard in Grafana
- [ ] Configure alert silencing

**Benefit**: Alerts visible directly in Grafana, better user experience

**Resources**:
- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)
- Configuration file: `monitoring/grafana/config/grafana.ini`

**Estimated time**: 2-3 hours

#### 2. Improve AlertManager

**Status**: AlertManager configured, notification configuration pending

> ⚠️ **Note**: The current `monitoring/alertmanager.yml` contains a placeholder webhook (`http://127.0.0.1:5001/`) that doesn't exist. This must be configured with a real endpoint for alerts to be delivered.

**Tasks**:
- [ ] Review current configuration: `monitoring/alertmanager.yml`
- [ ] Configure email notifications:
  - SMTP server
  - Credentials
  - Email templates
- [ ] Configure Slack/Discord integration (optional):
  - Webhook URL
  - Message templates
- [ ] Configure alert groups:
  - Group related alerts
  - Configure wait times
- [ ] Configure silencing:
  - Silence alerts during maintenance
  - Silence known alerts
- [ ] Create alerts dashboard in Grafana:
  - Active alerts
  - Alert history
  - Alert statistics

**Benefit**: Automatic notifications when problems occur

**Resources**:
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- Configuration file: `monitoring/alertmanager.yml`

**Estimated time**: 2-3 hours

### ⚡ Medium Priority

#### 3. Centralized Logging

**Status**: Logs scattered in Docker containers

**Tasks**:
- [ ] Choose logging solution:
  - **Option A**: Loki (recommended, integrates with Grafana)
  - **Option B**: ELK Stack (Elasticsearch, Logstash, Kibana)
- [ ] Configure Loki (if chosen):
  - Add Loki service to `docker-compose.yml`
  - Configure Promtail to collect container logs
  - Configure Loki datasource in Grafana
- [ ] Configure Docker logging driver:
  - Configure `logging` in `docker-compose.yml` to send logs to Loki
- [ ] Create log dashboards in Grafana:
  - Errors by service
  - Usage patterns
  - Ollama logs (requests, errors)
  - Keycloak logs (authentications, errors)
- [ ] Configure log-based alerts:
  - Repeated critical errors
  - Suspicious patterns
  - Mass authentication failures
- [ ] Configure rotation and retention:
  - Retention policy (e.g., 30 days)
  - Old log compression

**Benefit**: Centralized log search and analysis, better troubleshooting

**Resources**:
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)

**Estimated time**: 4-5 hours

#### 4. Additional Service Metrics

**Status**: Basic metrics configured

**Tasks**:
- [ ] Add n8n metrics:
  - Workflows executed per hour
  - Failed workflows
  - Average execution time
  - Memory usage per workflow
- [ ] Add Open WebUI metrics:
  - Active users
  - Messages per hour
  - Most used models
  - Average response time
- [ ] Add Qdrant metrics:
  - Active collections
  - Indexed vectors
  - Collection size
  - Queries per second
- [ ] Add Redis metrics (if implemented):
  - Cache hit ratio
  - Memory used
  - Commands per second
- [ ] Create specific dashboards for each service

**Benefit**: Complete stack visibility

**Estimated time**: 3-4 hours per service

---

## 🔄 Dashboard Updates

Dashboards are automatically provisioned from:
- `monitoring/grafana/provisioning/dashboards/system-overview.json`
- `monitoring/grafana/provisioning/dashboards/ollama-dashboard.json`
- `monitoring/grafana/provisioning/dashboards/gpu-cpu-performance.json`
- `monitoring/grafana/provisioning/dashboards/users-sessions.json`
- `monitoring/grafana/provisioning/dashboards/cost-estimation.json`
- `monitoring/grafana/provisioning/dashboards/ai-models-performance.json`
- `monitoring/grafana/provisioning/dashboards/executive-summary.json`
- `monitoring/grafana/provisioning/dashboards/ollama-optimization-monitoring.json`

**To apply changes**:
1. Edit dashboard JSON files
2. Restart Grafana: `docker compose restart grafana`
3. Refresh dashboard in Grafana

**Note**: Changes apply automatically when restarting Grafana.

**To add new dashboards**:
1. Create JSON file in `monitoring/grafana/provisioning/dashboards/`
2. Ensure it has a unique `uid`
3. Restart Grafana to provision automatically

---

## 📚 References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor Documentation](https://github.com/google/cadvisor)
- [node-exporter Documentation](https://github.com/prometheus/node_exporter)
- [postgres-exporter Documentation](https://github.com/prometheus-community/postgres_exporter)
- [NVIDIA DCGM Exporter Documentation](https://github.com/NVIDIA/dcgm-exporter)

---

*Last updated: 2026-01-24*
