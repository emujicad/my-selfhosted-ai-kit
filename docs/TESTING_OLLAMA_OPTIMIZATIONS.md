# 🧪 Guía de Pruebas para Optimizaciones de Ollama

Esta guía describe cómo probar y validar las optimizaciones aplicadas a Ollama.

## 📋 Pruebas Disponibles

### 1. Prueba Rápida (Recomendada)

Ejecuta el script de pruebas rápidas:

```bash
./scripts/test-ollama-quick.sh
```

Este script verifica:
- ✅ Configuración de variables de entorno
- ✅ Shared Memory Size
- ✅ Tiempo de carga de modelos
- ✅ Funcionamiento del cache
- ✅ Velocidad de inferencia básica

### 2. Prueba Completa

Para pruebas más detalladas:

```bash
./scripts/test-ollama-performance.sh
```

**Nota**: Esta prueba puede tardar varios minutos ya que carga modelos grandes.

## 🔍 Pruebas Manuales

### Prueba 1: Verificar Configuración

```bash
# Verificar variables de entorno
docker exec ollama env | grep OLLAMA

# Verificar Shared Memory Size
docker inspect ollama | grep ShmSize

# Verificar modelos disponibles
docker exec ollama ollama list
```

### Prueba 2: Tiempo de Carga de Modelos

```bash
# Cargar modelo pequeño (primera vez)
time docker exec ollama ollama run all-minilm:latest "test"

# Cargar el mismo modelo (segunda vez - desde cache)
time docker exec ollama ollama run all-minilm:latest "test"
```

**Resultado esperado**: La segunda carga debería ser significativamente más rápida (< 1s vs 2-5s).

### Prueba 3: Velocidad de Inferencia

```bash
# Probar con modelo pequeño
time docker exec ollama ollama run all-minilm:latest "Write a 50-word story about space"

# Probar con modelo mediano (si tienes GPU)
time docker exec ollama ollama run deepseek-r1:14b "Explain quantum computing in simple terms"
```

### Prueba 4: Uso de Recursos

```bash
# Monitorear uso de recursos durante inferencia
docker stats ollama

# En otra terminal, ejecutar inferencia
docker exec ollama ollama run deepseek-r1:14b "Write a long story"
```

### Prueba 5: Verificar Cache de Modelos

```bash
# Cargar modelo
docker exec ollama ollama run deepseek-r1:14b "test"

# Esperar 5 minutos (dentro del KEEP_ALIVE de 10m)
sleep 300

# Cargar de nuevo (debería ser rápido - desde cache)
time docker exec ollama ollama run deepseek-r1:14b "test"
```

## 📊 Métricas de GPU

Si tienes GPU NVIDIA, puedes monitorear el uso:

```bash
# Ver uso de GPU en tiempo real
watch -n 1 nvidia-smi

# Ver métricas específicas
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
```

## 📈 Métricas de Prometheus/Grafana

Las optimizaciones también se pueden monitorear desde Grafana:

1. **Accede a Grafana**: http://localhost:3000
2. **Ve al dashboard**: "AI Models Performance Dashboard"
3. **Verifica métricas**:
   - Ollama Status (debería ser 1)
   - Total Models (número de modelos disponibles)
   - Total Models Size (tamaño total de modelos)

## ✅ Criterios de Éxito

Las optimizaciones están funcionando correctamente si:

1. ✅ **Variables de entorno aplicadas**: 
   - `OLLAMA_MAX_LOADED_MODELS=2`
   - `OLLAMA_NUM_THREAD=8`
   - `OLLAMA_KEEP_ALIVE=10m`

2. ✅ **Shared Memory Size**: 2GB (2147483648 bytes)

3. ✅ **Cache funcionando**: 
   - Segunda carga de modelo es > 50% más rápida que la primera

4. ✅ **Rendimiento mejorado**:
   - Tiempo de carga inicial < 5s para modelos pequeños
   - Tiempo de carga desde cache < 1s
   - Velocidad de inferencia estable

5. ✅ **Recursos optimizados**:
   - Uso de CPU razonable (< 50% en idle)
   - Uso de memoria apropiado
   - GPU utilizada cuando hay modelos grandes cargados

## 🔧 Solución de Problemas

### Problema: Modelos no se cargan más rápido

**Solución**: Verifica que las variables de entorno estén aplicadas:
```bash
docker exec ollama env | grep OLLAMA_MAX_LOADED_MODELS
```

### Problema: Cache no funciona

**Solución**: Verifica `OLLAMA_KEEP_ALIVE`:
```bash
docker exec ollama env | grep OLLAMA_KEEP_ALIVE
```

### Problema: Shared Memory Size no aplicado

**Solución**: Reinicia el contenedor:
```bash
docker compose restart ollama-gpu
```

## 📝 Notas

- Las pruebas pueden tardar varios minutos con modelos grandes
- Los tiempos pueden variar según el hardware
- El cache funciona mejor con modelos que se usan frecuentemente
- Las optimizaciones son más notables con modelos grandes (> 7B parámetros)

## 🎯 Próximos Pasos

Después de validar las optimizaciones:

1. **Monitorear uso real**: Usa Ollama normalmente y observa las mejoras
2. **Ajustar parámetros**: Si es necesario, ajusta valores en `.env`
3. **Continuar optimizando**: Considera Redis cache o mejoras de HAProxy

