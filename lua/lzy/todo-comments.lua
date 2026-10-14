local M = {}
local leading_padding_namespace = vim.api.nvim_create_namespace "todo-comments-leading-padding"

M.keys = {
  {
    "<leader>ft",
    function()
      local ok = pcall(function()
        vim.cmd.TodoTelescope()
      end)

      if not ok then
        vim.cmd.TodoQuickFix()
      end
    end,
    desc = "Telescope: todo-comments",
  },
}

-- ----------------------------------------------------------------------------
-- Palabras clave
-- ----------------------------------------------------------------------------
-- Se escriben en mayúsculas y entre dos puntos, uno a cada lado de la palabra;
-- cada una admite sus alias (`alt`) con el mismo color e icono. Los ejemplos de
-- abajo empiezan por `/` en vez de por dos puntos para que no aparezcan en el
-- buscador de etiquetas ni se resalten.
--
-- Van en seis grupos. Para elegir, se responden estas preguntas en orden y vale
-- la primera que diga que sí:
--   1. ¿Es un parche: código ya puesto que toca o rodea algo por un camino que
--      no es el normal?                                         → Parches
--   2. ¿Queda trabajo por hacer?                                → Pendiente
--   3. ¿Hay que tener cuidado antes de tocarlo?                 → Avisos
--   4. ¿Solo da contexto?                                       → Información
--   5. ¿No es serio?                                            → Desahogo
--   6. ¿Solo marca una sección del código?                      → Marcadores
-- El orden va de lo que más conviene poder encontrar después a lo que menos.
-- Los parches van primero porque casi todos dejan algo pendiente (quitarlos,
-- revisarlos), y su etiqueta dice además qué puede romperse, que es lo que
-- importa al tocarlos. El desahogo va casi al final porque un chiste no quita
-- que haya trabajo: si lo hay, manda la etiqueta seria.
--
-- Dentro de cada grupo van de más a menos urgente, y cada etiqueta dice cuándo
-- usarla y en qué se diferencia de las que se le parecen.
--
-- `merge_keywords` está desactivado: el plugin trae sus propias palabras y,
-- fusionadas con estas, INFO acababa resolviéndose como alias de NOTE.
-- Aquí están todas las que existen.
--
-- La guía completa, con cómo elegir entre las que se parecen, está en
-- `docs/Etiquetas de comentarios.md`. Si cambia una etiqueta, cambian las dos.

