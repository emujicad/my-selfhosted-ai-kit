# Generación de Diagramas PNG

## Estado Actual

✅ **Diagramas Mermaid (.mmd) creados/actualizados:**
- `architecture_complete.mmd` - Arquitectura completa del sistema (NUEVO)
- `oidc_authentication_flow.mmd` - Flujo de autenticación OIDC (NUEVO)
- `profile_dependencies.mmd` - Dependencias entre perfiles (NUEVO)

## Opciones para Generar PNGs

### Opción 1: Editor Online de Mermaid (Recomendado - Más Fácil)

1. Ir a https://mermaid.live/
2. Copiar el contenido del archivo `.mmd`
3. Pegar en el editor
4. Ajustar el zoom/tamaño si es necesario
5. Click en "Actions" → "Export as PNG" o "Export as SVG"
6. Guardar en `diagrams_png/`

### Opción 2: Mermaid CLI (Requiere Chrome/Chromium)

#### Instalación Inicial:
```bash
# Instalar mermaid-cli globalmente
npm install -g @mermaid-js/mermaid-cli

# Instalar Chrome headless para Puppeteer
npx puppeteer browsers install chrome-headless-shell
```

#### Generar PNGs:
```bash
cd diagrams_mmd

# Generar un diagrama específico
mmdc -i architecture_complete.mmd -o ../diagrams_png/architecture_complete.png -w 2400 -H 1800

# Generar todos los diagramas
for file in *.mmd; do
  mmdc -i "$file" -o "../diagrams_png/${file%.mmd}.png" -w 2400 -H 1800
done
```

### Opción 3: VS Code Extension

1. Instalar extensión "Markdown Preview Mermaid Support"
2. Abrir archivo `.mmd`
3. Vista previa (Ctrl+Shift+V)
4. Capturar pantalla o exportar

### Opción 4: Script Automático (Docker)

```bash
# Usar contenedor con Chrome incluido
docker run --rm -v $(pwd):/data minlag/mermaid-cli \
  -i /data/diagrams_mmd/architecture_complete.mmd \
  -o /data/diagrams_png/architecture_complete.png \
  -w 2400 -H 1800
```

## Parámetros Recomendados

- **Ancho**: 2400px (alta resolución)
- **Alto**: 1800px (o automático)
- **Formato**: PNG (mejor compatibilidad) o SVG (vectorial, escalable)
- **Background**: Transparente o blanco

## Diagramas Creados Recientemente

### 1. architecture_complete.mmd
**Descripción**: Arquitectura completa del sistema mostrando todos los servicios actuales
**Incluye**:
- Open WebUI + Ollama (AI)
- Keycloak (Autenticación OIDC)
- Redis (Cache)
- PostgreSQL (BD)
- n8n (Automatización)
- Stack de monitoreo (Prometheus, Grafana, AlertManager)
- Todos los exporters
- HAProxy + ModSecurity

**Estilo**: Profesional con colores temáticos por categoría

### 2. oidc_authentication_flow.mmd  
**Descripción**: Diagrama de secuencia del flujo de autenticación OIDC de Open WebUI
**Muestra**:
- Problema de Split-Horizon Routing
- Solución con Fake Discovery (`oidc-config.json`)
- Solución con Fake UserInfo (`userinfo.json`)
- Mapeo de usuario en SQLite
- Flujo completo paso a paso (16 pasos)

**Estilo**: Secuencial con anotaciones de fases

### 3. profile_dependencies.mmd
**Descripción**: Sistema de resolución automática de dependencias de stack-manager.sh
**Muestra**:
- Perfiles principales (chat-ai, automation, monitoring, ci-cd)
- Perfiles de infraestructura (security, infrastructure, gpu-nvidia)
- Auto-resolución de dependencias
- Comparación antes/después

**Estilo**: Grafo con conexiones de dependencia

## Notas

- Los diagramas usan **tema personalizado** con colores profesionales
- Incluyen **iconos emoji** para mejor identificación visual
- Están **actualizados** con la arquitectura actual (2026-01-24)
- Usan **sintaxis Mermaid moderna** compatible con las últimas versiones
