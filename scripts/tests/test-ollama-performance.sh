#!/bin/bash
# scripts/test-ollama-performance.sh
# Script para probar el rendimiento de Ollama y validar las optimizaciones

set +e

echo "🧪 PRUEBAS DE RENDIMIENTO DE OLLAMA"
echo "===================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar que Ollama está corriendo
if ! docker ps | grep -q "ollama.*healthy"; then
    echo "❌ ERROR: Ollama no está corriendo o no está saludable"
    exit 0
fi

echo "✅ Ollama está funcionando correctamente"
echo ""

# Función para medir tiempo de carga de modelo
test_model_load_time() {
    local model=$1
    echo -e "${BLUE}📦 Probando carga de modelo: ${model}${NC}"
    
    # Limpiar modelo de memoria primero (si está cargado)
    docker exec ollama ollama show "$model" > /dev/null 2>&1 || true
    
    # Medir tiempo de carga
    start_time=$(date +%s.%N)
    docker exec ollama ollama run "$model" "test" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    
    load_time=$(echo "$end_time - $start_time" | bc)
    echo -e "${GREEN}   ⏱️  Tiempo de carga: ${load_time}s${NC}"
    echo "$load_time"
}

# Función para medir velocidad de inferencia
test_inference_speed() {
    local model=$1
    local prompt="Write a short story about a robot learning to paint. Make it exactly 100 words."
    
    echo -e "${BLUE}🚀 Probando velocidad de inferencia: ${model}${NC}"
    
    # Ejecutar inferencia y medir tiempo
    start_time=$(date +%s.%N)
    response=$(docker exec ollama ollama run "$model" "$prompt" 2>/dev/null)
    end_time=$(date +%s.%N)
    
    inference_time=$(echo "$end_time - $start_time" | bc)
    word_count=$(echo "$response" | wc -w)
    
    if [ "$word_count" -gt 0 ]; then
        words_per_second=$(echo "scale=2; $word_count / $inference_time" | bc)
        echo -e "${GREEN}   ⏱️  Tiempo total: ${inference_time}s${NC}"
        echo -e "${GREEN}   📝 Palabras generadas: ${word_count}${NC}"
        echo -e "${GREEN}   🚀 Velocidad: ${words_per_second} palabras/segundo${NC}"
    else
        echo -e "${YELLOW}   ⚠️  No se generaron palabras${NC}"
    fi
    
    echo ""
}

# Función para probar modelo en cache (segunda carga)
test_cached_model_load() {
    local model=$1
    echo -e "${BLUE}💾 Probando carga desde cache: ${model}${NC}"
    
    # El modelo ya debería estar en memoria
    start_time=$(date +%s.%N)
    docker exec ollama ollama run "$model" "test" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    
    cached_load_time=$(echo "$end_time - $start_time" | bc)
    echo -e "${GREEN}   ⏱️  Tiempo de carga desde cache: ${cached_load_time}s${NC}"
    echo "$cached_load_time"
}

# Función para mostrar uso de recursos
show_resource_usage() {
    echo -e "${BLUE}📊 Uso de recursos actual:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep -E "NAME|ollama"
    echo ""
}

# Función para mostrar modelos disponibles
show_available_models() {
    echo -e "${BLUE}📋 Modelos disponibles:${NC}"
    docker exec ollama ollama list 2>/dev/null | head -10
    echo ""
}

# Función principal de pruebas
main() {
    echo "═══════════════════════════════════════════════════════"
    echo "PASO 1: Verificar estado y modelos disponibles"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    show_available_models
    show_resource_usage
    
    echo "═══════════════════════════════════════════════════════"
    echo "PASO 2: Prueba de carga de modelos (primera vez)"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    # Probar con un modelo pequeño primero
    echo "Probando con modelo pequeño (all-minilm)..."
    test_model_load_time "all-minilm:latest"
    echo ""
    
    # Probar con un modelo mediano
    echo "Probando con modelo mediano (deepseek-r1:14b)..."
    test_model_load_time "deepseek-r1:14b"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "PASO 3: Prueba de velocidad de inferencia"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    test_inference_speed "deepseek-r1:14b"
    
    echo "═══════════════════════════════════════════════════════"
    echo "PASO 4: Prueba de carga desde cache (segunda vez)"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo "El modelo debería estar en memoria (OLLAMA_KEEP_ALIVE=10m)..."
    cached_time=$(test_cached_model_load "deepseek-r1:14b")
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "PASO 5: Verificar configuración de optimizaciones"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${BLUE}Variables de entorno aplicadas:${NC}"
    docker exec ollama env 2>/dev/null | grep -E "OLLAMA_(MAX_LOADED_MODELS|NUM_THREAD|KEEP_ALIVE)" | sort
    echo ""
    
    echo -e "${BLUE}Shared Memory Size:${NC}"
    docker inspect ollama 2>/dev/null | grep -i "ShmSize" | awk '{print "   ShmSize: " $2 " bytes (" $2/1024/1024/1024 " GB)"}'
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "✅ PRUEBAS COMPLETADAS"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "💡 Interpretación de resultados:"
    echo "   • Tiempo de carga inicial: debería ser rápido (< 5s para modelos pequeños)"
    echo "   • Tiempo de carga desde cache: debería ser muy rápido (< 1s)"
    echo "   • Velocidad de inferencia: depende del modelo y GPU"
    echo "   • Si la segunda carga es mucho más rápida, el cache funciona correctamente"
    echo ""
}

# Ejecutar pruebas
main