-- Parches: tocan o rodean algo por un camino que no es el normal.
--
-- Todos son código que ya funciona. Se elige con estas preguntas, en orden:
--   1. ¿Se toca código de otro (un plugin, una biblioteca, Neovim)?
--      - Se sustituyen sus funciones desde fuera, al ejecutar  → MONKEYPATCH
--      - Se edita una copia de su código que vive en el repo   → PATCH
--   2. ¿No se toca, pero se rodea un fallo suyo hasta que lo
--      arreglen?                                               → UPSTREAM
--   3. ¿Es cosa nuestra?
--      - Arreglo urgente de algo que se rompió en uso          → HOTFIX
--      - Truco por un camino no previsto, que puede romperse   → HACK
-- La técnica va antes que la causa porque lo que más importa al leer un
-- parche es qué lo puede romper. Tocar el código de otro se rompe en cuanto
-- ese otro cambia, aunque el motivo fuera un fallo suyo: un fallo de un
-- plugin arreglado con un monkey patch es MONKEYPATCH, y la incidencia se
-- enlaza en el texto.
local patch_keywords = {
  -- Un monkey patch es cambiar el código de otro desde fuera mientras el
  -- programa corre, sin tocar sus archivos: se sustituye una de sus funciones
  -- por una nuestra. En Lua basta con asignar
  -- `require("plugin").funcion = function() ... end`. Quien lea el código del
  -- plugin no sabrá que aquí se cambia, y se rompe en cuanto el plugin cambie
  -- esa función por dentro. Duck punching es otro nombre para lo mismo.
  --   /MONKEYPATCH: se sustituye `open` del picker de obsidian.nvim para que
  --   use nuestras opciones de Telescope.
  MONKEYPATCH = {
    icon = " ",
    color = "warning",
    alt = { "MONKEY_PATCH", "MONKEYPATCHED", "DUCKPUNCH" },
  },

  -- Código de otro copiado en el repo y modificado, o un archivo `.patch` que
  -- se aplica sobre el suyo. Un parche es eso: un cambio que se pone encima del
  -- código original. Al actualizar desde el original hay que volver a aplicar
  -- el cambio, así que conviene decir de qué versión viene y qué se cambió.
  --   /PATCH: copiado de mini.nvim 0.14; solo cambia el cálculo del ancho.
  -- No es `MONKEYPATCH`: aquí el código de otro se edita; allí se sustituye
  -- desde fuera sin tocar sus archivos.
  PATCH = {
    icon = " ",
    color = "warning",
    alt = { "PATCHED" },
  },

  -- Rodeo para un fallo de una dependencia (un plugin, una herramienta, el
  -- propio Neovim) que se quita cuando lo arreglen ellos. "Upstream" es el
  -- proyecto original del que dependemos, "río arriba". Conviene enlazar la
  -- incidencia y decir cuándo se puede quitar. Un workaround es justo eso: un
  -- rodeo para esquivar un fallo que no es nuestro.
  --   /UPSTREAM: render-markdown#123; quitar cuando salga la 8.14.
  -- Su código no se toca; si se tocara, sería `MONKEYPATCH` o `PATCH`.
  UPSTREAM = {
    icon = " ",
    color = "warning",
    alt = { "WORKAROUND" },
  },

  -- Arreglo urgente de algo que se rompió en pleno uso, hecho deprisa y lo más
  -- pequeño posible para que vuelva a funcionar ya; pide revisarlo con calma
  -- después. "Hot" porque se aplica en caliente, con todo en marcha. QUICKFIX
  -- es "arreglo rápido", y no tiene que ver con la lista quickfix de Vim.
  --   /HOTFIX: se ignoran las notas sin título, que tumbaban el picker; falta
  --   ver por qué llegan así.
  -- No es `FIX`: aquello sigue roto; esto ya funciona. No es `DEBT`: la deuda
  -- es un atajo elegido con calma; esto es una urgencia.
  HOTFIX = {
    icon = " ",
    color = "warning",
    alt = { "QUICKFIX", "HOTPATCH" },
  },

  -- Un hack es un truco: conseguir que algo funcione por un camino que el
  -- sistema no tenía previsto. No tiene nada que ver con atacar ni vulnerar
  -- nada; la palabra viene de la jerga de programadores, donde un hack es una
  -- solución ingeniosa. Aquí marca uno que se apoya en algo que no debería (un
  -- detalle interno de un plugin, un comportamiento no documentado), así que
  -- puede dejar de funcionar sin aviso.
  --   /HACK: se lee un campo privado de render-markdown.
  -- No es `UPSTREAM`: no esquiva un fallo de nadie, es un atajo nuestro.
  HACK = { icon = " ", color = "warning" },
}

