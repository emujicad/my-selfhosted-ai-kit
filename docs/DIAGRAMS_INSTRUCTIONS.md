<!--
🌐 Language: English | [Español](DIAGRAMS_INSTRUCTIONS.es.md)
-->

> **This documentation is in English. For Spanish, see [DIAGRAMS_INSTRUCTIONS.es.md](DIAGRAMS_INSTRUCTIONS.es.md).**

# Instructions to generate PNG diagrams from .mmd files

All source diagrams are in the `diagrams_mmd/` folder and the generated PNGs are in `diagrams_png/`.

## 1. Install Mermaid CLI

If you don't have Node.js and npm, install them first. Then install Mermaid CLI globally:

```bash
npm install -g @mermaid-js/mermaid-cli
```

Or use npx (no global install required):

```bash
npx -y @mermaid-js/mermaid-cli -i file.mmd -o file.png
```

## 2. Generate a PNG from a .mmd file

Example for a single file:

```bash
npx -y @mermaid-js/mermaid-cli -i diagrams_mmd/dev_stack_minimal.mmd -o diagrams_png/dev_stack_minimal.png -w 1800 -H 900 -s 2
```

## 3. Generate all PNGs automatically

You can use a bash loop to convert all .mmd files:

```bash
for f in diagrams_mmd/*.mmd; do 
  name=$(basename "$f" .mmd)
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "diagrams_png/${name}.png" -w 1800 -H 900 -s 2
done
```

Adjust the `-w` (width), `-H` (height), and `-s` (scale) parameters for your desired quality and size.

## 4. Edit or create new diagrams

- You can edit `.mmd` files with any text editor.
- Use Mermaid syntax to create your own diagrams.
- Preview them in [Mermaid Live Editor](https://mermaid.live/).

---

**This way you can maintain and customize all the visual diagrams of your stack!** 