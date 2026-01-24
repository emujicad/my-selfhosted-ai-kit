#!/bin/bash
# scripts/test-ollama-quick.sh
# Pruebas rápidas de rendimiento de Ollama

set -e

echo "🧪 PRUEBAS RÁPIDAS DE RENDIMIENTO DE OLLAMA"
echo "==========================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar que Ollama está corriendo
if ! docker ps | grep -q "ollama.*healthy"; then
    echo "❌ ERROR: Ollama no está corriendo o no está saludable"
    exit 1
fi

echo "✅ Ollama está funcionando correctamente"
echo ""

# Mostrar configuración actual
echo "═══════════════════════════════════════════════════════"
echo "CONFIGURACIÓN ACTUAL"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}Variables de entorno aplicadas:${NC}"
docker exec ollama env 2>/dev/null | grep -E "OLLAMA_(MAX_LOADED_MODELS|NUM_THREAD|KEEP_ALIVE)" | sort || echo "   (usando valores por defecto)"
echo ""

echo -e "${BLUE}Shared Memory Size:${NC}"
shm_size=$(docker inspect ollama 2>/dev/null | grep -i "ShmSize" | awk '{print $2}' | tr -d ',')
if [ -n "$shm_size" ]; then
    shm_gb=$(echo "scale=2; $shm_size / 1024 / 1024 / 1024" | bc)
    echo "   ShmSize: ${shm_size} bytes (${shm_gb} GB)"
else
    echo "   No disponible"
fi
echo ""

echo -e "${BLUE}Modelos disponibles:${NC}"
docker exec ollama ollama list 2>/dev/null | head -6
echo ""

echo -e "${BLUE}Uso de recursos actual:${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "NAME|ollama"
echo ""

# Prueba 1: Verificar que Ollama responde
echo "═══════════════════════════════════════════════════════"
echo "PRUEBA 1: Verificar respuesta de Ollama"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}Probando conexión con Ollama...${NC}"
if docker exec ollama ollama list > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ollama responde correctamente${NC}"
else
    echo -e "${YELLOW}⚠️  Ollama no responde${NC}"
    exit 1
fi
echo ""

# Prueba 2: Tiempo de carga de modelo pequeño
echo "═══════════════════════════════════════════════════════"
echo "PRUEBA 2: Tiempo de carga de modelo (all-minilm)"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}Cargando modelo all-minilm:latest...${NC}"
start_time=$(date +%s.%N)
docker exec ollama ollama run all-minilm:latest "test" > /dev/null 2>&1
end_time=$(date +%s.%N)

load_time=$(echo "$end_time - $start_time" | bc -l)
echo -e "${GREEN}⏱️  Tiempo de carga: ${load_time}s${NC}"
echo ""

# Prueba 3: Verificar que el modelo está en memoria (cache)
echo "═══════════════════════════════════════════════════════"
echo "PRUEBA 3: Verificar cache de modelos"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}Probando segunda carga (debería ser más rápida)...${NC}"
start_time=$(date +%s.%N)
docker exec ollama ollama run all-minilm:latest "test" > /dev/null 2>&1
end_time=$(date +%s.%N)

cached_time=$(echo "$end_time - $start_time" | bc -l)
echo -e "${GREEN}⏱️  Tiempo de carga desde cache: ${cached_time}s${NC}"

if (( $(echo "$cached_time < $load_time" | bc -l) )); then
    improvement=$(echo "scale=1; (($load_time - $cached_time) / $load_time) * 100" | bc -l)
    echo -e "${GREEN}✅ Mejora: ${improvement}% más rápido${NC}"
else
    echo -e "${YELLOW}⚠️  El tiempo es similar (puede ser que el modelo ya estaba cargado)${NC}"
fi
echo ""

# Prueba 4: Velocidad de inferencia simple
echo "═══════════════════════════════════════════════════════"
echo "PRUEBA 4: Velocidad de inferencia básica"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}Generando respuesta corta con all-minilm...${NC}"
start_time=$(date +%s.%N)
response=$(docker exec ollama ollama run all-minilm:latest "Say hello in 5 words" 2>/dev/null | head -1)
end_time=$(date +%s.%N)

inference_time=$(echo "$end_time - $start_time" | bc -l)
echo -e "${GREEN}⏱️  Tiempo de inferencia: ${inference_time}s${NC}"
echo -e "${GREEN}📝 Respuesta: ${response}${NC}"
echo ""

# Resumen final
echo "═══════════════════════════════════════════════════════"
echo "RESUMEN DE PRUEBAS"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${GREEN}✅ Todas las pruebas completadas${NC}"
echo ""
echo "📊 Métricas obtenidas:"
echo "   • Tiempo de carga inicial: ${load_time}s"
echo "   • Tiempo de carga desde cache: ${cached_time}s"
echo "   • Tiempo de inferencia: ${inference_time}s"
echo ""
echo "💡 Interpretación:"
echo "   • Si cached_time < load_time: El cache funciona correctamente ✅"
echo "   • Tiempos < 2s: Excelente rendimiento"
echo "   • Tiempos 2-5s: Buen rendimiento"
echo "   • Tiempos > 5s: Puede necesitar optimización"
echo ""

