#!/bin/bash

echo "Monitoreando descargas de modelos en ollama-pull-llama..."
echo "Presiona Ctrl+C para salir en cualquier momento (el script seguirá esperando el final del contenedor)."
echo

current_model=""

# Función para procesar cada línea del log
declare -f process_log_line >/dev/null || process_log_line() {
  while IFS= read -r line; do
    if [[ "$line" == *"Descargando"* ]]; then
      current_model="${line#Descargando }"
      echo -e "\nModelo en curso: $current_model"
    elif [[ "$line" == *"pulling"* || "$line" == *"%"* ]]; then
      # Muestra el progreso junto al modelo en curso
      echo -ne "\r[$current_model] $line                "
    elif [[ "$line" == *"Falló"* || "$line" == *"correctamente"* ]]; then
      echo -e "\n$line"
    fi
  done
}

# Usar docker logs -f y procesar cada línea
sudo docker logs -f ollama-pull-llama 2>&1 | process_log_line &

LOGS_PID=$!

while [ "$(sudo docker ps -q -f name=ollama-pull-llama)" ]; do
  sleep 5
done

kill $LOGS_PID 2>/dev/null
echo

echo -e "\nModelos disponibles en ollama:"
sudo docker exec ollama ollama list 