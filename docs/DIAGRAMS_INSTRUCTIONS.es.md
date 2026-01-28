<!--
🌐 Idioma: Español | [English](DIAGRAMS_INSTRUCTIONS.md)
-->

> **Esta documentación está en español. La versión principal en inglés está en [DIAGRAMS_INSTRUCTIONS.md](DIAGRAMS_INSTRUCTIONS.md).**

# Instrucciones para Generar Diagramas PNG desde Archivos .mmd

Todos los diagramas fuente están en la carpeta `../diagrams_mmd/` y los PNGs generados en `../diagrams_png/`.

## Diagramas Actuales

**Diagramas Profesionales Nuevos (2026-01-28):**
- `architecture_complete.mmd` - Arquitectura completa del sistema con todos los servicios
- `oidc_authentication_flow.mmd` - Diagrama de secuencia de autenticación OIDC detallado
- `profile_dependencies.mmd` - Diagrama de resolución automática de dependencias del stack-manager
- `perfiles.mmd` - Ecosistema completo de perfiles y relaciones

**Diagramas Heredados:**
- Otros archivos .mmd en diagrams_mmd/ (pueden necesitar actualizaciones)

## Opciones para Generar PNGs

### Opción 1: Editor en Línea de Mermaid (Recomendado - Más Fácil)

1. Ir a https://mermaid.live/
2. Copiar el contenido del archivo `.mmd`
3. Pegar en el editor
4. Ajustar el zoom/tamaño si es necesario
5. Click en "Actions" → "Export as PNG" o "Export as SVG"
6. Guardar en `diagrams_png/`

### Opción 2: Mermaid CLI (Requiere Chrome/Chromium)

#### Configuración Inicial:
```bash
# Instalar mermaid-cli globalmente
npm install -g @mermaid-js/mermaid-cli

# Instalar Chrome headless para Puppeteer
npx puppeteer browsers install chrome-headless-shell
```

#### Generar PNGs:
```bash
cd diagrams_mmd

# Encontrar y establecer la ruta del navegador (requerido para puppeteer)
export PUPPETEER_EXECUTABLE_PATH=$(find ~/.cache/puppeteer/chrome-headless-shell -name "chrome-headless-shell" -type f 2>/dev/null | head -1)

# Verificar que se encontró
echo "Usando Chrome: $PUPPETEER_EXECUTABLE_PATH"

# Generar un diagrama específico
npx -y @mermaid-js/mermaid-cli -i architecture_complete.mmd -o ../diagrams_png/architecture_complete.png -w 2400 -H 1800 -s 2

# Generar todos los diagramas
for f in *.mmd; do
  name=$(basename "$f" .mmd)
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "../diagrams_png/${name}.png" -w 2400 -H 1800 -s 2
done
```

> **Nota**: Si obtienes error "Could not find Chrome", ejecuta primero `npx puppeteer browsers install chrome-headless-shell`.

### Opción 3: Extensión de VS Code

1. Instalar extensión "Markdown Preview Mermaid Support"
2. Abrir archivo `.mmd`
3. Vista previa (Ctrl+Shift+V)
4. Capturar pantalla o exportar

### Opción 4: Contenedor Docker (Automatizado)

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
- **Escala**: 2 (para salida nítida)
- **Formato**: PNG (mejor compatibilidad) o SVG (vectorial, escalable)
- **Fondo**: Transparente o blanco

## Editar o Crear Nuevos Diagramas

- Puedes editar archivos `.mmd` con cualquier editor de texto.
- Usa sintaxis Mermaid para crear tus propios diagramas.
- Previsualízalos en [Editor en Línea de Mermaid](https://mermaid.live/).
- Ver [Documentación de Mermaid](https://mermaid.js.org/) para referencia de sintaxis.

**Consejos de Estilo:**
- Usa `%%{init: {...}}%%` para personalización de tema
- Codifica por colores según categoría para mayor claridad
- Agrega íconos emoji para identificación visual
- Mantén los diagramas enfocados y no demasiado complejos

---

**¡De esta manera puedes mantener y personalizar todos los diagramas visuales de tu stack!**