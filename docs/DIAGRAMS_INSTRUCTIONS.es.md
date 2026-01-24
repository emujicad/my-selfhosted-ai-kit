<!--
🌐 Idioma: Español | [English](DIAGRAMS_INSTRUCTIONS.md)
-->

> **Esta documentación está en español. La versión principal en inglés está en [DIAGRAMS_INSTRUCTIONS.md](DIAGRAMS_INSTRUCTIONS.md).**

# Instrucciones para generar diagramas PNG a partir de archivos .mmd

Todos los diagramas fuente están en la carpeta `diagrams_mmd/` y los PNG generados se guardan en `diagrams_png/`.

## 1. Instalar Mermaid CLI

Si no tienes instalado Node.js y npm, instálalos primero. Luego instala Mermaid CLI globalmente:

```bash
npm install -g @mermaid-js/mermaid-cli
```

O usa npx (no requiere instalación global):

```bash
npx -y @mermaid-js/mermaid-cli -i archivo.mmd -o archivo.png
```

## 2. Generar un PNG a partir de un archivo .mmd

Ejemplo para un solo archivo:

```bash
npx -y @mermaid-js/mermaid-cli -i diagrams_mmd/dev_stack_minimal.mmd -o diagrams_png/dev_stack_minimal.png -w 1800 -H 900 -s 2
```

## 3. Generar todos los PNG automáticamente

Puedes usar un bucle en bash para convertir todos los .mmd:

```bash
for f in diagrams_mmd/*.mmd; do 
  nombre=$(basename "$f" .mmd)
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "diagrams_png/${nombre}.png" -w 1800 -H 900 -s 2
done
```

Ajusta los parámetros `-w` (ancho), `-H` (alto) y `-s` (escala) según la calidad y tamaño que desees.

## 4. Editar o crear nuevos diagramas

- Puedes editar los archivos `.mmd` con cualquier editor de texto.
- Usa la sintaxis de Mermaid para crear tus propios diagramas.
- Puedes previsualizarlos en [Mermaid Live Editor](https://mermaid.live/).

---

**¡Así puedes mantener y personalizar todos los diagramas visuales de tu stack!** 