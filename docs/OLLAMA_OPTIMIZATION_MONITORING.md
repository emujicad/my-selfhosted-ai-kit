# 📊 Monitoreo de Optimizaciones de Ollama

**Última actualización**: 2025-12-12

## 📋 Resumen

Este documento describe el dashboard de monitoreo completo de optimizaciones de Ollama, que permite trackear mejoras de rendimiento en el tiempo y validar que las optimizaciones están funcionando correctamente.

## 🎯 Dashboard: Ollama Optimization Monitoring

**Ubicación**: Grafana → Dashboards → Ollama Optimization Monitoring  
**UID**: `ollama-optimization-monitoring`  
**Refresh**: 30 segundos  
**Rango de tiempo por defecto**: Últimas 6 horas

## 📈 Paneles Incluidos

### 1. Optimization Status
- **Tipo**: Stat
- **Métrica**: `ollama_up`
- **Descripción**: Estado del servicio Ollama con optimizaciones aplicadas
- **Interpretación**: Verde = Optimizado y funcionando

### 2. Total Models Available
- **Tipo**: Stat
- **Métrica**: `ollama_models_total`
- **Descripción**: Número de modelos disponibles
- **Nota**: `OLLAMA_MAX_LOADED_MODELS=2` permite mantener 2 modelos en memoria

### 3. Total Models Size
- **Tipo**: Stat
- **Métrica**: `ollama_total_size_bytes / 1024 / 1024 / 1024`
- **Descripción**: Tamaño total de todos los modelos en GB
- **Unidad**: GB

### 4. GPU Utilization Trend
- **Tipo**: Timeseries
- **Métrica**: `DCGM_FI_DEV_GPU_UTIL`
- **Descripción**: Tendencia de utilización de GPU a lo largo del tiempo
- **Target**: >80% utilización indica mejor optimización
- **Umbrales**:
  - Verde: <50%
  - Amarillo: 50-90%
  - Rojo: >90%

### 5. GPU Memory Usage Trend
- **Tipo**: Timeseries
- **Métrica**: `(DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100`
- **Descripción**: Tendencia de uso de memoria GPU
- **Interpretación**: Muestra uso eficiente de memoria GPU para cache de modelos
- **Umbrales**:
  - Verde: <70%
  - Amarillo: 70-95%
  - Rojo: >95%

