#!/bin/bash
# scripts/test-ollama-advanced.sh
# Pruebas avanzadas de optimizaciones de Ollama

set -e

echo "🧪 PRUEBAS AVANZADAS DE OPTIMIZACIONES DE OLLAMA"
echo "=================================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar que Ollama está corriendo
if ! docker ps | grep -q "ollama.*healthy"; then
    echo -e "${RED}❌ ERROR: Ollama no está corriendo o no está saludable${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ollama está funcionando correctamente${NC}"
echo ""

# Función para mostrar uso de recursos
show_resources() {
    echo -e "${BLUE}📊 Uso de recursos:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "NAME|ollama"
    echo ""
}

# PRUEBA 1: Verificar OLLAMA_KEEP_ALIVE
test_keep_alive() {
    echo "═══════════════════════════════════════════════════════"
    echo "PRUEBA 1: OLLAMA_KEEP_ALIVE (10 minutos)"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${BLUE}Cargando modelo y verificando que se mantiene en memoria...${NC}"
    
    # Cargar modelo
    docker exec ollama ollama run all-minilm:latest "test" > /dev/null 2>&1
    echo "   ✅ Modelo cargado"
    
    # Verificar memoria inicial
    mem_before=$(docker stats --no-stream --format "{{.MemUsage}}" ollama | awk '{print $1}')
    echo "   Memoria antes: ${mem_before}"
    
    # Esperar 30 segundos (dentro del KEEP_ALIVE de 10m)
    echo "   Esperando 30 segundos..."
    sleep 30
    
    # Cargar de nuevo (debería ser rápido - desde cache)
    start_time=$(date +%s.%N)
    docker exec ollama ollama run all-minilm:latest "test" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    cached_time=$(echo "$end_time - $start_time" | bc -l)
    
    mem_after=$(docker stats --no-stream --format "{{.MemUsage}}" ollama | awk '{print $1}')
    echo "   Memoria después: ${mem_after}"
    echo "   Tiempo de carga desde cache: ${cached_time}s"
    
    if (( $(echo "$cached_time < 1.0" | bc -l) )); then
        echo -e "${GREEN}   ✅ KEEP_ALIVE funcionando (carga rápida desde cache)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  KEEP_ALIVE puede no estar funcionando correctamente${NC}"
    fi
    echo ""
}

# PRUEBA 2: Verificar OLLAMA_MAX_LOADED_MODELS=2
test_max_loaded_models() {
    echo "═══════════════════════════════════════════════════════"
    echo "PRUEBA 2: OLLAMA_MAX_LOADED_MODELS=2"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${BLUE}Cargando 2 modelos diferentes y verificando que ambos están en memoria...${NC}"
    
    # Cargar primer modelo
    echo "   Cargando modelo 1 (all-minilm)..."
    docker exec ollama ollama run all-minilm:latest "test" > /dev/null 2>&1
    mem_after_1=$(docker stats --no-stream --format "{{.MemUsage}}" ollama | awk '{print $1}')
    echo "   Memoria después del modelo 1: ${mem_after_1}"
    
    # Cargar segundo modelo
    echo "   Cargando modelo 2 (deepseek-r1:14b)..."
    docker exec ollama ollama run deepseek-r1:14b "test" > /dev/null 2>&1
    mem_after_2=$(docker stats --no-stream --format "{{.MemUsage}}" ollama | awk '{print $1}')
    echo "   Memoria después del modelo 2: ${mem_after_2}"
    
    # Verificar que ambos modelos están accesibles rápidamente
    echo "   Verificando acceso rápido a ambos modelos..."
    
    start_time=$(date +%s.%N)
    docker exec ollama ollama run all-minilm:latest "test" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    time_1=$(echo "$end_time - $start_time" | bc -l)
    
    start_time=$(date +%s.%N)
    docker exec ollama ollama run deepseek-r1:14b "test" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    time_2=$(echo "$end_time - $start_time" | bc -l)
    
    echo "   Tiempo acceso modelo 1: ${time_1}s"
    echo "   Tiempo acceso modelo 2: ${time_2}s"
    
    if (( $(echo "$time_1 < 1.0 && $time_2 < 1.0" | bc -l) )); then
        echo -e "${GREEN}   ✅ MAX_LOADED_MODELS=2 funcionando (ambos modelos en memoria)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Puede que no ambos modelos estén en memoria${NC}"
    fi
    echo ""
}

# PRUEBA 3: Prueba de carga/stress
test_stress() {
    echo "═══════════════════════════════════════════════════════"
    echo "PRUEBA 3: Prueba de carga (múltiples requests)"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${BLUE}Enviando 5 requests simultáneos...${NC}"
    
    start_time=$(date +%s.%N)
    
    # Enviar 5 requests en paralelo
    for i in {1..5}; do
        docker exec ollama ollama run all-minilm:latest "Say hello $i" > /dev/null 2>&1 &
    done
    
    # Esperar a que todos terminen
    wait
    
    end_time=$(date +%s.%N)
    total_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo "   Tiempo total para 5 requests: ${total_time}s"
    echo "   Tiempo promedio por request: $(echo "scale=2; $total_time / 5" | bc)s"
    
    show_resources
    
    echo -e "${GREEN}   ✅ Prueba de carga completada${NC}"
    echo ""
}