-- Pendiente: trabajo que falta.
local pending_keywords = {
  -- Está mal: falla, da un resultado incorrecto o rompe algo.
  --   /FIX: con un `.md` vacío devuelve nil y el llamante no lo comprueba.
  FIX = {
    icon = " ",
    color = "error",
    alt = { "FIXME", "BUG", "FIXIT", "ISSUE", "PANIC", "ERROR" },
  },

  -- Falta hacerlo y está claro qué es. Si no está claro qué es, es
  -- `PROVISIONAL` o `PLACEHOLDER`.
  --   /TODO: atajo para abrir la nota del día.
  TODO = { icon = " ", color = "info" },

  -- No se puede avanzar hasta que pase algo de fuera: una decisión, otra pieza
  -- del proyecto, una respuesta. Un `TODO` dice "falta hacerlo"; esto dice
  -- "ahora no se puede". Conviene decir qué se espera.
  --   /BLOCKED: hasta decidir si nyabsidian sigue sobre Neovim o va aparte.
  BLOCKED = {
    icon = " ",
    color = "warning",
    alt = { "BLOCKER", "WAITING" },
  },

  -- Solución puesta para poder seguir montando el resto, sabiendo que no es la
  -- definitiva: la buena se decidirá cuando sepamos lo suficiente, y esto evita
  -- tener que conjeturarla ahora. Conviene decir qué falta saber. SCAFFOLD es
  -- "andamio": se pone para poder construir y se quita cuando el edificio se
  -- sostiene solo. INTERIM no es una abreviatura sino una palabra inglesa,
  -- "interino": lo que ocupa el puesto mientras llega lo definitivo.
  --   /PROVISIONAL: las rutas van fijas hasta saber si habrá varios vaults.
  --   /PROVISIONAL: se guarda en JSON; el formato se decide cuando sepamos qué
  --   consultas hacen falta.
  -- No es `DEBT`: en la deuda la buena ya se conoce y no se ha hecho; aquí
  -- todavía no se conoce. No es `STUB`: esto funciona de verdad.
  PROVISIONAL = {
    icon = "󰔟 ",
    color = "warning",
    alt = { "TEMP", "TEMPORARY", "INTERIM", "SCAFFOLD" },
  },

  -- Atajo feo hecho a sabiendas: se sabe cuál es la solución buena y no se ha
  -- hecho todavía. Es lo que se llama deuda técnica: se ahorra tiempo ahora a
  -- cambio de un trabajo que habrá que pagar más adelante.
  --   /DEBT: se copia la tabla entera en cada llamada; habría que cachearla.
  DEBT = {
    icon = "󱖫 ",
    color = "warning",
    alt = { "UGLY" },
  },

  -- Hay que reestructurarlo: funciona, pero la forma estorba (está duplicado,
  -- mezcla responsabilidades, cuesta de leer).
  --   /REFACTOR: estas tres funciones hacen lo mismo con otro nombre de campo.
  REFACTOR = {
    icon = " ",
    color = "warning",
    alt = { "CLEANUP", "REORGANIZE", "REWRITE" },
  },

  -- Es lento, o lo será cuando crezca.
  --   /PERF: recorre todo el vault en cada pulsación.
  PERF = {
    icon = " ",
    color = "warning",
    alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" },
  },

  -- Código falso que ocupa el lugar del de verdad para que lo de alrededor se
  -- pueda escribir o probar antes de que exista.
  --   - Un stub solo responde: devuelve siempre lo mismo (una nota de ejemplo,
  --     `true`) o no hace nada.
  --   - Un mock además vigila cómo lo usan: apunta con qué argumentos y cuántas
  --     veces lo llaman, para que una prueba pueda comprobarlo después.
  -- En los dos casos el código no es real, por eso comparten etiqueta.
  --   /STUB: siempre devuelve la misma nota de ejemplo.
  STUB = {
    icon = "󰇝 ",
    color = "warning",
    alt = { "MOCK" },
  },

  -- Hueco por rellenar: aquí irá algo y todavía no hay nada. TBD es "to be
  -- determined", "por determinar": aún no se ha decidido qué va.
  --   /TBD: texto de ayuda del comando.
  PLACEHOLDER = {
    icon = "",
    color = "comment",
    alt = { "PLACEHOLDERS", "TBD", "TOBEFILLED", "TOBEIMPLEMENTED", "FILLME" },
  },

  -- Funciona y está bien, pero podría estar mejor; ahora mismo no compensa
  -- hacerlo. No es un defecto: si nunca se hace, no pasa nada.
  --   /IMPROVE: el aviso podría decir también la línea exacta.
  -- No es `REFACTOR`: eso pide cambiarlo; esto solo anota que se podría.
  IMPROVE = {
    icon = "󰔵 ",
    color = "hint",
    alt = { "POLISH", "ENHANCE" },
  },

  -- Idea o plan para más adelante: algo nuevo, no algo que esté mal.
  --   /FUTURE: exportar las notas a PDF.
  --
  -- ROADMAP es "hoja de ruta": la lista ordenada de pasos previstos para llegar
  -- a un objetivo. Sirve para dejar dicho en qué paso del plan está un código y
  -- qué viene después, así quien lo lea sabe por qué hoy está incompleto y no
  -- lo "arregla" en la dirección equivocada.
  --   /ROADMAP: 1) enlaces entre notas (esto), 2) enlaces a encabezados,
  --   3) enlaces a bloques. Por eso aquí aún no se mira lo que va tras el `#`.
  FUTURE = {
    icon = " ",
    color = "hint",
    alt = { "NEXT", "ROADMAP", "UPCOMING", "PROPOSAL" },
  },
}