### 6. Ollama Container CPU Usage Trend
- **Tipo**: Timeseries
- **Métrica**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) by (id) * 100`
- **Descripción**: Tendencia de uso de CPU del contenedor Ollama
- **Nota**: `OLLAMA_NUM_THREAD=8` optimiza el uso de CPU
- **Umbrales**:
  - Verde: <50%
  - Amarillo: 50-80%
  - Rojo: >80%

### 7. Ollama Container Memory Usage Trend
- **Tipo**: Timeseries
- **Métrica**: `sum(container_memory_usage_bytes{id=~"/system.slice/docker-.*"}) by (id) / 1024 / 1024 / 1024`
- **Descripción**: Tendencia de uso de memoria
- **Nota**: `OLLAMA_MAX_LOADED_MODELS=2` mantiene 2 modelos en memoria para acceso rápido
- **Umbrales**:
  - Verde: <16GB
  - Amarillo: 16-28GB
  - Rojo: >28GB

### 8. Performance Improvement Indicators
- **Tipo**: Table
- **Métricas**: 
  - `ollama_up`
  - `ollama_models_total`
  - `DCGM_FI_DEV_GPU_UTIL`
- **Descripción**: Indicadores clave de rendimiento mostrando estado de optimización

### 9. Model Size Distribution
- **Tipo**: Bar Gauge
- **Métrica**: `ollama_model_size_bytes / 1024 / 1024 / 1024`
- **Descripción**: Distribución de tamaños de modelos
- **Nota**: Los modelos mantenidos en memoria por `OLLAMA_MAX_LOADED_MODELS=2` se acceden más rápido

### 10. GPU Temperature Trend
- **Tipo**: Timeseries
- **Métrica**: `DCGM_FI_DEV_GPU_TEMP`
- **Descripción**: Tendencia de temperatura de GPU
- **Interpretación**: Debería permanecer estable bajo carga optimizada
- **Umbrales**:
  - Verde: <70°C
  - Amarillo: 70-85°C
  - Rojo: >85°C

### 11. Optimization Configuration Summary
- **Tipo**: Text (Markdown)
- **Contenido**: Resumen de configuraciones de optimización aplicadas y mejoras esperadas

## 🔍 Cómo Usar el Dashboard

### Verificación Inmediata
1. Accede a Grafana: http://localhost:3000
2. Ve a Dashboards → Ollama Optimization Monitoring
3. Verifica que todos los paneles muestran datos
4. Revisa el estado de optimización (debería estar en verde)

### Monitoreo Continuo
1. Observa las tendencias en los paneles de GPU, CPU y Memoria
2. Compara métricas actuales con valores históricos
3. Identifica patrones de uso y mejoras de rendimiento
4. Verifica que las optimizaciones están funcionando según lo esperado

### Interpretación de Resultados

#### Indicadores de Optimización Funcionando:
- ✅ GPU Utilization >80% durante inferencia
- ✅ GPU Memory Usage estable (no fluctuaciones grandes)
- ✅ CPU Usage eficiente (<80% promedio)
- ✅ Memory Usage estable con modelos en cache
- ✅ Temperature estable (<85°C)

#### Señales de Problemas:
- ⚠️ GPU Utilization <50% constantemente (puede indicar subutilización)
- ⚠️ Memory Usage fluctuando mucho (cache no funcionando)
- ⚠️ CPU Usage >80% constantemente (puede necesitar ajuste)
- ⚠️ Temperature >85°C (sobrecalentamiento)

## 📊 Comparación Antes/Después

Para comparar métricas antes y después de las optimizaciones:

1. **Cambiar rango de tiempo**: Usa el selector de tiempo en la esquina superior derecha
2. **Comparar períodos**: Selecciona "Compare" para comparar con períodos anteriores
3. **Observar tendencias**: Las gráficas muestran tendencias históricas automáticamente

## 🔔 Alertas Recomendadas

Aunque el dashboard muestra alertas visuales, puedes configurar alertas automáticas en Grafana para:

- GPU Utilization <50% por más de 10 minutos
- Memory Usage >28GB por más de 5 minutos
- CPU Usage >80% por más de 5 minutos
- Temperature >85°C
- Ollama Status = Down

## 📝 Notas Importantes

- **No se modificaron dashboards existentes**: Este es un dashboard completamente nuevo
- **Usa métricas existentes**: Todas las métricas provienen de exporters ya configurados
- **Tendencias históricas**: Las gráficas muestran tendencias automáticamente desde que se implementaron las optimizaciones
- **Comparación manual**: Para comparar antes/después, necesitarías métricas históricas previas a las optimizaciones

## 🎯 Próximos Pasos

1. **Monitorear durante 24-48 horas**: Observa las tendencias para validar mejoras
2. **Configurar alertas**: Agrega alertas automáticas para degradación de rendimiento
3. **Documentar mejoras**: Registra mejoras observadas para referencia futura
4. **Ajustar optimizaciones**: Si es necesario, ajusta valores en `.env` basado en observaciones

## 🔗 Dashboards Relacionados

- **AI Models Performance Dashboard**: Métricas generales de modelos de IA
- **GPU/CPU Performance Dashboard**: Rendimiento detallado de GPU y CPU
- **System Overview Dashboard**: Vista general del sistema

## 📚 Referencias

- Variables de optimización configuradas en `docker-compose.yml`
- Valores configurables en `.env`:
  - `OLLAMA_MAX_LOADED_MODELS=2`
  - `OLLAMA_NUM_THREAD=8`
  - `OLLAMA_KEEP_ALIVE=10m`
  - `OLLAMA_SHM_SIZE=2g`

