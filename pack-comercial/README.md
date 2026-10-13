# Pack comercial

Instalador personal de Claude Code para ingeniería de producto y gestión comercial
con visión LatAm (Perú como base; Ecuador, Colombia, Chile, México y Brasil como
expansión).

Instala:

1. Plugins oficiales de Anthropic: `document-skills`, `sales`, `marketing`,
   `product-management`, `operations`.
2. 31 skills seleccionadas de este repo, `anthropics/skills`, `marketing-skills` y
   `social-media-skills`.
3. Subagentes por nivel: `haiku-investigador`, `haiku-operario`, `sonnet-analista`.
4. Skill `mercados-latam` y reglas globales de eficiencia y delegación en
   `~/.claude/CLAUDE.md`.

## Uso

```bash
# En tu computadora (Mac, Linux o Git Bash en Windows)
curl -fsSL https://raw.githubusercontent.com/nicoschangos/claude-skills/refs/heads/claude/adoring-rubin-gavwem/pack-comercial/instalar-pack-comercial.sh | bash

# Actualizar (una vez al mes)
curl -fsSL https://raw.githubusercontent.com/nicoschangos/claude-skills/refs/heads/claude/adoring-rubin-gavwem/pack-comercial/instalar-pack-comercial.sh | bash -s -- --actualizar
```

En sesiones en la nube de Claude Code, pega la primera línea en el
**Setup script** del entorno para que cada sesión nueva arranque con el pack.

El perfil de empresa (`~/.claude/skills/mercados-latam/references/empresa.md`) se
crea vacío y nunca se sobrescribe. Este repo es público: no guardes ahí márgenes ni
datos sensibles.