-- Avisos: cuidado al tocar esto.
local warning_keywords = {
  -- Afecta a la seguridad o a la privacidad.
  --   /SECURITY: el token se escribe en el log.
  SECURITY = {
    icon = "󰒃 ",
    color = "error",
    alt = { "VULN", "AUTH", "SECRET", "PRIVACY" },
  },

  -- Algo que no es evidente y que conviene saber antes de cambiar el código.
  -- XXX es una convención antigua con el mismo sentido: "ojo aquí".
  --   /WARN: el orden importa; prettier tiene que ir antes que la restauración.
  WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },

  -- Suposición de la que depende el código y que nadie ha comprobado. Deja
  -- escrita la conjetura para poder verificarla más adelante o para
  -- encontrarla cuando algo falle por su culpa.
  --   /ASSUME: el vault nunca tiene enlaces simbólicos.
  --   /ASSUME: las fechas del frontmatter vienen siempre en ISO 8601.
  -- No es `PROVISIONAL`: aquello es una solución temporal; esto es una premisa
  -- que, si resulta falsa, rompe el código aunque nadie lo haya tocado.
  ASSUME = {
    icon = " ",
    color = "warning",
    alt = { "ASSUMPTION", "ASSUMES" },
  },

  -- Sigue aquí pero no hay que usarlo: va a desaparecer o ya hay otra cosa.
  --   /DEPRECATED: usar `open_note`.
  DEPRECATED = {
    icon = "󰀼 ",
    color = "warning",
    alt = { "OLD", "OBSOLETE", "REMOVE" },
  },
}

-- Información: contexto, sin trabajo pendiente.
local info_keywords = {
  -- Explicación de por qué el código es así. COMM es la abreviatura de
  -- "comment", comentario.
  --   /NOTE: Obsidian guarda las fechas en UTC.
  NOTE = { icon = " ", color = "info", alt = { "REMARK", "ANNOTATION", "COMM" } },

  -- Dato de referencia, más secundario que una nota.
  --   /INFO: el formato viene de la especificación de CommonMark, sección 4.5.
  INFO = { icon = " ", color = "hint", alt = { "HINT" } },

  -- Hay que revisarlo o hablarlo: una duda, algo que no está comprobado.
  --   /REVIEW: ¿hace falta esto si el plugin ya lo hace?
  REVIEW = {
    icon = "󰛨 ",
    color = "hint",
    alt = { "QUESTION", "EXPLAIN", "DISCUSS", "VERIFY" },
  },

  -- Sobre documentación: qué documento lo explica o qué falta documentar.
  --   /DOCS: el flujo completo está en docs/language-dependencies.md.
  DOCS = {
    icon = "󰈙 ",
    color = "comment",
    alt = { "DOCUMENTATION", "README", "GUIDE" },
  },

  -- Sobre pruebas: qué la cubre, o su estado.
  --   /TEST: lo cubre spec/conform_markdown_spec.lua.
  TEST = {
    icon = "⏲ ",
    color = "warning",
    alt = { "TESTING", "PASSED", "FAILED" },
  },

  -- Código que se queda aunque nadie lo use todavía.
  --   /UNUSED: lo usará el comando de exportar.
  UNUSED = {
    icon = "",
    color = "hint",
    alt = { "UNREFERENCED", "UNIMPORT" },
  },

  -- Limitación conocida y aceptada a propósito: se sabe y no hay intención de
  -- quitarla, porque no compensa o porque es el precio de otra cosa. Evita que
  -- alguien la tome por un fallo y la "arregle".
  --   /LIMIT: un bloque de código sangrado dentro de un ítem de lista sigue
  --   pasando a tabs; sin un parser no se distingue de la propia lista.
  -- No es `IMPROVE`: aquello se podría mejorar; esto se ha decidido dejarlo.
  LIMIT = {
    icon = " ",
    color = "hint",
    alt = { "LIMITATION", "KNOWN" },
  },

  -- Código que solo existe por compatibilidad con otra versión, otro sistema o
  -- un formato antiguo ("legacy": heredado de antes). Conviene decir cuándo se
  -- podrá borrar.
  --   /COMPAT: Neovim 0.10; quitar al exigir la 0.12.
  COMPAT = {
    icon = " ",
    color = "hint",
    alt = { "COMPATIBILITY", "LEGACY" },
  },

  -- Algo que estaba pendiente y ya está hecho, dejado como registro.
  --   /DONE: ya acepta rutas con espacios.
  DONE = {
    icon = " ",
    color = "comment",
    alt = { "COMPLETED", "FINISHED", "OK", "CHECKED" },
  },
}

