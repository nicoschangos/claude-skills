#!/usr/bin/env bash
# Pack de Claude Code para ingeniería de producto + gestión comercial.
#
#   bash instalar-pack-comercial.sh               # instala todo
#   bash instalar-pack-comercial.sh --actualizar  # trae las últimas versiones (correr 1 vez al mes)
#   curl -fsSL https://raw.githubusercontent.com/nicoschangos/claude-skills/refs/heads/claude/adoring-rubin-gavwem/pack-comercial/instalar-pack-comercial.sh | bash
#
# Instala en ~/.claude (o en $CLAUDE_CONFIG_DIR si lo tienes definido):
#   1. Plugins oficiales de Anthropic (vía `claude plugin`)
#   2. Skills sueltas seleccionadas de repos públicos
#   3. Subagentes por nivel (Haiku, Sonnet) para delegar según dificultad
#   4. Skill propia mercados-latam + reglas globales de eficiencia en ~/.claude/CLAUDE.md
#
# Requisitos: git, bash y Claude Code (macOS, Linux, WSL o Git Bash en Windows).

set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"
GH_USER="${GH_USER:-nicoschangos}"   # tus forks; los originales también funcionan
UPDATE=0
[[ "${1:-}" == "--actualizar" || "${1:-}" == "--force" ]] && UPDATE=1

