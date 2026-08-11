---
id: nyabsidian-pendiente
aliases: []
tags: []
---

# Nyabsidian: pendiente — .nyabsidian en Lua y generación

Fecha: 2026-08-11. Replanteado tras probar `:NyabsidianFrontmatter` (hecho). La sesión anterior
(2026-08-10) planeaba `.nyabsidian` JSON con whitelist de claves; se descarta a favor de Lua.

## Estado

- [x] `NyabsidianFrontmatter` — fuerza la regeneración del frontmatter de la nota actual esté o
	  no activado. Incluye protección anti-basura: body con flow `[`/`{` sin cerrar (p.ej.
	  `aliases: [` o `id: [broken`) → warning y no reescribe (el parser YAML del plugin es
	  permisivo y los "arregla" en basura). Implementado y verificado.
- [x] `.nyabsidian` pasa de JSON a Lua.
- [x] `NyabsidianInit` — genera un `.nyabsidian` de ejemplo en buffer sin nombre.

## Hecho el 2026-08-11 (verificado headless)

- Pipeline Lua completo: `read_nyabsidian` (loadfile + pcall), validación con
  `config.normalize` (sin whitelist, `legacy_commands` neutralizado), ftplugin reclasifica a
  `lua`, conform aplica stylua, `.nyabsidian` del repo convertido.
- Verificado: sintaxis rota → warning + defaults; fragmento válido → aplica; live edit sin
  reiniciar; `frontmatter.enabled` como función por vault.
- **Bug encontrado y corregido**: `set_workspace` pasaba `ws.root` (objeto `Path`) a
  `read_nyabsidian`, y `vim.fs.joinpath` descarta el Path → leía el `.nyabsidian` del cwd
  (overrides del vault equivocado). Fix: normalizar `tostring(root)` a la entrada de
  `read_nyabsidian`/`workspace_overrides`.
- `NyabsidianInit` probado: buffer sin nombre, filetype `nyabsidian` → `lua` vía ftplugin,
  template de 17 líneas, notify con la ruta exigida.
- Herramientas: `sync.sh` + módulos `hzsr/sync.lua` y `hzsr/test/init.lua` (harness headless
  con `--root`, `--config`, `--plenary`) + comandos `:Synco` y `:Harness`.

## Decisiones

- **Formato Lua** (no JSON): permite comentarios y funciones por vault. El nombre del archivo se
  mantiene `.nyabsidian` (no `.nyabsidian.lua`). El archivo ES el marker: el directorio donde lo
  guardes es el vault (no es "la raíz" de un vault existente). Sin extensión, ningún otro archivo
  lo trata como módulo Lua (no se requiere desde fuera), pero dentro los `require` funcionan
  igual: `loadfile` no depende del nombre.
- **Semántica de merge**: el archivo devuelve un _fragmento_ de overrides (`return { ... }`). El
  deep-merge por clave de obsidian.nvim se mantiene tal cual (`Workspace.set` →
  `config.normalize(overrides, Obsidian._opts)` → `tbl_override`): lo que pongas pisa al default
  por clave. Aunque el archivo sea Lua el merge es igual de viable que con JSON — la tabla se
  mergea igual; las funciones son valores normales que se **reemplazan** por clave, nunca se
  fusionan.
- **La whitelist del plan anterior desaparece**: al no ser JSON no hay que passthrough de claves
  "seguras"; el fragmento entero pasa como overrides y `config.normalize` (con
  `legacy_commands = false` neutralizado) valida.
- **Lo que el Lua destraba** (JSON no podía): `frontmatter.func` y `frontmatter.enabled` como
  función, `templates.substitutions`, `note_id_func`, `note_path_func`, `callbacks` — todo por
  vault. Si un vault no define `frontmatter.func`, aplica la función global de `make_opts`
  (fallback por merge).
- **`NyabsidianInit`**: buffer sin nombre con template comentado; el usuario copia lo que le
  interesa y guarda con su `:w` (su save flow pide ruta y gestiona conflictos). La única
  incongruencia —guardarlo con otro nombre— se resuelve con docstring en el propio archivo +
  aviso del comando (factor humano). Nada de detección de ubicación ni check de existencia.