-- Desahogo: fuera de registro.
local venting_keywords = {
  -- Lo que no es serio ni pretende serlo. El programador está harto, lleva
  -- semanas dando vueltas a lo mismo y lo deja de cualquier manera para poder
  -- avanzar; o suelta un chiste malo; o da con un truco tan absurdo que no
  -- debería funcionar, y funciona.
  --   /XD: tres semanas con esto. Funciona. No preguntes.
  --   /XD: si lees esto, el café se ha acabado.
  --   /XD: sumar cero arregla el redondeo. No sé por qué. Nadie lo sabe.
  -- Si lo absurdo además puede romperse, es `HACK` y no esto: el XD avisa de
  -- que no es serio, no de que sea frágil.
  --
  -- Alias, cada uno con su matiz:
  --   - WTF, "what the fuck": "no entiendo por qué esto funciona".
  --   - MAGIC: "funciona, no sé por qué, mejor no tocarlo".
  --   - MEH: "está regular, ya si eso".
  XD = {
    icon = " ",
    color = "ok",
    alt = { "WTF", "MAGIC", "MEH" },
  },
}

-- Marcadores de estructura: señalan secciones del código.
local marker_keywords = {
  -- Encabezado de un grupo de cosas relacionadas.
  --   /CATEGORY: atajos de ventanas.
  CATEGORY = { icon = "", color = "type", alt = { "GROUP", "CAT", "GRP" } },

  -- Un constructor es la función que crea un valor nuevo y lo deja listo para
  -- usar: le pone su estado inicial y lo devuelve. No es exclusivo de la
  -- programación orientada a objetos; existe en cualquier lenguaje aunque no se
  -- llame así: en Lua es el típico `M.new(opts)` que devuelve una tabla, en Go
  -- `NewServer()`, en C `buffer_create()`.
  --   /CONSTRUCTOR: crea el workspace y registra sus autocomandos.
  CONSTRUCTOR = {
    icon = "",
    color = "func",
    alt = { "CONSTRUCTORS", "INIT", "INITIALIZE", "NEW" },
  },

  -- Un getter es una función que solo lee y devuelve un dato de un objeto o de
  -- un módulo, sin cambiar nada.
  --   /GETTER: accesos a la configuración.
  GETTER = {
    icon = "",
    color = "getter",
    alt = { "GETTERS", "GET", "PROPERTY", "PROPERTIES", "FETCH" },
  },

  -- Un setter es una función que cambia un dato de un objeto o de un módulo.
  --   /SETTER: cambios de la configuración.
  SETTER = {
    icon = "",
    color = "setter",
    alt = { "SETTERS", "SET", "STORE" },
  },
}

-- El plugin las quiere todas en una sola tabla. Con "error", una palabra clave
-- repetida en dos grupos falla al cargar en vez de pisar a la otra en silencio.
local keywords = vim.tbl_extend(
  "error",
  patch_keywords,
  pending_keywords,
  warning_keywords,
  info_keywords,
  venting_keywords,
  marker_keywords
)