command -v git >/dev/null || { echo "Error: necesitas git instalado." >&2; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# 1. Plugins oficiales de Anthropic
# ─────────────────────────────────────────────────────────────────────────────
MARKETPLACES=(anthropics/skills anthropics/knowledge-work-plugins)
PLUGINS=(
  document-skills@anthropic-agent-skills       # Excel, Word, PowerPoint, PDF: catálogos, listas de precios, propuestas
  sales@knowledge-work-plugins                 # pipeline, pronóstico, objeciones, competencia, planes de cuenta
  marketing@knowledge-work-plugins             # planes de campaña, contenidos, reportes de rendimiento
  product-management@knowledge-work-plugins    # briefs competitivos, especificaciones, roadmap
  operations@knowledge-work-plugins            # evaluación de proveedores, cumplimiento, riesgos (homologaciones)
)

echo "== 1/4 Plugins de Anthropic"
if command -v claude >/dev/null; then
  for m in "${MARKETPLACES[@]}"; do
    claude plugin marketplace add "$m" >/dev/null 2>&1 || true
  done
  [[ $UPDATE -eq 1 ]] && claude plugin marketplace update >/dev/null 2>&1 || true
  installed="$(claude plugin list 2>/dev/null || true)"
  for p in "${PLUGINS[@]}"; do
    if grep -q "$p" <<<"$installed"; then
      if [[ $UPDATE -eq 1 ]]; then
        claude plugin update "$p" >/dev/null 2>&1 && echo "  ↻ $p" || echo "  ✗ $p (no se pudo actualizar)"
      else
        echo "  • $p (ya instalado)"
      fi
    else
      claude plugin install -y "$p" >/dev/null 2>&1 && echo "  ✓ $p" || echo "  ✗ $p (falló la instalación)"
    fi
  done
else
  echo "  ⚠ No encontré el comando 'claude'. Instala Claude Code y vuelve a correr el script,"
  echo "    o dentro de Claude Code usa: /plugin marketplace add anthropics/knowledge-work-plugins"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Skills sueltas (repo|ruta). Se omiten las que ya cubren los plugins de arriba.
# ─────────────────────────────────────────────────────────────────────────────
PACK=(
  # Escoger productos nuevos
  "$GH_USER/claude-skills|research-ops/skills/market-research"
  "$GH_USER/claude-skills|product-team/skills/product-strategist"
  # Proveedores, homologaciones y expedientes
  "$GH_USER/claude-skills|business-operations/skills/vendor-management"
  "$GH_USER/claude-skills|business-operations/skills/procurement-optimizer"
  "$GH_USER/claude-skills|ra-qm-team/skills/quality-documentation-manager"
  # Precios, promociones y negocios
  "$GH_USER/claude-skills|commercial/skills/pricing-strategist"
  "$GH_USER/claude-skills|commercial/skills/commercial-policy"
  "$GH_USER/claude-skills|commercial/skills/channel-economics"
  "$GH_USER/claude-skills|commercial/skills/deal-desk"
  "$GH_USER/claude-skills|commercial/skills/rfp-responder"
  # Catálogos, marca y piezas gráficas (Anthropic)
  "anthropics/skills|skills/theme-factory"
  "anthropics/skills|skills/canvas-design"
  "anthropics/skills|skills/doc-coauthoring"
  "anthropics/skills|skills/internal-comms"
  "$GH_USER/claude-skills|marketing-skill/skills/brand-guidelines"
  # Anuncios pagados
  "$GH_USER/marketing-skills|skills/google-ads-audit"
  "$GH_USER/marketing-skills|skills/meta-ads-audit"
  "$GH_USER/marketing-skills|skills/linkedin-ads-audit"
  "$GH_USER/marketing-skills|skills/wasted-spend-finder"
  "$GH_USER/marketing-skills|skills/roas-forecasting"
  "$GH_USER/marketing-skills|skills/budget-scenario-planner"
  "$GH_USER/marketing-skills|skills/ab-test-setup-and-analysis"
  "$GH_USER/marketing-skills|skills/ad-copy-variant-generator"
  "$GH_USER/marketing-skills|skills/competitor-creative-analysis"
  "$GH_USER/marketing-skills|skills/landing-page-audit"
  "$GH_USER/marketing-skills|skills/utm-tracking-generator"
  "$GH_USER/marketing-skills|skills/weekly-account-summary"
  # LinkedIn / redes
  "$GH_USER/social-media-skills|skills/voice-builder"
  "$GH_USER/social-media-skills|skills/post-writer"
  "$GH_USER/social-media-skills|skills/hook-generator"
  # Equipo
  "$GH_USER/claude-skills|productivity/meetings/skills/meetings"
)

echo "== 2/4 Skills seleccionadas"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$SKILLS_DIR"

REPOS=$(printf '%s\n' "${PACK[@]}" | cut -d'|' -f1 | sort -u)
for repo in $REPOS; do
  dir="$TMP/${repo//\//__}"
  paths=$(printf '%s\n' "${PACK[@]}" | awk -F'|' -v r="$repo" '$1==r{print $2}')
  git clone --quiet --depth 1 --filter=blob:none --sparse "https://github.com/$repo.git" "$dir"
  # shellcheck disable=SC2086
  git -C "$dir" sparse-checkout set $paths
done

ok=0; skipped=0; missing=0
for entry in "${PACK[@]}"; do
  repo="${entry%%|*}"; path="${entry#*|}"; name="$(basename "$path")"
  src="$TMP/${repo//\//__}/$path"; dest="$SKILLS_DIR/$name"
  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  ✗ $name: no encontrado en $repo/$path"; missing=$((missing+1)); continue
  fi
  if [[ -e "$dest" && $UPDATE -eq 0 ]]; then
    skipped=$((skipped+1)); continue
  fi
  rm -rf "$dest"; cp -R "$src" "$dest"; ok=$((ok+1))
done
echo "  $ok copiadas, $skipped ya existían, $missing no encontradas → $SKILLS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Subagentes por nivel de inteligencia
# ─────────────────────────────────────────────────────────────────────────────
echo "== 3/4 Subagentes por nivel"
mkdir -p "$AGENTS_DIR"

cat > "$AGENTS_DIR/haiku-investigador.md" <<'EOF'
---
name: haiku-investigador
description: Use proactively for read-only legwork - finding files, reading and summarizing long documents, PDFs, spreadsheets, datasheets or web pages, extracting specific data (prices, specs, certifications, SKUs, contacts) and comparing lists. Fast and cheap. Returns facts with their source, never decisions.
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
model: haiku
---
Eres un asistente de investigación rápido. Tu trabajo es encontrar, leer y extraer
información; no tomas decisiones de negocio.

- Responde solo con lo que se te pidió, en formato compacto (tabla o viñetas).
- Cita la fuente de cada dato (archivo y página/hoja, o URL).
- Si un dato no aparece, escribe "no encontrado"; nunca lo inventes ni lo estimes.
- No modifiques archivos. Usa Bash solo para comandos de lectura (ls, cat, grep, find, pdftotext).
EOF

cat > "$AGENTS_DIR/haiku-operario.md" <<'EOF'
---
name: haiku-operario
description: Use proactively for mechanical, well-specified edits where the instructions fully determine the result - reformatting tables, converting CSV/Excel/JSON, cleaning or merging price lists, renaming files, filling templates, translating text, applying the same change to many items. Not for pricing, strategy or anything needing judgment.
tools: Read, Write, Edit, Bash, Glob, Grep
model: haiku
---
Eres un operario preciso. Ejecutas transformaciones mecánicas exactamente como se
te indican.

- No cambies cifras, precios ni nombres salvo que la instrucción lo pida.
- Si la instrucción es ambigua o requiere criterio, detente y devuelve la duda en
  lugar de adivinar.
- Al terminar, lista los archivos que tocaste y cuántos elementos cambiaste.
EOF
cat > "$AGENTS_DIR/sonnet-analista.md" <<'EOF'
---
name: sonnet-analista
description: Use for mid-complexity work with clear success criteria - first-pass market or competitor analysis for one country or product, drafting commercial content or proposals, localizing a piece for another country, building comparison tables, spreadsheet analysis and calculations. Not for final pricing decisions or strategy calls.
tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch
model: sonnet
---
Eres un analista comercial. Recibes un encargo con objetivo, insumos y criterio de
aceptación; entrega exactamente eso.

- Empieza por la conclusión y luego el respaldo (tabla o viñetas).
- Cita la fuente y fecha de cada dato externo; marca como "estimado" lo que calcules
  y explica el supuesto en una línea.
- Si falta un insumo para cumplir el criterio de aceptación, dilo en vez de
  rellenar con supuestos no declarados.
- Las recomendaciones finales de precio, margen o estrategia son propuestas para
  revisión, no decisiones.
EOF
echo "  ✓ haiku-investigador, haiku-operario, sonnet-analista → $AGENTS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Skill propia: mercados-latam (se carga solo cuando hace falta)
# ─────────────────────────────────────────────────────────────────────────────
echo "== 4/4 Skill mercados-latam y reglas globales"
LATAM="$SKILLS_DIR/mercados-latam"
mkdir -p "$LATAM/references"
cat > "$LATAM/SKILL.md" <<'LATAM_EOF'
---
name: mercados-latam
description: Regional lens for a Peru-based electronics company expanding to Mexico, Colombia, Chile, Ecuador, Brazil and nearby markets. Use when sizing markets, choosing products or countries, setting prices or promotions, planning ad campaigns or sales plans, writing commercial content, or checking homologation/certification across Latin American countries.
---

# Mercados LatAm

Perú es la base. Cada análisis comercial, de precios o de contenido evalúa también
los mercados de expansión, salvo que el usuario limite el alcance a un país.

Antes de empezar, lee el perfil de la empresa: `memoria/empresa.md` del
repositorio `comercial` si está en la sesión (y sigue su `CLAUDE.md`); si no,
`references/empresa.md`. Rubros, márgenes objetivo y países activos mandan sobre
los valores por defecto de abajo.

## Países y prioridad por defecto

| Nivel | País | Por qué |
|---|---|---|
| Base | Perú | Mercado actual |
| 1 · entrada fácil | Ecuador | Vecino, dolarizado, CAN, mismo idioma y logística terrestre |
| 1 · escala | Colombia, Chile | Alianza del Pacífico, mercados mayores, canales maduros |
| 2 · tamaño | México | Mayor mercado hispano; competencia y certificación (NOM) más exigentes |
| 3 · largo plazo | Brasil | El mayor de la región; portugués, impuestos complejos, ANATEL/INMETRO |
| Vigilar | Bolivia, Centroamérica/Panamá, Argentina | Oportunistas; Argentina por volatilidad cambiaria |

## Reglas de trabajo

1. **Nombra el país en cada cifra.** Nunca "el mercado" a secas.
2. **Precios:** B2C en moneda local con impuesto incluido; B2B en USD y moneda
   local sin impuesto. Muestra la comparación por país en una tabla (precio local,
   equivalente USD, margen).
3. **Compara primero, profundiza después.** Empieza con una tabla resumen por país
   (3 a 5 filas) y desarrolla solo el país o los dos países que el usuario elija.
4. **Homologación y certificación:** para cada producto y país indica el organismo y
   si el trámite es obligatorio. Lo regulatorio cambia: confirma con una búsqueda
   web antes de que el usuario decida, y cita la fecha de la fuente.
5. **Datos volátiles** (impuestos, tipos de cambio, reguladores, fechas de eventos):
   usa `references/paises.md` como punto de partida y verifica en la web solo cuando
   la decisión dependa del número. No inventes cifras de tamaño de mercado: si no
   hay fuente, dilo y propone cómo estimarlo (arriba-abajo y abajo-arriba).
6. **Contenido:** adapta idioma, trato y formatos según `references/contenido.md`.
   Brasil siempre en portugués de Brasil.
7. **Canales:** considera marketplaces, WhatsApp Business, distribuidores locales y
   licitaciones públicas de cada país (ver `references/paises.md`).

## Archivos

- `references/paises.md`: ficha por país (moneda, impuestos, reguladores, bloques,
  canales, pagos, eventos de venta, compras públicas).
- `references/contenido.md`: localización de textos y formatos por país.
- `references/empresa.md`: perfil de la empresa que llena el usuario.
LATAM_EOF
cat > "$LATAM/references/paises.md" <<'LATAM_EOF'
# Ficha por país

Valores de referencia a octubre de 2026. Todo lo marcado (v) cambia con frecuencia:
verifícalo antes de una decisión.

## Impuestos y moneda

| País | Moneda | Impuesto al consumo (v) | Nota |
|---|---|---|---|
| Perú | PEN (S/) | IGV 18% | 16% IGV + 2% IPM |
| Ecuador | USD | IVA 15% | Fijado por decreto ejecutivo; revisar circulares del SRI |
| Colombia | COP | IVA 19% | Algunos bienes con tarifa reducida o excluidos |
| Chile | CLP | IVA 19% | Precios sin decimales |
| México | MXN | IVA 16% | 8% en la región fronteriza |
| Brasil | BRL | ICMS (estatal) + IPI + PIS/Cofins | Reforma: CBS desde 2027 e IBS gradual hasta 2033 |
| Bolivia | BOB | IVA 13% | Restricciones cambiarias (v) |
| Argentina | ARS | IVA 21% | Alta volatilidad cambiaria (v) |

Aranceles: revisa la partida arancelaria del producto en cada país; los acuerdos
(CAN, Alianza del Pacífico, Mercosur) pueden reducirlos según el origen.

## Reguladores para homologación y certificación (v)

| País | Telecom / radio (equipos con RF, celulares, routers) | Seguridad eléctrica / conformidad |
|---|---|---|
| Perú | MTC | Reglamentos técnicos sectoriales; INACAL para normas |
| Ecuador | ARCOTEL | INEN (reglamentos RTE) + organismos acreditados por el SAE |
| Colombia | CRC (terminales móviles), ANE (espectro) | RETIE; reglamentos técnicos (SIC) |
| Chile | SUBTEL | SEC |
| México | CRT (asumió funciones del IFT en 2025; certificados IFT siguen vigentes hasta su vencimiento) | NOM (p. ej. NOM-001-SCFI, NOM-019-SCFI) vía organismos como ANCE o NYCE |
| Brasil | ANATEL | INMETRO |
| Bolivia | ATT | IBNORCA |
| Argentina | ENACOM | Certificación de seguridad eléctrica (Res. SC) |

Pregunta clave por producto: ¿tiene radio (WiFi, Bluetooth, celular)? ¿Va enchufado
a la red eléctrica? ¿Usa baterías de litio (transporte y etiquetado)? Cada "sí"
suele sumar un trámite por país.

## Bloques comerciales

- **CAN:** Perú, Colombia, Ecuador, Bolivia.
- **Alianza del Pacífico:** Perú, Chile, Colombia, México.
- **Mercosur:** Brasil, Argentina, Uruguay, Paraguay, Bolivia.

## Canales y pagos

| País | Marketplaces (v) | Pagos habituales | Compras públicas |
|---|---|---|---|
| Perú | Mercado Libre, Falabella | Yape, Plin, tarjetas | SEACE |
| Ecuador | Mercado Libre (verificar), tiendas propias | Tarjetas, transferencias | SERCOP |
| Colombia | Mercado Libre, Falabella | PSE, Nequi, tarjetas | SECOP II |
| Chile | Mercado Libre, Falabella, Paris | Webpay, cuotas | Mercado Público |
| México | Mercado Libre, Amazon | SPEI, OXXO, meses sin intereses | Compras públicas federales (v) |
| Brasil | Mercado Livre, Amazon, Shopee | Pix, boleto, parcelamento | PNCP / Compras.gov.br |

En toda la región: WhatsApp Business es el canal de venta y soporte por defecto,
LinkedIn para B2B y competencia directa de plataformas como Temu o AliExpress en
B2C de electrónica de bajo precio.

## Eventos de venta (fechas varían cada año; v)

- Perú: Cyber Wow (varias ediciones al año).
- Chile: CyberDay.
- Colombia: Cyberlunes.
- México: Hot Sale (mayo/junio), Buen Fin (noviembre).
- Brasil y toda la región: Black Friday y Cyber Monday.
- Día de la Madre: México el 10 de mayo; la mayoría de países el segundo domingo de
  mayo. Revisa Navidad, regreso a clases y Día del Padre por país.
LATAM_EOF
cat > "$LATAM/references/contenido.md" <<'LATAM_EOF'
# Localización de contenido

## Idioma y trato

- Por defecto: español latinoamericano neutro. Adapta al país solo si la pieza es
  para un mercado concreto.
- B2B: "usted" en Perú, Colombia y Ecuador; "tú" o "usted" en México y Chile según
  la marca. Nunca voseo salvo piezas para Argentina o Uruguay.
- Brasil: portugués de Brasil siempre, nunca español ni portugués de Portugal.
- Evita modismos peruanos en piezas regionales.

## Vocabulario que cambia

| Concepto | Perú / Ecuador | Colombia | Chile | México |
|---|---|---|---|---|
| Computer | computadora | computador | computador | computadora |
| Laptop | laptop | portátil | notebook | laptop |
| Cellphone | celular | celular | celular | celular |
| Outlet/plug | tomacorriente | toma / enchufe | enchufe | contacto / enchufe |
| Discount event | ofertas / cyber | descuentos | ofertas / cyber | ofertas / rebajas |

Si dudas de un término, usa el más neutro y evita el modismo.

## Formatos de precio

| País | Ejemplo |
|---|---|
| Perú | S/ 1,299.90 |
| Ecuador | US$ 1,299.90 |
| Colombia | $1.299.900 COP |
| Chile | $1.299.990 (sin decimales) |
| México | $1,299.00 MXN |
| Brasil | R$ 1.299,90 |

Indica siempre si el precio incluye impuestos y, en B2C, las cuotas o meses sin
intereses cuando el canal los ofrezca (pesan mucho en Chile, México y Brasil).

## Piezas multi-país

Escribe una versión base y entrega solo las diferencias por país (vocabulario,
precio, evento, canal), no textos completos repetidos.
LATAM_EOF
# El perfil de empresa es tuyo: solo se crea si no existe, nunca se sobrescribe.
if [[ ! -f "$LATAM/references/empresa.md" ]]; then
cat > "$LATAM/references/empresa.md" <<'LATAM_EOF'
# Perfil de la empresa

Completa este archivo una vez. Claude lo lee antes de cada análisis para no
preguntarte lo mismo en cada sesión. Borra lo que no aplique.

- Empresa: 
- Rubros / líneas de producto: 
- Modelo: (importador, distribuidor, fabricante, retail, B2B, B2C)
- Países donde ya vendes: Perú
- Países prioritarios este año: 
- Margen bruto objetivo por línea: 
- Canales actuales: (tienda, distribuidores, Mercado Libre, licitaciones, ...)
- Proveedores u orígenes principales: 
- Certificaciones que ya tienen tus productos: 
- Competidores de referencia: 
- Tono de marca:
LATAM_EOF
fi
echo "  ✓ mercados-latam → $LATAM  (completa references/empresa.md)"

# ─────────────────────────────────────────────────────────────────────────────
# Reglas globales (se cargan en cada sesión: se mantienen cortas a propósito)
# ─────────────────────────────────────────────────────────────────────────────
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
touch "$CLAUDE_MD"
START="<!-- pack-comercial:inicio -->"; END="<!-- pack-comercial:fin -->"
# Quita el bloque anterior (si existe) y escribe la versión actual.
awk -v s="$START" -v e="$END" '$0==s{skip=1} !skip{print} $0==e{skip=0}' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
cat >> "$CLAUDE_MD" <<EOF
$START
## Contexto comercial

Empresa peruana de electrónica con aspiración regional (Ecuador, Colombia, Chile,
México, Brasil). Para mercado, precios, ventas, anuncios, contenido u
homologaciones usa la skill \`mercados-latam\`.

## Eficiencia

- Conclusión primero. Tablas o viñetas en vez de prosa; no repitas la pregunta ni
  resumas lo que acabas de hacer.
- Planifica en proporción: tareas simples, directo; tareas complejas, un plan de
  3 a 7 pasos una sola vez.
- Pregunta solo si te bloquea. Si no, asume lo razonable y decláralo en una línea.
- Lee solo lo necesario (rangos, hojas o páginas concretas) y no releas archivos.
- Busca en la web solo datos volátiles que afecten la decisión; una búsqueda por dato.

## Delegación por niveles

En tareas con varias partes, actúa como director: divide el trabajo y asigna cada
parte al agente más económico que pueda hacerla bien.

| Nivel | Agente | Para qué |
|---|---|---|
| Básico (Haiku) | \`haiku-investigador\`, \`haiku-operario\` | Buscar, leer, extraer datos, transformaciones mecánicas |
| Intermedio (Sonnet) | \`sonnet-analista\` | Borradores, análisis por país, briefs competitivos, localización, cálculos con criterio claro |
| Superior (tú) | — | Lo ambiguo o de alto impacto: precios, márgenes, elección de productos y países, normativa, síntesis final |

1. **Cantidad:** un agente por subtarea independiente (p. ej. uno por país o por
   proveedor), en paralelo. No delegues lo que es de un solo paso o está muy
   acoplado: si explicar la tarea cuesta más que hacerla, hazla tú.
2. **Encargo:** a cada agente dale objetivo, insumos concretos (rutas, datos; no
   toda la conversación), restricciones, formato de salida y criterio de aceptación.
3. **Revisión:** contrasta cada resultado con su criterio y verifica cifras y
   fuentes por muestreo. Si falla, reencarga una vez con la corrección concreta o
   sube un nivel. Nunca entregues al usuario un resultado sin revisar.
4. Con agentes genéricos puedes fijar el modelo (haiku o sonnet) al lanzarlos.
$END
EOF
echo "  ✓ reglas globales en $CLAUDE_MD"

echo
echo "Listo. Reinicia Claude Code para cargar todo."
echo "Para mantener el pack al día, vuelve a correrlo con --actualizar (una vez al mes)."
