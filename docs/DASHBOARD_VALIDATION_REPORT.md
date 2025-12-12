# 📊 Reporte de Validación de Dashboards de Grafana

**Fecha**: 2025-12-12  
**Objetivo**: Validar que los nombres de paneles y unidades sean correctos y consistentes con las métricas que representan

---

## 📋 Resumen Ejecutivo

### ✅ Dashboards Sin Problemas (3)
- ✅ **gpu-cpu-performance.json** - Todas las unidades y títulos correctos
- ✅ **cost-estimation.json** - Todas las unidades y títulos correctos
- ✅ **executive-summary.json** - Todas las unidades y títulos correctos

### ⚠️ Dashboards Con Problemas (4)
- ⚠️ **system-overview.json** - 3 problemas de unidades
- ⚠️ **ollama-dashboard.json** - 2 problemas (1 unidad + 1 título ambiguo)
- ⚠️ **users-sessions.json** - 4 problemas de títulos incorrectos
- ⚠️ **ai-models-performance.json** - 8 problemas (7 títulos incorrectos + 1 unidad genérica)

### 📈 Estadísticas
- **Total de problemas encontrados**: 17
- **Problemas de unidades**: 6
- **Problemas de títulos**: 11

---

## ❌ PROBLEMAS DETALLADOS

### 1. Problemas de Unidades (6 casos)

#### **system-overview.json**

**Panel 4: "Network Traffic"**
- **Problema**: `"unit": "bytes"` pero la expresión divide por 1024 (KB/s)
- **Corrección**: Cambiar a `"unit": "kbytes"` o `"unit": "KB/s"`

**Panel 5: "Disk I/O"**
- **Problema**: `"unit": "bytes"` pero la expresión divide por 1024 (KB/s)
- **Corrección**: Cambiar a `"unit": "kbytes"` o `"unit": "KB/s"`

**Panel 7: "Container Memory Usage"**
- **Problema**: `"unit": "bytes"` pero la expresión divide por 1024/1024 (MB)
- **Corrección**: Cambiar a `"unit": "mbytes"`

#### **ollama-dashboard.json**

**Panel 3: "Ollama Container Memory Usage"**
- **Problema**: `"unit": "bytes"` pero la expresión divide por 1024/1024 (MB)
- **Corrección**: Cambiar a `"unit": "mbytes"`

**Panel 4: "Ollama Container Network Traffic"**
- **Problema**: `"unit": "bytes"` pero la expresión divide por 1024 (KB/s)
- **Corrección**: Cambiar a `"unit": "kbytes"` o `"unit": "KB/s"`

#### **ai-models-performance.json**

**Panel 7: "Estimated Throughput (Requests/Hour)"**
- **Problema**: `"unit": "short"` es genérico, aunque el título es claro
- **Corrección**: Mantener "short" está bien, pero el título ya es descriptivo

---

### 2. Problemas de Títulos (11 casos)

#### **users-sessions.json**

**Panel 5: "Keycloak Container Status"**
- **Problema**: El título dice "Keycloak" pero la expresión cuenta TODOS los contenedores
- **Expresión**: `count(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}) > 0`
- **Corrección**: Cambiar título a `"Container Status (All Docker Containers)"`

**Panel 6: "Keycloak Container CPU"**
- **Problema**: El título dice "Keycloak" pero la expresión muestra TODOS los contenedores
- **Expresión**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) by (id) * 100`
- **Corrección**: Cambiar título a `"Container CPU Usage (All Docker Containers)"`

**Panel 7: "Grafana Container Status"**
- **Problema**: El título dice "Grafana" pero la expresión cuenta TODOS los contenedores
- **Expresión**: `count(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}) > 0`
- **Corrección**: Cambiar título a `"Container Status (All Docker Containers)"`

**Panel 8: "Grafana Container CPU"**
- **Problema**: El título dice "Grafana" pero la expresión muestra TODOS los contenedores
- **Expresión**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) by (id) * 100`
- **Corrección**: Cambiar título a `"Container CPU Usage (All Docker Containers)"`