M.opts = {
  signs = true, -- iconos en la columna de signos
  sign_priority = 8,
  keywords = keywords,
  merge_keywords = false,
  gui_style = {
    fg = "NONE", -- estilo del grupo de resaltado de primer plano
    bg = "BOLD", -- estilo del grupo de resaltado de fondo
  },
  -- Resaltado de la línea: `before` es lo que va antes de la palabra clave (los
  -- caracteres de comentario), `keyword` la palabra y `after` el texto.
  highlight = {
    multiline = true, -- el comentario sigue en las líneas siguientes
    multiline_pattern = "^.", -- patrón Lua de cada línea de continuación
    multiline_context = 10, -- líneas que se reevalúan al cambiar una
    before = "fg", -- "fg", "bg" o vacío
    keyword = "wide", -- "wide": fondo que abarca también los caracteres de alrededor
    after = "fg", -- "fg", "bg" o vacío
    -- Etiquetas delimitadas por dos puntos a ambos lados de la palabra.
    pattern = [[.*:(KEYWORDS)\s*:]],
    comments_only = false, -- también fuera de comentarios (Markdown, por ejemplo)
    max_line_len = 400, -- las líneas más largas se ignoran
    exclude = {}, -- filetypes sin resaltado
  },
  -- Cada color toma el primer plano del primer grupo de resaltado que exista y,
  -- si no existe ninguno, el hexadecimal del final.
  colors = {
    info = { "DiagnosticInfo", "#77B791" }, -- verde
    hint = { "DiagnosticHint", "#C48BEB" }, -- lila
    warning = { "DiagnosticWarn", "WarningMsg", "#EBD18A" }, -- amarillo
    error = { "DiagnosticError", "ErrorMsg", "#DE5B61" }, -- rojo
    comment = { "Comment", "#515354" }, -- gris
    ok = { "DiagnosticOk", "#24B37E" }, -- verde

    type = { "Type", "Structure", "#E69780" }, -- naranja/amarillo/azul/negro (en temas claros) [cambia mucho según el tema]

    func = { "Function", "#69C2FF" }, -- azul

    -- Hardcodeados (colores apagados para máxima compatibilidad)
    getter = { "#6b1c16" },
    setter = { "#754c1c" },
  },
  search = {
    command = "rg",
    args = {
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
    },
    -- Regex de ripgrep; `(KEYWORDS)` lo sustituye el plugin por la lista.
    pattern = [[:(KEYWORDS)\s*:]],
  },
}

local function refresh_leading_padding_highlights()
  local config = require "todo-comments.config"

  for keyword in pairs(config.options.keywords) do
    local todo_bg = vim.api.nvim_get_hl(0, { name = "TodoBg" .. keyword, link = false })

    if todo_bg.bg then
      vim.api.nvim_set_hl(0, "TodoLeadingPadding" .. keyword, {
        fg = todo_bg.bg,
        bg = todo_bg.bg,
      })
    end
  end
end

-- El primer `:` de una etiqueta (`:TODO:`) forma parte del bloque de color: en
-- la línea de la etiqueta se pinta como relleno del fondo, y en las líneas que
-- la continúan se pinta con el color del texto, igual que lo que tiene a la
-- derecha. Sin esto, esa columna quedaba sin color debajo de los dos puntos:
--
--   -- :TODO: texto
--   --  ?resto del comentario      <- la `?` quedaba fuera del bloque
--
-- Qué líneas continúan una etiqueta lo decide el plugin, y aquí se repite su
-- misma regla para no pintar una línea que él no pinta: la línea sigue si es
-- un comentario y tiene algún carácter en la columna de la palabra clave. La
-- primera que no lo cumple corta el bloque, y las de detrás ya no se pintan.

