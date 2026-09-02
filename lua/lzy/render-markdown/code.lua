-- Bloques de código que no se ven: vacíos, sin cerrar y sin lenguaje.
--
-- Con los delimitadores ocultos (`code.conceal_delimiters`), un fence sin
-- cuerpo desaparece del todo: render-markdown.nvim le pone `conceal_lines` a
-- las dos líneas de ``` y, como no hay contenido que pintar de fondo, en
-- pantalla no queda ni una fila. Lo mismo pasa con un fence al que le falta el
-- cierre: la apertura se oculta y lo que viene detrás se pinta como si fuera
-- código, sin ninguna pista de que el bloque nunca se cerró.
--
-- Los dos casos son trampas de edición -- bloques abandonados que nadie ve, y
-- texto normal que queda dentro de un bloque -- y encima falsean lo que
-- entiende cualquier cosa que lea el documento: el propio parser empareja los
-- ``` de otra manera, así que hasta la copia de un bloque de más abajo se
-- lleva texto de fuera. Así que en vez de ocultarlos, se marcan: la fila
-- vuelve a existir, con una banda de color y una etiqueta que dice qué pasa.
--
-- El tercer caso no es un error, pero se pierde igual: un fence sin lenguaje
-- no recibe la cabecera del plugin -- esa se dibuja a partir del nombre del
-- lenguaje -- y su apertura se oculta como cualquier otro borde. El cuerpo
-- queda flotando sobre el fondo del código, sin nada que diga dónde empieza el
-- bloque ni dónde acaba el párrafo anterior. Se le pone una cabecera propia,
-- neutra, que dice lo único que hay que decir: es texto plano.
--
-- Detectarlos es mirar los hijos del nodo:
--   * sin `code_fence_content`, o con un cuerpo en blanco -> el fence está vacío.
--   * con un solo `fenced_code_block_delimiter` -> nunca se cerró.
--   * sin `language` en el `info_string` -> es texto plano.
--
-- Lo de "en blanco" hay que medirlo con cuidado: un cuerpo de una sola línea
-- vacía no es un `code_fence_content` que falte, es uno lleno de nada, y
-- dentro de una cita las filas llevan delante los `>` de la cita, que no son
-- contenido. Por eso se mira cada fila a partir de la columna donde empieza el
-- ```: lo de delante es el prefijo de la cita y lo de detrás, el código -- así
-- un `>` escrito dentro del bloque sigue contando como contenido.

local M = {}

M.empty_highlight = "RenderMarkdownCodeEmpty"
M.unclosed_highlight = "RenderMarkdownCodeUnclosed"
M.plain_highlight = "RenderMarkdownCodePlain"

M.empty_text = "bloque de código vacío"
M.unclosed_text = "bloque de código sin cerrar"
M.plain_text = "texto plano"

-- Los dos primeros son avisos y lo dicen; el tercero solo pone nombre a lo que
-- ya hay, así que va sin marca, igual que la cabecera de lenguaje del plugin.
M.warning_marker = "▲ "

-- Por encima de la banda de fondo del plugin (140) y de su etiqueta de
-- lenguaje (4096), que en estas filas se descarta.
M.priority = 4200

local block_query = vim.treesitter.query.parse("markdown", "(fenced_code_block) @block")

---@class lzy.render_markdown.CodeFlag
---@field row integer fila del delimitador de apertura (0-based)
---@field col integer columna donde empieza el ``` (0-based)
---@field rows integer[] filas cuyo render del plugin hay que descartar
---@field language string|?
---@field highlight string
---@field text string
---@field marker string prefijo de la etiqueta: aviso o nada

