<!--
🌐 Language: English | [Español](DIAGRAMS_INSTRUCTIONS.es.md)
-->

> **This documentation is in English. For Spanish, see [DIAGRAMS_INSTRUCTIONS.es.md](DIAGRAMS_INSTRUCTIONS.es.md).**

# Instructions to Generate PNG Diagrams from .mmd Files

All source diagrams are in the `../diagrams_mmd/` folder and the generated PNGs are in `../diagrams_png/`.

## Current Diagrams

**New Professional Diagrams (2026-01-24):**
- `architecture_complete.mmd` - Complete system architecture with all services
- `oidc_authentication_flow.mmd` - Detailed OIDC authentication sequence diagram
- `profile_dependencies.mmd` - Stack-manager auto-dependency resolution diagram
- `perfiles.mmd` - Complete profile ecosystem and relationships

**Legacy Diagrams:**
- Other .mmd files in diagrams_mmd/ (may need updates)

## Options to Generate PNGs

### Option 1: Mermaid Live Editor (Recommended - Easiest)

1. Go to https://mermaid.live/
2. Copy the content of the `.mmd` file
3. Paste in the editor
4. Adjust zoom/size if needed
5. Click "Actions" → "Export as PNG" or "Export as SVG"
6. Save to `diagrams_png/`

### Option 2: Mermaid CLI (Requires Chrome/Chromium)

#### Initial Setup:
```bash
# Install mermaid-cli globally
npm install -g @mermaid-js/mermaid-cli

# Install Chrome headless for Puppeteer
npx puppeteer browsers install chrome-headless-shell
```

#### Generate PNGs:
```bash
cd diagrams_mmd

# Find and set the browser path (required for puppeteer)
export PUPPETEER_EXECUTABLE_PATH=$(find ~/.cache/puppeteer/chrome-headless-shell -name "chrome-headless-shell" -type f 2>/dev/null | head -1)

# Verify it was found
echo "Using Chrome: $PUPPETEER_EXECUTABLE_PATH"

# Generate a specific diagram
npx -y @mermaid-js/mermaid-cli -i architecture_complete.mmd -o ../diagrams_png/architecture_complete.png -w 2400 -H 1800 -s 2

# Generate all diagrams
for f in *.mmd; do
  name=$(basename "$f" .mmd)
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "../diagrams_png/${name}.png" -w 2400 -H 1800 -s 2
done
```

> **Note**: If you get "Could not find Chrome" error, run `npx puppeteer browsers install chrome-headless-shell` first.

### Option 3: VS Code Extension

1. Install extension "Markdown Preview Mermaid Support"
2. Open `.mmd` file
3. Preview (Ctrl+Shift+V)
4. Capture screenshot or export

### Option 4: Docker Container (Automated)

```bash
# Using container with Chrome included
docker run --rm -v $(pwd):/data minlag/mermaid-cli \
  -i /data/diagrams_mmd/architecture_complete.mmd \
  -o /data/diagrams_png/architecture_complete.png \
  -w 2400 -H 1800
```

## Recommended Parameters

- **Width**: 2400px (high resolution)
- **Height**: 1800px (or automatic)
- **Scale**: 2 (for crisp output)
- **Format**: PNG (best compatibility) or SVG (vector, scalable)
- **Background**: Transparent or white

## Edit or Create New Diagrams

- You can edit `.mmd` files with any text editor.
- Use Mermaid syntax to create your own diagrams.
- Preview them in [Mermaid Live Editor](https://mermaid.live/).
- See [Mermaid Documentation](https://mermaid.js.org/) for syntax reference.

**Styling Tips:**
- Use `%%{init: {...}}%%` for theme customization
- Color-code by category for clarity
- Add emoji icons for visual identification
- Keep diagrams focused and not too complex

---

**This way you can maintain and customize all the visual diagrams of your stack!**