--- Marcas de la columna del `:` en las líneas dadas, que empiezan en `first`.
--- Devuelve también si la última línea deja un bloque abierto, porque entonces
--- las siguientes pueden seguir perteneciéndole.
---@param bufnr integer
---@param lines string[]
---@param first integer
---@param block? { keyword: string, start: integer, colon: integer }
---@return { row: integer, col: integer, hl: string }[] marks
---@return { keyword: string, start: integer, colon: integer }? block
local function leading_padding_marks(bufnr, lines, first, block)
  local config = require "todo-comments.config"
  local highlight = require "todo-comments.highlight"
  local options = config.options.highlight
  local marks = {}

  for offset, line in ipairs(lines) do
    local row = first + offset - 1
    -- Cuando `match` lanza (config del plugin aún sin inicializar) el pcall
    -- deja en `start` el mensaje de error; hay que comprobar `ok` primero.
    local ok, start, _, keyword = pcall(highlight.match, line)

    if ok and start then
      -- Una etiqueta nueva cierra el bloque anterior, tenga `:` delante o no.
      block = nil
      local colon = start - 2
      if colon >= 0 and line:sub(colon + 1, colon + 1) == ":" then
        keyword = config.keywords[keyword] or keyword
        marks[#marks + 1] = { row = row, col = colon, hl = "TodoLeadingPadding" .. keyword }
        block = { keyword = keyword, start = start, colon = colon }
      end
    elseif block then
      if
        options.multiline
        and highlight.is_comment(bufnr, row, block.start)
        and line:find(options.multiline_pattern, block.start)
      then
        marks[#marks + 1] = { row = row, col = block.colon, hl = "TodoFg" .. block.keyword }
      else
        block = nil
      end
    end
  end

  return marks, block
end

---@param bufnr integer
---@param first? integer
---@param last? integer
local function update_leading_padding(bufnr, first, last)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local count = vim.api.nvim_buf_line_count(bufnr)
  local context = require("todo-comments.config").options.highlight.multiline_context or 10
  first = math.max((first or 0) - context, 0)
  last = math.min((last or count) + context, count)

  -- Qué es comentario lo dice Tree-sitter, y puede que todavía no haya
  -- analizado el texto nuevo (al entrar en el buffer, nada más escribir): sin
  -- esto, las continuaciones no se verían como comentario.
  if vim.treesitter.highlighter.active[bufnr] then
    pcall(function()
      vim.treesitter.get_parser(bufnr):parse()
    end)
  end

  -- Si `first` cae en mitad de un bloque, su etiqueta está más arriba: se busca
  -- para no tratar sus líneas como sueltas.
  local highlight = require "todo-comments.highlight"
  for row = first - 1, math.max(first - 200, 0), -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local ok, start = pcall(highlight.match, line)
    if ok and start then
      first = row
      break
    end
  end

  -- Y si el último bloque sigue abierto al llegar a `last`, se sigue leyendo
  -- hasta que se cierre.
  local marks, block =
    leading_padding_marks(bufnr, vim.api.nvim_buf_get_lines(bufnr, first, last, false), first)
  while block and last < count do
    local next_last = math.min(last + 50, count)
    local more
    more, block = leading_padding_marks(
      bufnr,
      vim.api.nvim_buf_get_lines(bufnr, last, next_last, false),
      last,
      block
    )
    vim.list_extend(marks, more)
    last = next_last
  end

  vim.api.nvim_buf_clear_namespace(bufnr, leading_padding_namespace, first, last)
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(bufnr, leading_padding_namespace, mark.row, mark.col, {
      end_col = mark.col + 1,
      hl_group = mark.hl,
      priority = 501,
    })
  end
end

local function setup_leading_padding()
  refresh_leading_padding_highlights()

  local group = vim.api.nvim_create_augroup("TodoCommentsLeadingPadding", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged" }, {
    group = group,
    callback = function(args)
      update_leading_padding(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    callback = function(args)
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      update_leading_padding(args.buf, math.max(row - 1, 0), row + 2)
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = refresh_leading_padding_highlights,
  })

  update_leading_padding(vim.api.nvim_get_current_buf())
end

-- Para los specs.
M._update_leading_padding = update_leading_padding

function M.setup()
  require("todo-comments").setup(M.opts)
  vim.schedule(setup_leading_padding)
end

return M