# PRUEBA 4: Prueba de inferencia con prompts largos
test_long_prompts() {
    echo "═══════════════════════════════════════════════════════"
    echo "PRUEBA 4: Inferencia con prompts largos"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    long_prompt="Write a detailed story about a space mission to Mars. Include descriptions of the spacecraft, the crew, the challenges they face, and their successful landing. Make it at least 200 words."
    
    echo -e "${BLUE}Generando respuesta con prompt largo...${NC}"
    
    start_time=$(date +%s.%N)
    response=$(docker exec ollama ollama run deepseek-r1:14b "$long_prompt" 2>/dev/null)
    end_time=$(date +%s.%N)
    
    inference_time=$(echo "$end_time - $start_time" | bc -l)
    word_count=$(echo "$response" | wc -w)
    
    echo "   Tiempo de inferencia: ${inference_time}s"
    echo "   Palabras generadas: ${word_count}"
    
    if [ "$word_count" -gt 0 ]; then
        wps=$(echo "scale=2; $word_count / $inference_time" | bc -l)
        echo "   Velocidad: ${wps} palabras/segundo"
    fi
    
    show_resources
    
    echo -e "${GREEN}   ✅ Inferencia con prompt largo completada${NC}"
    echo ""
}

# PRUEBA 5: Prueba de uso de recursos con diferentes modelos
test_resource_usage() {
    echo "═══════════════════════════════════════════════════════"
    echo "PRUEBA 5: Uso de recursos con diferentes modelos"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${BLUE}Probando uso de recursos con diferentes modelos...${NC}"
    
    models=("all-minilm:latest" "deepseek-r1:14b")
    
    for model in "${models[@]}"; do
        echo "   Probando modelo: ${model}"
        
        # Memoria antes
        mem_before=$(docker stats --no-stream --format "{{.MemUsage}}" ollama | awk '{print $1}')
        
        # Cargar modelo
        docker exec ollama ollama run "$model" "test" > /dev/null 2>&1
        
        # Memoria después
        mem_after=$(docker stats --no-stream --format "{{.MemUsage}}" ollama | awk '{print $1}')
        
        echo "     Memoria antes: ${mem_before}"
        echo "     Memoria después: ${mem_after}"
        echo ""
    done
    
    show_resources
    
    echo -e "${GREEN}   ✅ Prueba de recursos completada${NC}"
    echo ""
}

# PRUEBA 6: Prueba de concurrencia
test_concurrency() {
    echo "═══════════════════════════════════════════════════════"
    echo "PRUEBA 6: Concurrencia (requests simultáneos)"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${BLUE}Enviando 3 requests simultáneos con diferentes modelos...${NC}"
    
    start_time=$(date +%s.%N)
    
    # Request 1
    docker exec ollama ollama run all-minilm:latest "Request 1" > /dev/null 2>&1 &
    pid1=$!
    
    # Request 2 (mismo modelo)
    docker exec ollama ollama run all-minilm:latest "Request 2" > /dev/null 2>&1 &
    pid2=$!
    
    # Request 3 (modelo diferente)
    docker exec ollama ollama run deepseek-r1:14b "Request 3" > /dev/null 2>&1 &
    pid3=$!
    
    # Esperar a que todos terminen
    wait $pid1 $pid2 $pid3
    
    end_time=$(date +%s.%N)
    total_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo "   Tiempo total para 3 requests simultáneos: ${total_time}s"
    echo "   Tiempo promedio: $(echo "scale=2; $total_time / 3" | bc)s"
    
    show_resources
    
    echo -e "${GREEN}   ✅ Prueba de concurrencia completada${NC}"
    echo ""
}

# Ejecutar todas las pruebas
main() {
    test_keep_alive
    test_max_loaded_models
    test_stress
    test_long_prompts
    test_resource_usage
    test_concurrency
    
    echo "═══════════════════════════════════════════════════════"
    echo "✅ TODAS LAS PRUEBAS COMPLETADAS"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "💡 Interpretación de resultados:"
    echo "   • KEEP_ALIVE: Debería mantener modelos en memoria"
    echo "   • MAX_LOADED_MODELS: Debería mantener 2 modelos simultáneos"
    echo "   • Stress: Debería manejar múltiples requests eficientemente"
    echo "   • Prompts largos: Debería generar respuestas completas"
    echo "   • Recursos: Debería usar memoria apropiadamente"
    echo "   • Concurrencia: Debería manejar requests simultáneos"
    echo ""
}

main

