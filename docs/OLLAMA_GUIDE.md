# 🚀 Ollama Optimization Guide

Complete guide for optimizing, monitoring, and testing Ollama performance in this stack.

**Last updated**: 2026-01-25

---

## 📋 Table of Contents

1. [Optimization Configuration](#optimization-configuration)
2. [Monitoring Dashboard](#monitoring-dashboard)
3. [Testing and Validation](#testing-and-validation)
4. [Troubleshooting](#troubleshooting)

---

## ⚡ Optimization Configuration

### Current Optimizations

The following optimizations are configured in `docker-compose.yml`:

```yaml
environment:
  - OLLAMA_MAX_LOADED_MODELS=2      # Keep 2 models in memory
  - OLLAMA_NUM_THREAD=8             # Use 8 CPU threads
  - OLLAMA_KEEP_ALIVE=10m           # Keep models loaded for 10 minutes
shm_size: 2g                        # 2GB shared memory
deploy:
  resources:
    limits:
      cpus: '6'                     # Max 6 CPU cores
      memory: 32G                   # Max 32GB RAM
```

### What Each Optimization Does

**OLLAMA_MAX_LOADED_MODELS=2**
- Keeps up to 2 models in memory simultaneously
- **Benefit**: Second load of same model is instant
- **Trade-off**: Uses more memory

**OLLAMA_NUM_THREAD=8**
- Uses 8 CPU threads for inference
- **Benefit**: Better CPU utilization for CPU models
- **Optimal**: Adjust based on your CPU (cores × 1.5)

**OLLAMA_KEEP_ALIVE=10m**
- Keeps models loaded for 10 minutes after last use
- **Benefit**: Fast reloading if used again quickly
- **Trade-off**: Higher memory usage during idle

**shm_size=2g**
- Shared memory for inter-process communication
- **Benefit**: Faster model loading and inference
- **Required**: For models > 7B parameters

**Resource Limits**
- Prevents Ollama from consuming all system resources
- **Benefit**: System remains responsive

### How to Adjust

Edit `.env` to customize:

```bash
# In .env
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_NUM_THREAD=8
OLLAMA_KEEP_ALIVE=10m
OLLAMA_SHM_SIZE=2g
```

Then recreate container:
```bash
docker compose up -d --force-recreate ollama-gpu
```

### 🛑 Concurrency Protection (HAProxy Queue)

To prevent GPU OOM (Out of Memory) crashes when n8n or multiple users request inference simultaneously, we implemented a **Request Queue** in HAProxy.

**How it works:**
1.  **HAProxy Intercepts**: All requests to `/ollama/*` go through HAProxy (port 80).
2.  **Max Connections = 1**: We limit `ollama_back` backend to `maxconn 1`.
3.  **Queueing**: If a request comes while GPU is busy, it is **queued** (up to 100 requests) inside HAProxy.
4.  **n8n Configuration**: n8n is configured to point to `http://haproxy/ollama`, forcing it to respect the queue.

**Benefit**:
- n8n execution loops cannot crash the GPU.
- Requests simply "wait" instead of failing or causing OOM.

---

## 📊 Monitoring Dashboard

### Dashboard: Ollama Optimization Monitoring

**Location**: Grafana → Dashboards → Ollama Optimization Monitoring  
**UID**: `ollama-optimization-monitoring`  
**Refresh**: 30 seconds  
**Default time range**: Last 6 hours

### Panels Included

#### 1. Optimization Status
- **Type**: Stat
- **Metric**: `ollama_up`
- **Description**: Ollama service status with optimizations applied
- **Interpretation**: Green = Optimized and running

#### 2. Total Models Available
- **Type**: Stat
- **Metric**: `ollama_models_total`
- **Description**: Number of available models
- **Note**: `OLLAMA_MAX_LOADED_MODELS=2` allows keeping 2 models in memory

#### 3. Total Models Size
- **Type**: Stat
- **Metric**: `ollama_total_size_bytes / 1024 / 1024 / 1024`
- **Description**: Total size of all models in GB
- **Unit**: GB

#### 4. GPU Utilization Trend
- **Type**: Timeseries
- **Metric**: `DCGM_FI_DEV_GPU_UTIL`
- **Description**: GPU utilization trend over time
- **Target**: >80% utilization indicates better optimization
- **Thresholds**:
  - Green: <50%
  - Yellow: 50-90%
  - Red: >90%

#### 5. GPU Memory Usage Trend
- **Type**: Timeseries
- **Metric**: `(DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100`
- **Description**: GPU memory usage trend
- **Interpretation**: Shows efficient GPU memory usage for model cache
- **Thresholds**:
  - Green: <70%
  - Yellow: 70-95%
  - Red: >95%

#### 6. Ollama Container CPU Usage Trend
- **Type**: Timeseries
- **Metric**: `sum(rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*"}[5m])) by (id) * 100`
- **Description**: Ollama container CPU usage trend
- **Note**: `OLLAMA_NUM_THREAD=8` optimizes CPU usage
- **Thresholds**:
  - Green: <50%
  - Yellow: 50-80%
  - Red: >80%

#### 7. Ollama Container Memory Usage Trend
- **Type**: Timeseries
- **Metric**: `sum(container_memory_usage_bytes{id=~"/system.slice/docker-.*"}) by (id) / 1024 / 1024 / 1024`
- **Description**: Memory usage trend
- **Note**: `OLLAMA_MAX_LOADED_MODELS=2` keeps 2 models in memory for fast access
- **Thresholds**:
  - Green: <16GB
  - Yellow: 16-28GB
  - Red: >28GB

#### 8. Performance Improvement Indicators
- **Type**: Table
- **Metrics**: 
  - `ollama_up`
  - `ollama_models_total`
  - `DCGM_FI_DEV_GPU_UTIL`
- **Description**: Key performance indicators showing optimization status

#### 9. Model Size Distribution
- **Type**: Bar Gauge
- **Metric**: `ollama_model_size_bytes / 1024 / 1024 / 1024`
- **Description**: Model size distribution
- **Note**: Models kept in memory by `OLLAMA_MAX_LOADED_MODELS=2` are accessed faster

#### 10. GPU Temperature Trend
- **Type**: Timeseries
- **Metric**: `DCGM_FI_DEV_GPU_TEMP`
- **Description**: GPU temperature trend
- **Interpretation**: Should remain stable under optimized load
- **Thresholds**:
  - Green: <70°C
  - Yellow: 70-85°C
  - Red: >85°C

#### 11. Optimization Configuration Summary
- **Type**: Text (Markdown)
- **Content**: Summary of applied optimization configurations and expected improvements

### How to Use the Dashboard

**Immediate Verification**
1. Access Grafana: http://localhost:3001
2. Go to Dashboards → Ollama Optimization Monitoring
3. Verify all panels show data
4. Check optimization status (should be green)

**Continuous Monitoring**
1. Observe trends in GPU, CPU and Memory panels
2. Compare current metrics with historical values
3. Identify usage patterns and performance improvements
4. Verify optimizations are working as expected

### Interpreting Results

**Indicators of Working Optimizations:**
- ✅ GPU Utilization >80% during inference
- ✅ Stable GPU Memory Usage (no large fluctuations)
- ✅ Efficient CPU Usage (<80% average)
- ✅ Stable Memory Usage with models in cache
- ✅ Stable Temperature (<85°C)

**Problem Signals:**
- ⚠️ GPU Utilization <50% constantly (may indicate under-utilization)
- ⚠️ Memory Usage fluctuating a lot (cache not working)
- ⚠️ CPU Usage >80% constantly (may need adjustment)
- ⚠️ Temperature >85°C (overheating)

### Before/After Comparison

To compare metrics before and after optimizations:

1. **Change time range**: Use time selector in top right corner
2. **Compare periods**: Select "Compare" to compare with previous periods
3. **Observe trends**: Graphs show historical trends automatically

### Recommended Alerts

While dashboard shows visual alerts, you can configure automatic alerts in Grafana for:

- GPU Utilization <50% for more than 10 minutes
- Memory Usage >28GB for more than 5 minutes
- CPU Usage >80% for more than 5 minutes
- Temperature >85°C
- Ollama Status = Down

---

## 🧪 Testing and Validation

### Quick Test (Recommended)

Run quick tests script:

```bash
./scripts/test-ollama-quick.sh
```

This script verifies:
- ✅ Environment variable configuration
- ✅ Shared Memory Size
- ✅ Model load time
- ✅ Cache functionality
- ✅ Basic inference speed

### Complete Test

For more detailed testing:

```bash
./scripts/test-ollama-performance.sh
```

**Note**: This test may take several minutes as it loads large models.

### Manual Tests

#### Test 1: Verify Configuration

```bash
# Verify environment variables
docker exec ollama env | grep OLLAMA

# Verify Shared Memory Size
docker inspect ollama | grep ShmSize

# Verify available models
docker exec ollama ollama list
```

#### Test 2: Model Load Time

```bash
# Load small model (first time)
time docker exec ollama ollama run all-minilm:latest "test"

# Load same model (second time - from cache)
time docker exec ollama ollama run all-minilm:latest "test"
```

**Expected result**: Second load should be significantly faster (<1s vs 2-5s).

#### Test 3: Inference Speed

```bash
# Test with small model
time docker exec ollama ollama run all-minilm:latest "Write a 50-word story about space"

# Test with medium model (if you have GPU)
time docker exec ollama ollama run deepseek-r1:14b "Explain quantum computing in simple terms"
```

#### Test 4: Resource Usage

```bash
# Monitor resource usage during inference
docker stats ollama

# In another terminal, run inference
docker exec ollama ollama run deepseek-r1:14b "Write a long story"
```

#### Test 5: Verify Model Cache

```bash
# Load model
docker exec ollama ollama run deepseek-r1:14b "test"

# Wait 5 minutes (within KEEP_ALIVE of 10m)
sleep 300

# Load again (should be fast - from cache)
time docker exec ollama ollama run deepseek-r1:14b "test"
```

### GPU Metrics

If you have NVIDIA GPU, you can monitor usage:

```bash
# View GPU usage in real-time
watch -n 1 nvidia-smi

# View specific metrics
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
```

### Prometheus/Grafana Metrics

Optimizations can also be monitored from Grafana:

1. **Access Grafana**: http://localhost:3001
2. **Go to dashboard**: "AI Models Performance Dashboard"
3. **Verify metrics**:
   - Ollama Status (should be 1)
   - Total Models (number of available models)
   - Total Models Size (total model size)

### Success Criteria

Optimizations are working correctly if:

1. ✅ **Environment variables applied**: 
   - `OLLAMA_MAX_LOADED_MODELS=2`
   - `OLLAMA_NUM_THREAD=8`
   - `OLLAMA_KEEP_ALIVE=10m`

2. ✅ **Shared Memory Size**: 2GB (2147483648 bytes)

3. ✅ **Cache working**: 
   - Second model load is >50% faster than first

4. ✅ **Improved performance**:
   - Initial load time <5s for small models
   - Cache load time <1s
   - Stable inference speed

5. ✅ **Optimized resources**:
   - Reasonable CPU usage (<50% idle)
   - Appropriate memory usage
   - GPU used when large models loaded

---

## 🔧 Troubleshooting

### Problem: Models don't load faster

**Solution**: Verify environment variables are applied:
```bash
docker exec ollama env | grep OLLAMA_MAX_LOADED_MODELS
```

### Problem: Cache not working

**Solution**: Verify `OLLAMA_KEEP_ALIVE`:
```bash
docker exec ollama env | grep OLLAMA_KEEP_ALIVE
```

### Problem: Shared Memory Size not applied

**Solution**: Restart container:
```bash
docker compose restart ollama-gpu
```

### Problem: Poor Performance

**Possible causes and solutions**:

1. **CPU thread count too low/high**:
   - Adjust `OLLAMA_NUM_THREAD` in `.env`
   - Recommended: CPU cores × 1.5

2. **Not enough shared memory**:
   - Increase `OLLAMA_SHM_SIZE` in `.env`
   - Try 4g or 8g for very large models

3. **Resource limits too restrictive**:
   - Adjust CPU and memory limits in `docker-compose.yml`

4. **Models too large for available memory**:
   - Reduce `OLLAMA_MAX_LOADED_MODELS`
   - Use smaller quantized models

---

## 📝 Notes

- Tests may take several minutes with large models
- Times may vary depending on hardware
- Cache works best with frequently used models
- Optimizations are more noticeable with large models (>7B parameters)

---

## 🎯 Next Steps

After validating optimizations:

1. **Monitor real usage**: Use Ollama normally and observe improvements
2. **Adjust parameters**: If needed, adjust values in `.env`
3. **Continue optimizing**: Consider Redis cache or HAProxy improvements

---

## 🔗 Related Dashboards

- **AI Models Performance Dashboard**: General AI model metrics
- **GPU/CPU Performance Dashboard**: Detailed GPU and CPU performance
- **System Overview Dashboard**: General system overview

---

## 📚 References

- Optimization variables configured in `docker-compose.yml`
- Configurable values in `.env`:
  - `OLLAMA_MAX_LOADED_MODELS=2`
  - `OLLAMA_NUM_THREAD=8`
  - `OLLAMA_KEEP_ALIVE=10m`
  - `OLLAMA_SHM_SIZE=2g`

---

*Last updated: 2026-01-25*
