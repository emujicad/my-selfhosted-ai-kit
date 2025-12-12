#!/usr/bin/env python3
"""
Open WebUI Prometheus Exporter
Expone métricas de Open WebUI en formato Prometheus
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
OPEN_WEBUI_HOST = os.getenv('OPEN_WEBUI_HOST', 'open-webui:8080')
OPEN_WEBUI_BASE_URL = f'http://{OPEN_WEBUI_HOST}'
PORT = int(os.getenv('EXPORTER_PORT', '9890'))
SCRAPE_INTERVAL = int(os.getenv('SCRAPE_INTERVAL', '15'))

# Cache para métricas
metrics_cache: Dict[str, Any] = {}
cache_timestamp = 0


def check_openwebui_health() -> bool:
    """Verifica si Open WebUI está disponible"""
    try:
        url = f'{OPEN_WEBUI_BASE_URL}/healthz'
        with urllib.request.urlopen(url, timeout=5) as response:
            return response.status == 200
    except Exception as e:
        print(f"Error checking Open WebUI health: {e}", file=sys.stderr)
        return False


def fetch_openwebui_stats() -> Dict[str, Any]:
    """Obtiene estadísticas de Open WebUI (si están disponibles)"""
    stats = {
        'users_total': 0,
        'chats_total': 0,
        'messages_total': 0,
    }
    
    # Open WebUI no expone estadísticas directamente por API pública sin autenticación
    # Estas métricas se pueden obtener consultando la base de datos
    # Por ahora, solo verificamos disponibilidad
    return stats


def scrape_metrics() -> Dict[str, Any]:
    """Recolecta todas las métricas de Open WebUI"""
    global metrics_cache, cache_timestamp
    
    # Usar cache si está fresco
    current_time = time.time()
    if current_time - cache_timestamp < SCRAPE_INTERVAL:
        return metrics_cache
    
    metrics = {
        'openwebui_up': 0,
        'openwebui_health_status': 0,
    }
    
    try:
        is_healthy = check_openwebui_health()
        metrics['openwebui_up'] = 1 if is_healthy else 0
        metrics['openwebui_health_status'] = 1 if is_healthy else 0
        
        # Intentar obtener estadísticas adicionales
        stats = fetch_openwebui_stats()
        metrics.update(stats)
        
    except Exception as e:
        print(f"Error scraping metrics: {e}", file=sys.stderr)
        metrics['openwebui_up'] = 0
        metrics['openwebui_health_status'] = 0
    
    metrics_cache = metrics
    cache_timestamp = current_time
    return metrics


def format_prometheus_metrics(metrics: Dict[str, Any]) -> str:
    """Formatea las métricas en formato Prometheus"""
    lines = []
    
    # Métricas de disponibilidad
    lines.append(f'openwebui_up {metrics["openwebui_up"]}')
    lines.append(f'openwebui_health_status {metrics["openwebui_health_status"]}')
    
    # Métricas de estadísticas (si están disponibles)
    if 'users_total' in metrics:
        lines.append(f'openwebui_users_total {metrics["users_total"]}')
    if 'chats_total' in metrics:
        lines.append(f'openwebui_chats_total {metrics["chats_total"]}')
    if 'messages_total' in metrics:
        lines.append(f'openwebui_messages_total {metrics["messages_total"]}')
    
    return '\n'.join(lines) + '\n'


class OpenWebUIExporterHandler(http.server.BaseHTTPRequestHandler):
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
    print(f"Starting Open WebUI Exporter on port {PORT}")
    print(f"Open WebUI host: {OPEN_WEBUI_HOST}")
    print(f"Scrape interval: {SCRAPE_INTERVAL}s")
    
    handler = OpenWebUIExporterHandler
    httpd = socketserver.TCPServer(("", PORT), handler)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        httpd.shutdown()


if __name__ == '__main__':
    main()