- `make_opts` no se toca: los defaults del plugin ya están bien.

## Pipeline: `.nyabsidian` JSON → Lua

1. `read_nyabsidian` (obsidian.lua l.236): `vim.json.decode` → `loadfile` + pcall del chunk.
   Vacío → `{}`. Error de sintaxis/runtime o resultado no-tabla → `config_warning` y `{}`.
2. `workspace_overrides` (l.267): simplificar — fuera la whitelist y fuera el caso especial de
   frontmatter (eliminar `overrides.frontmatter.func = nil`, l.282). Validar el fragmento con
   `config.normalize(copy)` (mantener el `copy.legacy_commands = false`) y devolverlo.
3. `after/ftplugin/nyabsidian.lua`: reclasifica a `json` → `lua` (sintaxis, treesitter, LSP).
4. `conform.lua`: quitar `nyabsidian = { "biome" }` (l.111-114) y el hack de filename falso en
   los args de biome (l.158-165). Al reclasificar a `lua`, aplica `lua = { "stylua" }` (l.82)
   solo.
5. Convertir el `.nyabsidian` del repo (el único que existe) a Lua.
6. ftdetect y live reload (BufWritePost por nombre) no cambian.

## NyabsidianInit (comando)

- Buffer nuevo sin nombre, filetype `nyabsidian` (→ `lua` vía ftplugin).
- Template con docstring y ejemplos comentados:

```lua
-- Config de Nyabsidian para este vault.
-- Guarda este archivo como ".nyabsidian" en el directorio que quieras
-- tratar como vault: ese archivo ES el marker que lo convierte en vault
-- (junto a .obsidian si existe). Es live: se relee al entrar en cada nota.
return {
  frontmatter = { enabled = true }, -- false, true, o una función por nota

  -- Ejemplos (claves por vault):
  -- link = { style = "markdown" },
  -- templates = { folder = "Templates" },
  -- daily_notes = { folder = "Daily", default_tags = { "diario" } },
  -- attachments = { folder = "Archivos" },

  -- frontmatter.func opcional: si no se define, aplica la función global.
  -- func = function(note) return { id = note.id } end,
}
```

- `notify`: recuerda la ruta/nombre exigidos.
- Tras guardar como `.nyabsidian`, el autocmd existente (BufWritePost, obsidian.lua l.779-785)
  refresca en caliente.

## Orden de implementación (pasos pequeños, que pruebe el usuario)

1. **Pipeline Lua** — hecho y verificado (11-08). Que pruebe el usuario: `.nyabsidian` Lua con
   `frontmatter.enabled = true` funciona live; sintaxis rota → warning y defaults; una vault JSON
   vieja rota con warning claro.
2. **NyabsidianInit** — hecho y verificado (11-08). Que pruebe el usuario: genera, guarda como
   `.nyabsidian`, refresca solo; guarda con otro nombre → solo es un buffer Lua normal.

## Verificación (harness headless, patrón de siempre)

- [x] `read_nyabsidian` con Lua válido / vacío / sintaxis rota / runtime error / no-tabla (lista,
  string).
- [x] Fragmento con `frontmatter.func` función → `config.normalize` no se atraganta (tbl_override
  maneja funciones: reemplazo por clave).
- [x] `NyabsidianInit` → buffer con template; save flow pide ruta.
- [x] stylua formatea el buffer `.nyabsidian` (filetype lua).

## Notas

- El merge ya funciona hoy: solo hay que meter las claves en overrides (verificado el 10-08). Los
  tests del comando headless cargan desde `~/.config/nvim` (rtp por defecto), no desde hzsr12.
- Recordatorio: hzsr12 y `~/.config/nvim` son directorios distintos. Ya no hace falta copiar a
  mano: `./sync.sh` (o `:Synco`) sincroniza hzsr12 → nvim, y el harness es
  `nvim --headless -u NONE -c "lua dofile('$HOME/.config/hzsr12/lua/hzsr/test/init.lua').run({})" -c qa!`
  (flags: `--root=`, `--config=`, `--plenary`). Reiniciar nvim para que cargue lo desplegado.
  </content>
