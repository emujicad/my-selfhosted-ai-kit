#!/usr/bin/env python3
"""
n8n Prometheus Exporter
Expone métricas de n8n en formato Prometheus
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
N8N_HOST = os.getenv('N8N_HOST', 'n8n:5678')
N8N_BASE_URL = f'http://{N8N_HOST}'
PORT = int(os.getenv('EXPORTER_PORT', '9889'))
SCRAPE_INTERVAL = int(os.getenv('SCRAPE_INTERVAL', '15'))

# Cache para métricas
metrics_cache: Dict[str, Any] = {}
cache_timestamp = 0


def check_n8n_health() -> bool:
    """Verifica si n8n está disponible"""
    try:
        url = f'{N8N_BASE_URL}/healthz'
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode())
            return data.get('status') == 'ok'
    except Exception as e:
        print(f"Error checking n8n health: {e}", file=sys.stderr)
        return False


def fetch_n8n_stats() -> Dict[str, Any]:
    """Obtiene estadísticas de n8n (si están disponibles)"""
    stats = {
        'workflows_total': 0,
        'executions_total': 0,
        'executions_success': 0,
        'executions_error': 0,
    }
    
    # n8n no expone estadísticas directamente por API pública
    # Estas métricas se pueden obtener consultando la base de datos PostgreSQL
    # Por ahora, solo verificamos disponibilidad
    return stats


def scrape_metrics() -> Dict[str, Any]:
    """Recolecta todas las métricas de n8n"""
    global metrics_cache, cache_timestamp
    
    # Usar cache si está fresco
    current_time = time.time()
    if current_time - cache_timestamp < SCRAPE_INTERVAL:
        return metrics_cache
    
    metrics = {
        'n8n_up': 0,
        'n8n_health_status': 0,
    }
    
    try:
        is_healthy = check_n8n_health()
        metrics['n8n_up'] = 1 if is_healthy else 0
        metrics['n8n_health_status'] = 1 if is_healthy else 0
        
        # Intentar obtener estadísticas adicionales
        stats = fetch_n8n_stats()
        metrics.update(stats)
        
    except Exception as e:
        print(f"Error scraping metrics: {e}", file=sys.stderr)
        metrics['n8n_up'] = 0
        metrics['n8n_health_status'] = 0
    
    metrics_cache = metrics
    cache_timestamp = current_time
    return metrics


def format_prometheus_metrics(metrics: Dict[str, Any]) -> str:
    """Formatea las métricas en formato Prometheus"""
    lines = []
    
    # Métricas de disponibilidad
    lines.append(f'n8n_up {metrics["n8n_up"]}')
    lines.append(f'n8n_health_status {metrics["n8n_health_status"]}')
    
    # Métricas de estadísticas (si están disponibles)
    if 'workflows_total' in metrics:
        lines.append(f'n8n_workflows_total {metrics["workflows_total"]}')
    if 'executions_total' in metrics:
        lines.append(f'n8n_executions_total {metrics["executions_total"]}')
    if 'executions_success' in metrics:
        lines.append(f'n8n_executions_success {metrics["executions_success"]}')
    if 'executions_error' in metrics:
        lines.append(f'n8n_executions_error {metrics["executions_error"]}')
    
    return '\n'.join(lines) + '\n'


class N8nExporterHandler(http.server.BaseHTTPRequestHandler):
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
    print(f"Starting n8n Exporter on port {PORT}")
    print(f"n8n host: {N8N_HOST}")
    print(f"Scrape interval: {SCRAPE_INTERVAL}s")
    
    handler = N8nExporterHandler
    httpd = socketserver.TCPServer(("", PORT), handler)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        httpd.shutdown()


if __name__ == '__main__':
    main()

