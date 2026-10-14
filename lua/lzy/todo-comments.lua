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
-- Van agrupadas por para qué sirven y, dentro de cada grupo, de más a menos
-- urgente. Lo que importa es elegir bien entre las que se parecen, así que cada
-- una dice cuándo usarla y cuándo usar otra.
--
-- `merge_keywords` está desactivado: el plugin trae sus propias palabras y,
-- fusionadas con estas, INFO acababa resolviéndose como alias de NOTE.
-- Aquí están todas las que existen.
--
-- La guía completa, con cómo elegir entre las que se parecen, está en
-- `docs/Etiquetas de comentarios.md`. Si cambia una etiqueta, cambian las dos.
local keywords = {
  -- --- Pendiente: trabajo que falta -------------------------------------------

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
    alt = { "QUICKFIX", "UGLY" },
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

  -- --- Avisos: cuidado al tocar esto ------------------------------------------

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

  -- Un hack es un truco: conseguir que algo funcione por un camino que el
  -- sistema no tenía previsto. No tiene nada que ver con atacar ni vulnerar
  -- nada; la palabra viene de la jerga de programadores, donde un hack es una
  -- solución ingeniosa. Aquí marca uno que se apoya en algo que no debería (un
  -- detalle interno de un plugin, un comportamiento no documentado), así que
  -- puede dejar de funcionar sin aviso.
  --   /HACK: se lee un campo privado de render-markdown.
  HACK = { icon = " ", color = "warning" },

  -- Parche para un fallo de una dependencia (un plugin, una herramienta, el
  -- propio Neovim) que se quita cuando lo arreglen ellos. "Upstream" es el
  -- proyecto original del que dependemos, "río arriba". Conviene enlazar la
  -- incidencia y decir cuándo se puede quitar. Un workaround es justo eso: un
  -- rodeo para esquivar un fallo que no es nuestro.
  --   /UPSTREAM: render-markdown#123; quitar cuando salga la 8.14.
  -- No es `HACK`: el hack es un truco nuestro que puede romperse; esto es
  -- culpa de otro y tiene fecha de caducidad.
  UPSTREAM = {
    icon = " ",
    color = "warning",
    alt = { "WORKAROUND" },
  },

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

  -- --- Información: contexto, sin trabajo pendiente ---------------------------

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
  --   /LIMIT: los bloques de código sangrados sin delimitador siguen pasando a
  --   tabs; sin un parser no se distinguen de una lista.
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

  -- --- Desahogo: fuera de registro -------------------------------------------

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

  -- --- Marcadores de estructura: señalan secciones del código -----------------

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

---@param bufnr integer
---@param first? integer
---@param last? integer
local function update_leading_padding(bufnr, first, last)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local config = require "todo-comments.config"
  local highlight = require "todo-comments.highlight"
  first = first or 0
  last = last or vim.api.nvim_buf_line_count(bufnr)

  vim.api.nvim_buf_clear_namespace(bufnr, leading_padding_namespace, first, last)

  local lines = vim.api.nvim_buf_get_lines(bufnr, first, last, false)
  for offset, line in ipairs(lines) do
    local ok, start, _, keyword = pcall(highlight.match, line)
    -- Cuando `match` lanza (config del plugin aún sin inicializar) el pcall
    -- deja en `start` el mensaje de error; hay que comprobar `ok` primero.
    local colon_col = ok and start and start - 2 or -1

    if ok and keyword and colon_col >= 0 and line:sub(colon_col + 1, colon_col + 1) == ":" then
      keyword = config.keywords[keyword] or keyword
      vim.api.nvim_buf_set_extmark(
        bufnr,
        leading_padding_namespace,
        first + offset - 1,
        colon_col,
        {
          end_col = colon_col + 1,
          hl_group = "TodoLeadingPadding" .. keyword,
          priority = 501,
        }
      )
    end
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

function M.setup()
  require("todo-comments").setup(M.opts)
  vim.schedule(setup_leading_padding)
end

return M