#### **ai-models-performance.json**

**Panel 2: "Ollama CPU Usage"**
- **Problema**: El título dice "Ollama" pero la expresión suma TODOS los contenedores
- **Expresión**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) * 100`
- **Corrección**: Cambiar título a `"Total Container CPU Usage"`

**Panel 3: "Ollama Memory Usage"**
- **Problema**: El título dice "Ollama" pero la expresión suma TODOS los contenedores
- **Expresión**: `sum(container_memory_usage_bytes{id=~"/system.slice/docker-.*"}) / 1024 / 1024 / 1024`
- **Corrección**: Cambiar título a `"Total Container Memory Usage"`

**Panel 4: "Ollama Network I/O"**
- **Problema**: El título dice "Ollama" pero muestra tráfico agregado de TODOS los contenedores
- **Expresión**: `sum(rate(container_network_receive_bytes_total{id="/",interface=~"br-.*"}[5m])) / 1024`
- **Corrección**: Cambiar título a `"Network I/O (All Docker Containers)"`

**Panel 5: "Ollama CPU Usage Over Time"**
- **Problema**: El título dice "Ollama" pero muestra TODOS los contenedores
- **Expresión**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) by (id) * 100`
- **Corrección**: Cambiar título a `"Container CPU Usage Over Time (All Docker Containers)"`

**Panel 6: "Ollama Memory Usage Over Time"**
- **Problema**: El título dice "Ollama" pero muestra TODOS los contenedores
- **Expresión**: `sum(container_memory_usage_bytes{id=~"/system.slice/docker-.*"}) by (id) / 1024 / 1024 / 1024`
- **Corrección**: Cambiar título a `"Container Memory Usage Over Time (All Docker Containers)"`

**Panel 9: "Open WebUI Container Status"**
- **Problema**: El título dice "Open WebUI" pero cuenta TODOS los contenedores
- **Expresión**: `count(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"})`
- **Corrección**: Cambiar título a `"Container Status (All Docker Containers)"`

