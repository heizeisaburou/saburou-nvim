# Sabunv Markdown — diseño de resolución, apertura y rename de enlaces/adjuntos

> Documento de diseño de `lua/sabunv/nvim/markdown.lua` y sus parches (`lua/lzy/obsidian.lua`,
> `after/ftplugin/markdown.lua`).
>
> Convención: las secciones **invariantes** describen lo que debe ser así sí o sí (no se
> negocian). Las **decisiones** tienen casillas `- [x]` y son las que el usuario debe marcar. La
> **política** recoge lo que se resuelve con configuración sin necesidad de decisión (defaults
> aquí propuestos).

---

## 1. Análisis del estado actual

### 1.1 Los dos mundos

| Contexto          | Marker                       | LSP                                       | Quién gestiona los enlaces                        |
| ----------------- | ---------------------------- | ----------------------------------------- | ------------------------------------------------- |
| Vault Obsidian    | `.obsidian/` o `.nyabsidian` | obsidian-ls (in-process, parcheable)      | obsidian.nvim + nuestros parches                  |
| Proyecto markdown | `.marksman.toml` o `.git`    | marksman (proceso externo, NO parcheable) | `sabunv.nvim.markdown` (gx) + LSP para navegación |
| Scratch           | ninguno                      | ninguno                                   | solo nuestro ftplugin (gx → cWORD)                |

El objetivo declarado es: "ganar capacidades de Obsidian incluso cuando no es Obsidian". Eso
obliga a un **motor agnóstico** y a tratar cada LSP como una **entrada** (adaptador), no como el
motor.

### 1.2 Qué hace hoy `sabunv.nvim.markdown` (estado estable, commit `ec89b74`)

- **`M.resolve(target, opts)`** — orden actual: nota → raíz → vault-wide por basename (solo si
  `root_of` dice que es vault real). Devuelve candidatos si la búsqueda vault-wide es ambigua.
- **`M.open`** — URI → `vim.ui.open`; resuelto → `vim.ui.open`; ambiguo → `vim.ui.select` con
  candidatos.
- **`M.ref_target(bufnr, row, col)`** — parser común de `[[x|label]]`, `![[x]]`, `[l](t)`,
  `<url>`.
- **`M.rename_attachment(target, new_name, opts)`** — mueve el archivo en disco y construye un
  WorkspaceEdit (documentChanges + `kind = "rename"`) que actualiza todos los enlaces del vault:
  wiki/embed, markdown relativos (nota y raíz), canvas. Conserva la extensión si no se da.
  Rechaza existentes/ambiguos. No toca menciones en prosa.
- Entradas: `gx` (ftplugin, con fallback cWORD), smart action y `gd` (parches sobre obsidian.nvim
  / obsidian-ls), `textDocument/rename` (parche sobre obsidian-ls).

### 1.3 Dónde está el problema (el "intermedio")

1. **El rename de adjuntos está acoplado a obsidian-ls** (parche del handler
   `textDocument/rename`). En un proyecto marksman, renombrar una imagen no hace nada (marksman
   no entiende adjuntos como tales) o, peor, puede responder algo que no controlamos.
2. **La semántica de rutas es ambigua entre mundos.** Hoy se resuelve nota → raíz → vault-wide.
   Pero:
	- `./x.png` y `../x.png` son **nota-relativos puros** (marca explícita).
	- `x.png` pelado puede significar "junto a esta nota" o "$ROOT/x.png" o (en Obsidian)
	  "cualquier x.png del vault". Marksman se queja cuando un `[[...]]` es ambiguo (al menos
	  para notas).
	- `sub/x.png` sin `./`: ¿nota o raíz? Hoy se prueba nota primero y luego raíz; hay que fijar
	  esto como contrato (decisión D1).
3. **El nombre nuevo del rename es "pelado" obligatorio** (solo basename, se queda en su
   carpeta). En Obsidian la operación natural permite **mover** de carpeta (el prompt admite
   path). En marksman interesa conservar el formato del enlace original (D4/D5/D6).