---@param node TSNode
---@return TSNode[] delimiters
---@return TSNode|? content
---@return TSNode|? language
local function parts(node)
  local delimiters, content, language = {}, nil, nil
  for child in node:iter_children() do
    local kind = child:type()
    if kind == "fenced_code_block_delimiter" then
      delimiters[#delimiters + 1] = child
    elseif kind == "code_fence_content" then
      content = child
    elseif kind == "info_string" then
      for info_child in child:iter_children() do
        if info_child:type() == "language" then
          language = info_child
        end
      end
    end
  end
  return delimiters, content, language
end

--- ¿Esta fila del cuerpo está en blanco?
---
--- Solo cuenta como contenido lo que hay a partir de la columna donde empieza
--- el ```. Lo de delante es el prefijo del bloque que contiene al fence -- los
--- `>` de una cita o la sangría de una lista -- y no es código. Un `>` escrito
--- ya dentro del bloque queda detrás de esa columna, así que sí cuenta.
---@param line string
---@param col integer columna donde empieza el ``` (0-based)
---@return boolean
local function is_blank(line, col)
  if not line:sub(1, col):match "^[%s>]*$" then
    return false
  end
  return line:sub(col + 1):match "^%s*$" ~= nil
end

--- Un fence está vacío si no tiene cuerpo o si su cuerpo son solo blancos: un
--- salto de línea suelto sí produce un `code_fence_content`, pero no es nada.
---@param ctx render.md.handler.Context
---@param content TSNode|?
---@param col integer
---@return boolean
local function is_empty(ctx, content, col)
  if not content then
    return true
  end

  local start_row, _, end_row, end_col = content:range()
  local lines = vim.api.nvim_buf_get_lines(ctx.buf, start_row, end_row + 1, false)

  for offset, line in ipairs(lines) do
    -- La última fila del cuerpo llega solo hasta donde arranca el cierre: lo
    -- que va detrás es el propio ``` -- y dentro de una cita, delante va el
    -- `>` que la continúa, que tampoco es cuerpo.
    if start_row + offset - 1 == end_row then
      line = line:sub(1, end_col)
    end
    if not is_blank(line, col) then
      return false
    end
  end
  return true
end

---@param ctx render.md.handler.Context
---@return lzy.render_markdown.CodeFlag[]
local function flags(ctx)
  local result = {}

  for _, node in block_query:iter_captures(ctx.root, ctx.buf) do
    local delimiters, content, language = parts(node)
    local opening = delimiters[1]

    if opening then
      local row, col = opening:range()
      local highlight, text, marker
      if #delimiters < 2 then
        highlight, text, marker = M.unclosed_highlight, M.unclosed_text, M.warning_marker
      elseif is_empty(ctx, content, col) then
        highlight, text, marker = M.empty_highlight, M.empty_text, M.warning_marker
      elseif not language then
        highlight, text, marker = M.plain_highlight, M.plain_text, ""
      end

      if highlight then
        -- Un fence vacío tiene dos filas que rescatar; uno sin cerrar, solo la
        -- suya: el resto del bloque ya se ve (de más), no hace falta tocarlo.
        -- Y uno sin lenguaje, tampoco: su cuerpo ya lleva el fondo del plugin y
        -- su cierre se oculta igual que el de cualquier bloque con lenguaje.
        local rows = { row }
        if highlight == M.empty_highlight and #delimiters > 1 then
          rows[#rows + 1] = (delimiters[2]:range())
        end

        result[#result + 1] = {
          row = row,
          col = col,
          rows = rows,
          language = language and vim.treesitter.get_node_text(language, ctx.buf) or nil,
          highlight = highlight,
          text = text,
          marker = marker,
        }
      end
    end
  end

  return result
end

---@param bufnr integer
---@param row integer
---@return integer
local function line_length(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  return line and #line or 0
end

---@param flag lzy.render_markdown.CodeFlag
---@return string
local function label(flag)
  if flag.language and flag.language ~= "" then
    return (" %s%s · %s "):format(flag.marker, flag.language, flag.text)
  end
  return (" %s%s "):format(flag.marker, flag.text)
end

---@param ctx render.md.handler.Context
---@param flag lzy.render_markdown.CodeFlag
---@param marks render.md.Mark[]
local function flag_marks(ctx, flag, marks)
  for _, row in ipairs(flag.rows) do
    -- La banda es lo que devuelve la fila a la pantalla, así que se queda
    -- puesta en todos los modos y también con el cursor encima.
    marks[#marks + 1] = {
      modes = { "i" },
      conceal = false,
      start_row = row,
      start_col = flag.col,
      opts = {
        end_row = row,
        end_col = math.max(line_length(ctx.buf, row), flag.col),
        hl_group = flag.highlight,
        hl_eol = true,
        hl_mode = "combine",
        priority = M.priority,
      },
    }
  end

  -- La etiqueta sí es un adorno encima del texto real: con el cursor en la
  -- línea estorbaría para editar los ``` , así que ahí se quita (anti-conceal)
  -- y queda la banda sola.
  marks[#marks + 1] = {
    modes = { "i" },
    conceal = true,
    start_row = flag.row,
    start_col = flag.col,
    opts = {
      virt_text = { { label(flag), flag.highlight } },
      virt_text_pos = "overlay",
      priority = M.priority + 1,
    },
  }
end

--- Marcas para los fences vacíos, sin cerrar o sin lenguaje, y las filas donde
--- el render del plugin (el `conceal_lines` que las hace desaparecer y su
--- etiqueta de lenguaje) hay que descartar para que se vean, cada una con la
--- columna donde empieza su ```.
---@param ctx render.md.handler.Context
---@return render.md.Mark[] marks
---@return table<integer, integer> hidden_rows fila -> columna del delimitador
function M.parse_markdown(ctx)
  local marks, hidden_rows = {}, {}

  for _, flag in ipairs(flags(ctx)) do
    flag_marks(ctx, flag, marks)
    for _, row in ipairs(flag.rows) do
      hidden_rows[row] = flag.col
    end
  end

  return marks, hidden_rows
end

--- ¿Esta marca del plugin es la que deja la fila invisible?
---
--- Solo lo son las suyas sobre el propio ```: la línea entera oculta y la
--- etiqueta de lenguaje que iría donde ahora va la nuestra. Lo que decore la
--- fila por delante -- la barra `▋` de una cita, sin ir más lejos -- se queda.
---@param mark render.md.Mark
---@param hidden_rows table<integer, integer>
---@return boolean
function M.hides_row(mark, hidden_rows)
  local col = hidden_rows[mark.start_row]
  if not col then
    return false
  end
  return mark.opts.conceal_lines ~= nil
    or (mark.opts.virt_text ~= nil and mark.start_col == col)
end

return M