**Panel 10: "Open WebUI CPU Usage"**
- **Problema**: El título dice "Open WebUI" pero muestra TODOS los contenedores
- **Expresión**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) by (id) * 100`
- **Corrección**: Cambiar título a `"Container CPU Usage (All Docker Containers)"`

**Panel 11: "Open WebUI Memory Usage"**
- **Problema**: El título dice "Open WebUI" pero muestra TODOS los contenedores
- **Expresión**: `sum(container_memory_usage_bytes{id=~"/system.slice/docker-.*"}) by (id) / 1024 / 1024`
- **Corrección**: Cambiar título a `"Container Memory Usage (All Docker Containers)"`

---

## 🔧 GUÍA DE CORRECCIÓN

### Corrección de Unidades

**Regla general**: La unidad debe coincidir con el resultado de la expresión después de las divisiones.

| Expresión divide por | Unidad correcta |
|---------------------|-----------------|
| Sin división (bytes) | `"bytes"` |
| `/ 1024` (KB) | `"kbytes"` o `"KB/s"` |
| `/ 1024 / 1024` (MB) | `"mbytes"` |
| `/ 1024 / 1024 / 1024` (GB) | `"decgbytes"` |

### Corrección de Títulos

**Problema común**: Los títulos mencionan servicios específicos (Ollama, Keycloak, Grafana, Open WebUI) pero las expresiones muestran TODOS los contenedores.

**Solución recomendada**: 
1. **Opción A (Recomendada)**: Cambiar títulos para reflejar que muestran todos los contenedores
   - Ejemplo: `"Ollama CPU Usage"` → `"Container CPU Usage (All Docker Containers)"`

2. **Opción B**: Implementar filtrado específico por contenedor (más complejo)
   - Requiere identificar el hash del contenedor específico
   - Usar filtro: `{id="/system.slice/docker-<hash>.scope"}`
   - **Limitación**: cAdvisor no expone nombres de contenedores directamente, solo IDs

### Ejemplo de Corrección Completa

**Antes**:
```json
{
  "title": "Ollama CPU Usage",
  "targets": [{
    "expr": "sum(rate(container_cpu_usage_seconds_total{id=~\"/system.slice/docker-.*\"}[5m])) * 100"
  }],
  "fieldConfig": {
    "defaults": {
      "unit": "percent"
    }
  }
}
```

**Después**:
```json
{
  "title": "Total Container CPU Usage",
  "targets": [{
    "expr": "sum(rate(container_cpu_usage_seconds_total{id=~\"/system.slice/docker-.*\"}[5m])) * 100"
  }],
  "fieldConfig": {
    "defaults": {
      "unit": "percent"
    }
  }
}
```

---

## 📝 CHECKLIST DE CORRECCIÓN

### Unidades a Corregir (6)
- [ ] `system-overview.json` Panel 4: `"unit": "bytes"` → `"unit": "kbytes"`
- [ ] `system-overview.json` Panel 5: `"unit": "bytes"` → `"unit": "kbytes"`
- [ ] `system-overview.json` Panel 7: `"unit": "bytes"` → `"unit": "mbytes"`
- [ ] `ollama-dashboard.json` Panel 3: `"unit": "bytes"` → `"unit": "mbytes"`
- [ ] `ollama-dashboard.json` Panel 4: `"unit": "bytes"` → `"unit": "kbytes"`
- [ ] `ai-models-performance.json` Panel 7: `"unit": "short"` → (opcional, mantener está bien)

### Títulos a Corregir (11)
- [ ] `users-sessions.json` Panel 5: `"Keycloak Container Status"` → `"Container Status (All Docker Containers)"`
- [ ] `users-sessions.json` Panel 6: `"Keycloak Container CPU"` → `"Container CPU Usage (All Docker Containers)"`
- [ ] `users-sessions.json` Panel 7: `"Grafana Container Status"` → `"Container Status (All Docker Containers)"`
- [ ] `users-sessions.json` Panel 8: `"Grafana Container CPU"` → `"Container CPU Usage (All Docker Containers)"`
- [ ] `ai-models-performance.json` Panel 2: `"Ollama CPU Usage"` → `"Total Container CPU Usage"`
- [ ] `ai-models-performance.json` Panel 3: `"Ollama Memory Usage"` → `"Total Container Memory Usage"`
- [ ] `ai-models-performance.json` Panel 4: `"Ollama Network I/O"` → `"Network I/O (All Docker Containers)"`
- [ ] `ai-models-performance.json` Panel 5: `"Ollama CPU Usage Over Time"` → `"Container CPU Usage Over Time (All Docker Containers)"`
- [ ] `ai-models-performance.json` Panel 6: `"Ollama Memory Usage Over Time"` → `"Container Memory Usage Over Time (All Docker Containers)"`
- [ ] `ai-models-performance.json` Panel 9: `"Open WebUI Container Status"` → `"Container Status (All Docker Containers)"`
- [ ] `ai-models-performance.json` Panel 10: `"Open WebUI CPU Usage"` → `"Container CPU Usage (All Docker Containers)"`
- [ ] `ai-models-performance.json` Panel 11: `"Open WebUI Memory Usage"` → `"Container Memory Usage (All Docker Containers)"`

---

## 💡 NOTAS IMPORTANTES

### Sobre el Filtrado por Contenedor Específico

**Limitación técnica**: cAdvisor expone métricas usando IDs de contenedor (`/system.slice/docker-<hash>.scope`), no nombres de contenedores directamente.

**Para filtrar por servicio específico**:
1. Identificar el hash del contenedor específico consultando Prometheus o cAdvisor directamente
2. Usar el hash en la expresión: `{id="/system.slice/docker-<hash>.scope"}`
3. **Problema**: El hash cambia cuando se recrea el contenedor, por lo que no es una solución permanente

**Alternativa**: Usar labels si están disponibles, pero cAdvisor no expone nombres de contenedores directamente en las métricas.

**Recomendación**: Cambiar los títulos para reflejar que muestran todos los contenedores es la solución más práctica y mantenible.

---

## ✅ VALIDACIÓN POST-CORRECCIÓN

Después de aplicar las correcciones, verificar:

1. ✅ Todas las unidades coinciden con el resultado de la expresión
2. ✅ Todos los títulos reflejan correctamente qué métricas muestran
3. ✅ Las descripciones de los paneles son consistentes con los títulos
4. ✅ Los valores mostrados en Grafana tienen sentido con las unidades configuradas

---

---

## ✅ CORRECCIONES APLICADAS

**Fecha de corrección**: 2025-12-12

### Resumen de Correcciones Aplicadas

**Total de correcciones**: 17

#### Unidades Corregidas (6):
- ✅ `system-overview.json` Panel 4: `"bytes"` → `"kbytes"`
- ✅ `system-overview.json` Panel 5: `"bytes"` → `"kbytes"`
- ✅ `system-overview.json` Panel 7: `"bytes"` → `"mbytes"`
- ✅ `ollama-dashboard.json` Panel 3: `"bytes"` → `"mbytes"`
- ✅ `ollama-dashboard.json` Panel 4: `"bytes"` → `"kbytes"`

#### Títulos Corregidos (11):
- ✅ `ollama-dashboard.json` Panel 3: `"Ollama Container Memory Usage"` → `"Container Memory Usage (All Docker Containers)"`
- ✅ `ollama-dashboard.json` Panel 4: `"Ollama Container Network Traffic"` → `"Container Network Traffic (All Docker Containers)"`
- ✅ `users-sessions.json` Panel 5: `"Keycloak Container Status"` → `"Container Status (All Docker Containers)"`
- ✅ `users-sessions.json` Panel 6: `"Keycloak Container CPU"` → `"Container CPU Usage (All Docker Containers)"`
- ✅ `users-sessions.json` Panel 7: `"Grafana Container Status"` → `"Container Status (All Docker Containers)"`
- ✅ `users-sessions.json` Panel 8: `"Grafana Container CPU"` → `"Container CPU Usage (All Docker Containers)"`
- ✅ `ai-models-performance.json` Panel 2: `"Ollama CPU Usage"` → `"Total Container CPU Usage"`
- ✅ `ai-models-performance.json` Panel 3: `"Ollama Memory Usage"` → `"Total Container Memory Usage"`
- ✅ `ai-models-performance.json` Panel 4: `"Ollama Network I/O"` → `"Network I/O (All Docker Containers)"`
- ✅ `ai-models-performance.json` Panel 5: `"Ollama CPU Usage Over Time"` → `"Container CPU Usage Over Time (All Docker Containers)"`
- ✅ `ai-models-performance.json` Panel 6: `"Ollama Memory Usage Over Time"` → `"Container Memory Usage Over Time (All Docker Containers)"`
- ✅ `ai-models-performance.json` Panel 9: `"Open WebUI Container Status"` → `"Container Status (All Docker Containers)"`
- ✅ `ai-models-performance.json` Panel 10: `"Open WebUI CPU Usage"` → `"Container CPU Usage (All Docker Containers)"`
- ✅ `ai-models-performance.json` Panel 11: `"Open WebUI Memory Usage"` → `"Container Memory Usage (All Docker Containers)"`

### Estado Final

- ✅ **Todos los problemas identificados han sido corregidos**
- ✅ **JSON válido en todos los dashboards**
- ✅ **Unidades ahora coinciden con las expresiones**
- ✅ **Títulos ahora reflejan correctamente las métricas mostradas**

**Próximo paso**: Reiniciar Grafana para aplicar los cambios:
```bash
docker compose --profile monitoring restart grafana
```

---

**Última actualización**: 2025-12-12 (Correcciones aplicadas)