4. **El formato del enlace resultante no está garantizado.** Regla deseada: wiki → wiki, markdown
   → markdown, y el texto resultante debe ser el "menor" coherente con el modelo (en vault:
   `[[x]]` = basename; `![]()` = ruta relativa desde la nota que referencia).
5. **Renombrar notas solo funciona en vault** (vía obsidian-ls). En marksman hay que decidir si
   implementarlo (D7).
6. **No podemos parchear marksman** (proceso externo): cualquier intercepción de rename fuera de
   vaults debe hacerse a nivel cliente (D8).

### 1.4 Restricciones (no negociables)

- En vaults reales, obsidian.nvim debe seguir funcionando tal cual (los parches actuales se
  mantienen como están o se refinan sin cambio de comportamiento).
- En proyectos marksman no se lanza búsqueda vault-wide (hoy ya es así; verifica que siga siendo
  así con el resolver único).
- Un solo motor de resolución para todas las entradas (gx, smart action, gd, rename). Los LSP son
  adaptadores, no lógica de negocio.
- Nunca escribir archivos sin que el usuario lo haya pedido explícitamente (un rename es
  explícito; una apertura no escribe nada).

---

## 2. Modelo invariable (debe ser así)

### 2.1 Resolución de un target `t` desde un buffer `B`

`R` = raíz del vault/proyecto (puede ser nil). `es_vault` = existe marker `.obsidian`/`.nyabsidian` (ver
`M.root_of`). El orden es **este y solo este**:

1. **URI** (`scheme://`) → no es archivo local. Nunca tocar.
2. **Ruta absoluta** → ese archivo, tal cual (si existe).
3. **Prefijo explícito `./` o `../`** → siempre relativo a la carpeta de la nota. Semántica
   markdown pura. Si no existe → nil (sin fallbacks).
4. **Sin prefijo explícito** (basename pelado o ruta con `/` interna): a. relativo a la carpeta
   de la nota; b. si no existe, relativo a `R`; c. si no existe y `es_vault` → búsqueda
   vault-wide por basename; d. si no existe y no es vault → nil.
5. **Ambigüedad** (varias coincidencias en 4c) → candidatos. Apertura: picker. Rename: ver D9.
6. Todos los puntos de entrada (`M.open`, rename, gx, smart action, `gd`) pasan por este mismo
   orden con los mismos flags.

> Nota: el paso 4 es el "modelo híbrido" (nota → raíz) propuesto por el usuario. Si la decisión
> D1 elige el modelo nota-relativo puro, el paso 4 queda: relativo a la nota; si no existe y
> `es_vault` → vault-wide; raíz solo para rutas con `/` interna cuando el proyecto es marksman y
> la ruta no resuelve contra la nota (mismo orden, solo cambia la lista de destinos).
>
> ⚠️ Evidencia empírica (probes en `/tmp/opencode/probe`, ver §5): marksman NO resuelve `[[x]]`
> nota-relativo — resuelve por **basename en todo el workspace** e IGNORA `..`/paths de wiki;
> las imágenes NO son documentos para marksman (siempre `DEF-EMPTY` y diag "non-existent" aunque
> el archivo exista en disco), y marksman NO implementa `textDocument/rename` en absoluto
> (prepareRename → nil). Obsidian-ls tampoco responde `textDocument/definition` (todo `DEF-EMPTY`)
> y su rename es orientado a adjuntos. Consecuencia para el motor: la resolución propia debe ser
> la que da la semántica del modelo de D1; los LSP son solo entrada de navegación (y rename donde
> fun cione).

### 2.2 Parser de enlaces (común para apertura y rename)

- Wiki: `[[x]]`, `![[x]]`, `[[x|label]]`, `[[x#ancla]]`, `[[x^bloque]]`.
- Markdown: `[texto](target)`, `![alt](target)` — target puede ser URL.
- Autolink: `<url>`.
- El target extraído se limpia de label/ancla/bloque antes de resolver.
- `![]()` con URL (`https://…`, `data:`, `file:`) nunca se renombra.

### 2.3 Rename de adjuntos

Invariantes:

1. **El enlace resultante conserva el formato del enlace original**: wiki/embed →
   `[[nuevo_basename]]` (el vault resuelve por basename); markdown → ruta relativa desde la nota
   que referencia (o la forma que el modelo de D1 exija), nunca URL.
2. **El nombre nuevo admite dos formas** (decisión D4, pero el motor soporta ambas desde ya):
	- basename pelado → se queda en su carpeta;
	- con subruta `carpeta/nuevo.png` → mueve el archivo (creando carpetas si hace falta) y los
	  enlaces se actualizan apuntando a la nueva ubicación.
3. **Validación**: no vacío, no `.`/`..`, no `\`, destino inexistente, nombre final distinto del
   actual, target resoluble y no ambiguo, y el archivo debe estar DENTRO del root (ver D10 para
   la excepción).
4. **El WorkspaceEdit** (documentChanges + `kind = "rename"`) es el único mecanismo de
   aplicación: el cliente modifica los buffers y nuestro `silent! wall` diferido persiste (mismo
   patrón que el plugin).
5. **Ambigüedad de resolución del target** → nunca renombrar "a ciegas": el usuario elige (D9) o
   se aborta.
6. No se tocan menciones en prosa (solo contextos de enlace: dentro de `[[…]]`, tras `](`, rutas
   relativas no pegadas a más caracteres de ruta).

### 2.4 Notas (para D7)

El mismo motor sirve para renombrar notas si el LSP no lo cubre: resolver el target (con la
semántica de D1), validar el nombre nuevo (idéntico al de adjuntos, p.ej. subruta = move), y
construir el WorkspaceEdit sobre los `[[…]]` de todo el proyecto. La diferencia con adjuntos es que
una nota puede tener alias YaML, titles y anchors — el motor de reemplazo debe tratar `[[x]]` y
`[[x|label]]` dejando el label intacto.

---

## 3. Decisiones (márcalas tú, no se implementan sin esto)

### D1 — Semántica de rutas sin prefijo explícito (corazón del resolver)

> Empíricamente (2026-08-12, §5.1): marksman resuelve `[[x]]`/`[x](y)` sin prefijo por basename en
> todo el workspace (nunca nota-relativo) e ignora `../` wiki. Nuestro resolver es libre de
> implementar cualquier modelo; la divergencia con el LSP se acepta (el LSP solo navega).

- [ ] **A) Nota-relativo puro**: `x.png` solo significa "junto a esta nota". Fallback a
	  raíz/vault-wide solo para el caso wiki-explícito que decida el LSP. Simple y predecible;
	  rompe el caso "la imagen vive en `$ROOT` y la nota en `sub/`".
- [ ] **B) Híbrido nota → raíz → (vault) vault-wide** (recomendado, es lo que describe el
	  enunciado): `sub/note.md` con `x.png` encuentra `sub/x.png`, y si no está, `$ROOT/x.png`;
	  en vault, además, cualquier `x.png` del vault. Afecta a apertura y rename por igual.
- [ ] **C) Configurable** por política (default B; p. ej. proyectos marksman pueden forzar A si
	  hay colisiones).

### D2 — Búsqueda vault-wide: ¿dónde se permite?

- [ ] **A) Solo vaults reales** (estado actual; recomendado).
- [ ] **B) También en proyectos marksman**: resuelve `x.png` de todo el proyecto. Riesgo:
	  ambigüedades frecuentes; marksman ya se queja de estas cosas para notas; puede sorprender.
- [ ] **C) Config por proyecto** (default A).

### D3 — Rename de adjuntos: ¿qué entrada lo atiende en cada mundo?

> Empíricamente (2026-08-12, §5.2): el rename de obsidian-ls para ADJUNTOS es fuerte (renombra
> el archivo con `kind=rename` y edita todas las referencias del vault), pero para NOTAS es
> poco fiable (placeholde = primer adjunto del buffer, no la nota bajo el cursor). En marksman
> no hay rename alguno. → En vault, para adjuntos, delegar en el LSP sigue siendo válido; la
> entrada de cliente es la única forma de rename de notas en marksman.

- [ ] **A) Mantener obsidian-ls como única entrada** (estado actual): en proyectos marksman
	  simplemente no hay rename de adjuntos.
- [ ] **B) Entrada de cliente única** (recomendado): el comando/mapping `sabunv` decide según
	  contexto — si el target bajo el cursor es un adjunto, construye el edit con el motor y lo
	  aplica (funciona con cualquier LSP o sin LSP); si es una nota, delega en el LSP adjunto.
- [ ] **C) Híbrido**: vault → parche obsidian-ls actual; marksman → entrada de cliente. Aceptable
	  pero duplica código de entrada.

### D4 — Rename de adjuntos en vault: ¿se permite mover de carpeta?

- [ ] **A) Solo basename** (estado actual): el archivo se queda donde está; la salida del enlace
	  markdown solo cambia el nombre.
- [ ] **B) Basename o subruta** (recomendado): si el prompt recibe `carpeta/nuevo.png`, se mueve;
	  en ambos casos el output de los enlaces usa la forma mínima del modelo (wiki → basename; md
	  → ruta relativa desde cada nota que referencia).
- [ ] **C) Como B + confirmación** si al mover se crean carpetas o el destino cruza directorios.

### D5 — Rename en marksman: formato del enlace resultante

- [ ] **A) Conservar la forma original** (recomendado): si era `./x.png` queda `./x2.png`; si era
	  `x.png` queda `x2.png` (sin `./`, sin `/`).
- [ ] **B) Normalizar siempre a la forma mínima** (pelado sin `./` salvo que el modelo D1 la
	  exija).

### D6 — Rename en marksman: ¿mover archivo?

- [ ] **A) Solo nombre** (estable y mínimo).
- [ ] **B) Permitir subruta = mover** (simétrico con D4; el formato del enlace resultante respeta
	  D5 salvo que la ruta lo exija).
- [ ] **C) Como B + política de carpeta por defecto** (p. ej. `assets/` del proyecto si el nombre
	  nuevo no trae subruta y la config lo pide).

### D7 — Renombrar notas en proyectos marksman (sin vault)

> Empíricamente (2026-08-12, §5.1): marksman devuelve `nil` en `prepareRename` y `rename` tanto
> para notas como para adjuntos — NO soporta rename en absoluto. La opción A queda descartada.

- [ ] **A) No implementar** (obsoleto: marksman no soporta rename nativo).
- [ ] **B) Implementar con el motor sabunv** (recomendado): mismo WorkspaceEdit, `[[x]]` por todo
	  el proyecto, label intacto, alias respetados; solo actúa si el LSP no responde o el target
	  es nuestra responsabilidad.
- [ ] **C) Solo como fallback** cuando no hay LSP adjunto (scratches).

### D8 — Intercepción del rename para marksman (si D3=B)

> Empíricamente (2026-08-12, §5.1): marksman no responde a `rename`/`prepareRename` (nil), así
> que no hay nada que interceptar del lado LSP; la entrada de cliente es la única vía.

- [ ] **A) Mapping/comando propio** (`sabunv rename`, `normal! <leader>nr` compartido):
	  intercepta SIEMPRE, decide por contexto (vault → flujo actual; marksman/adjunto → motor;
	  nota → LSP). Recomendado: una sola puerta, sin duplicar con el parche del plugin (que se
	  mantiene por compatibilidad con `:Obsidian rename`).
- [ ] **B) Parche a `vim.lsp.handlers["textDocument/rename"]`** (nivel cliente, después del
	  server): corre para cualquier LSP, pero ensucia el flujo estándar y es difícil de depurar.
- [ ] **C) Parche al método LSP en caliente** (wrapper de `vim.lsp.buf_request` para ese método):
	  frágil.

### D9 — Ambigüedad en el RENAME (el target resuelve a varios)

- [ ] **A) Abortar con error claro** (estado actual; recomendado: renombrar a ciegas es
	  destructivo).
- [ ] **B) Picker de candidatos** y renombrar el elegido (todas las referencias del vault apuntan
	  al mismo archivo real que se mueve — cuidado: con dos `x.png` distintos, el picker resuelve
	  el caso).
- [ ] **C) Config** (default A).

### D10 — El adjunto está FUERA del root / es enlace externo

- [ ] **A) Abortar** (recomendado: nunca tocar fuera del vault/proyecto).
- [ ] **B) Permitir con confirmación** (útil si el vault monta enlaces a un directorio compartido
	  externo).
- [ ] **C) Ignorar silenciosamente** (no recomendado).

---

## 4. Política y configuración (no necesita tu decisión; defaults propuestos)

Opción `sabunv.markdown` (nuevo bloque en `lzy/obsidian.lua` o en el módulo, con `vim.g`/`require`
perezoso). Defaults:

| Clave                         | Default                            | Efecto                            |
| ----------------------------- | ---------------------------------- | --------------------------------- |
| `model`                       | `hybrid` (`note-only` si D1=A o C) | Semántica del punto 2.1-4         |
| `vault_wide_only_in_vaults`   | `true` (D2=A)                      | Búsqueda por basename global      |
| `rename.move`                 | `true` (D4/B, D6/B)                | Subruta = mover                   |
| `rename.format`               | `preserve` (D5/A)                  | Forma del enlace resultante       |
| `rename.no_move_outside_root` | `true` (D10/A)                     | Abortar si fuera del root         |
| `rename.ambiguous`            | `abort` (D9/A)                     | Comportamiento ante candidatos    |
| `rename.move_default_folder`  | `"assets"` (solo D6/C)             | Carpeta si el nombre no trae ruta |

Decisiones idénticas para ambos LSP cuando aplican: la config es única y el adaptador de cada LSP
solo traduce (cursor, buffer, respuesta) al motor.

## 5. Verificaciones experimentales (probes en `/tmp/opencode/probe`, 2026-08-12)

Metodología: árbol idéntico para ambos mundos (`proj/` con `.marksman.toml` en raíz; `vault/` con
`.obsidian/`), con duplicados a propósito (`dup.md`, `root.md`, `img.png` en raíz y subcarpetas).
Se consultaron los servers reales (marksman y obsidian-ls vía nvim headless) con
`textDocument/definition`, diagnostics, `prepareRename` y `rename`. Resultados:

### 5.1 marksman (proyecto)

| Forma de enlace (desde `sub/note.md` o raíz) | Definición | Diagnóstico |
| --- | --- | --- |
| `[[dup]]` (existe en raíz Y en `sub/`) | MULTI(2) raíz+sub | ERROR *Ambiguous link* |
| `[[../dup]]` (idem, con `..`  explícito) | MULTI(2) raíz+sub — el `..`  se IGNORA | ERROR *Ambiguous* |
| `[[sub/dup]]` desde `sub/note.md` | resolve a `root/sub/dup.md` **root-relative** | — |
| `[[root.md]]` desde `sub/note.md` | MULTI(2) | ERROR *Ambiguous* |
| `[[otra]]` único en raíz | resuelve `root/otra.md` | — |
| `[[img.png]]` (existe en disco en ambas) | **EMPTY** — las imágenes NO son documentos | ERROR *Link to non-existent document* |
| `[n1](dup.md)`, `[n3](dup.md)` (md-link pelado) | igual que wiki: basename-wide, MULTI si duplicado | WARN *Ambiguous* |
| `[n2](sub/dup.md)` (md-link con ruta) | root-relative único | WARN si basename duplica |
| `![](img.png)` (embed, archivo existente) | EMPTY | ERROR *non-existent* |

**Halls concretos:**

1. **marksman resuelve `[[x]]`/`[x](y)` por basename en TODO el workspace**, no nota-relativo ni
   root-relative "puro": con dos `dup.md`/`root.md` devuelve los dos y diagnostica *Ambiguous*.
   La ruta con `/` interna sí filtra root-relative (`sub/dup` → `root/sub/dup.md`). El `../`
   explícito de wiki se ignora: `[[../dup]]` desde `sub/` devuelve los mismos dos candidatos.
2. **Las imágenes no existen para marksman**: aunque `img.png` esté en disco, `[[img.png]]` da
   *Link to non-existent document* y `DEF-EMPTY`. Solo los `.md` son "documentos". (Los adjuntos
   NO se resuelven ni se renombran.)
3. **`textDocument/rename` NO existe en marksman**: `prepareRename` y `rename` devuelven `nil`
   (sin error) tanto sobre `[[otra]]` como sobre `![](img.png)`. → D7 queda: implementar motor
   propio o nada; "usar nativo" NO es opción.
4. Ambigüedad para notas `.md`: ERROR (wiki) / WARN (md-link); definición devuelve MULTI en el
   resultado, no lo declara como fallo.

### 5.2 obsidian-ls (vault)

| Forma de enlace | Definición | Diagnóstico |
| --- | --- | --- |
| Todas (`[[x]]`, `[x](y)`, `![]()`, con/sin duplicados) | **EMPTY** siempre | ninguno |
| `prepareRename` sobre `![](img.png)` | `{placeholder = "img.png"}` | — |
| `rename` → `imgx` sobre `![](img.png)` | WorkspaceEdit: textEdits en 3 archivos (root.md 4, note.md 4, deep.md 3) + `kind=rename` `sub/img.png → sub/imgx.png` | — |

**Halls concretos:**

1. **obsidian-ls NO implementa `textDocument/definition`** (ni para notas existentes ni para
   embeds): todo `DEF-EMPTY`. Tampoco diagnostica enlaces rotos ni ambigüedad. → La navegación
   `gd`/gx en vault no puede depender del LSP: solo obsidian.nvim y nuestro resolver.
2. **El rename de obsidian-ls es fuerte para adjuntos**: renombra el archivo (`kind=rename`) y
   edita TODAS las referencias del vault (wiki, md-relativo, embeds) en todos los archivos —
   exactamente lo que replicamos en el motor. El placeholder es el basename del adjunto.
3. **Sobre `[[nota]]` el rename de obsidian-ls es raro**: `prepareRename` devuelve placeholder
   `img.png` (¡el primer adjunto del buffer actual!) y el rename aplica a `sub/img.png`, no a
   `otra.md`. → El rename de NOTAS por este camino no es fiable; usar el comando propio de
   obsidian.nvim (o motor sabunv), como ya prevé D3/D8.
4. `apply_workspace_edit(result, "utf-16")` sobre imagen abierta en buffer: OK — mueve el archivo
   en disco, el buffer abierto se queda apuntando al nuevo nombre (nvim 0.11 lo soporta nativo;
   en el caso probado además se autoconvierte el buffer). No rompe nada.

### 5.3 Implicaciones para el modelo y las decisiones

- D1: el "híbrido nota → raíz → vault-wide" es coherente como motor propio; en marksman el LSP
  concurre con basename-wide, así que nuestro resolver y el LSP pueden divergir: eso se acepta
  (nuestro resolver es el motor; el LSP solo navegación). El `../` nota-relativo SÍ debe respetar
  `../` (a diferencia de marksman) porque es la semántica markdown pura.
- D2: en marksman la búsqueda vault-wide de .md es gratuita (el LSP la hace); para adjuntos no
  existe en el LSP → sigue siendo decisión nuestra.
- D7: marksman no renombra nada → o motor sabunv o nada (la opción "usar nativo" queda descartada
  empíricamente).
- D8: no hay nada que interceptar de marksman (no responde); la entrada propia es la única vía.
- D10: `apply_workspace_edit` con `kind=rename` es seguro sobre archivos abiertos → no hay
  bloqueo técnico en el mecanismo.

## 6. Plan de implementación propuesto (tras decisiones)

1. **Motor único**: refactor de `M.resolve` a `model` + tests por tabla de casos
   (nota/raíz/vault-wide/ambiguo, con y sin vault).
2. **Rename multi-entrada**: `sabunv rename` (D3/D8), move con subruta (D4/D6), formato de salida
   (D5).
3. **Notas en marksman** (D7): motor de nota (labels/anchors) + backlinks del proyecto.
4. **E2E**: tabla de escenarios (por LSP × forma de enlace × modelo) en el suite actual de
   `/tmp/opencode`.

> Los tres commits de la base estable: `1499175` (autolinks), `443b4ad` (resolución real
> adjuntos), `ec89b74` (rename de adjuntos vía LSP).

