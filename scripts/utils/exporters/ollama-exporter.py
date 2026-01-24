#!/usr/bin/env python3
"""
Ollama Prometheus Exporter
Expone métricas de Ollama en formato Prometheus
"""

import os
import sys
import time
import json
import http.server
import socketserver
import urllib.request
import urllib.error
from typing import Dict, Any

# Configuración
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'ollama:11434')
OLLAMA_BASE_URL = f'http://{OLLAMA_HOST}'
PORT = int(os.getenv('EXPORTER_PORT', '9888'))
SCRAPE_INTERVAL = int(os.getenv('SCRAPE_INTERVAL', '15'))

# Cache para métricas
metrics_cache: Dict[str, Any] = {}
cache_timestamp = 0


def fetch_ollama_models() -> list:
    """Obtiene la lista de modelos disponibles en Ollama"""
    try:
        url = f'{OLLAMA_BASE_URL}/api/tags'
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            return data.get('models', [])
    except Exception as e:
        print(f"Error fetching models: {e}", file=sys.stderr)
        return []


def fetch_model_info(model_name: str) -> Dict[str, Any]:
    """Obtiene información detallada de un modelo"""
    try:
        url = f'{OLLAMA_BASE_URL}/api/show'
        data = json.dumps({'name': model_name}).encode()
        req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"Error fetching model info for {model_name}: {e}", file=sys.stderr)
        return {}


def scrape_metrics() -> Dict[str, Any]:
    """Recolecta todas las métricas de Ollama"""
    global metrics_cache, cache_timestamp
    
    # Usar cache si está fresco
    current_time = time.time()
    if current_time - cache_timestamp < SCRAPE_INTERVAL:
        return metrics_cache
    
    metrics = {
        'models_total': 0,
        'models': [],
        'total_size_bytes': 0,
        'ollama_up': 0,
    }
    
    try:
        models = fetch_ollama_models()
        metrics['models_total'] = len(models)
        metrics['ollama_up'] = 1
        
        total_size = 0
        for model in models:
            model_name = model.get('name', 'unknown')
            
            # Intentar obtener size directamente de tags (optimización)
            size_bytes = model.get('size', 0)
            
            # Si no está (versiones viejas de Ollama), intentar fallback
            if size_bytes == 0:
                model_info = fetch_model_info(model_name)
                size_bytes = model_info.get('size', 0)
                
            total_size += size_bytes
            
            metrics['models'].append({
                'name': model_name,
                'size_bytes': size_bytes,
                'modified_at': model.get('modified_at', ''),
            })
        
        metrics['total_size_bytes'] = total_size
        
    except Exception as e:
        print(f"Error scraping metrics: {e}", file=sys.stderr)
        metrics['ollama_up'] = 0
    
    metrics_cache = metrics
    cache_timestamp = current_time
    return metrics


def format_prometheus_metrics(metrics: Dict[str, Any]) -> str:
    """Formatea las métricas en formato Prometheus"""
    lines = []
    
    # Métrica de disponibilidad
    lines.append(f'ollama_up {metrics["ollama_up"]}')
    
    # Total de modelos
    lines.append(f'ollama_models_total {metrics["models_total"]}')
    
    # Tamaño total en bytes
    lines.append(f'ollama_total_size_bytes {metrics["total_size_bytes"]}')
    
    # Métricas por modelo
    for model in metrics['models']:
        name = model['name'].replace('-', '_').replace('.', '_')
        size = model['size_bytes']
        lines.append(f'ollama_model_size_bytes{{model="{model["name"]}"}} {size}')
    
    return '\n'.join(lines) + '\n'


class OllamaExporterHandler(http.server.BaseHTTPRequestHandler):
    """Handler HTTP para el exporter"""
    
    def do_GET(self):
        if self.path == '/metrics':
            metrics = scrape_metrics()
            prometheus_output = format_prometheus_metrics(metrics)
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4')
            self.end_headers()
            self.wfile.write(prometheus_output.encode())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suprimir logs de acceso
        pass


def main():
    """Función principal"""
    print(f"Starting Ollama Exporter on port {PORT}")
    print(f"Ollama host: {OLLAMA_HOST}")
    print(f"Scrape interval: {SCRAPE_INTERVAL}s")
    
    handler = OllamaExporterHandler
    httpd = socketserver.TCPServer(("", PORT), handler)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        httpd.shutdown()


if __name__ == '__main__':
    main()

