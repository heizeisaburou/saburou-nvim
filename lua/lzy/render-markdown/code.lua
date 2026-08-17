-- Bloques de código que no se ven: vacíos y sin cerrar.
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
-- Detectarlos es mirar los hijos del nodo:
--   * sin `code_fence_content` -> el fence está vacío.
--   * con un solo `fenced_code_block_delimiter` -> nunca se cerró.

local M = {}

M.empty_highlight = "RenderMarkdownCodeEmpty"
M.unclosed_highlight = "RenderMarkdownCodeUnclosed"

M.empty_text = "bloque de código vacío"
M.unclosed_text = "bloque de código sin cerrar"

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

---@param ctx render.md.handler.Context
---@return lzy.render_markdown.CodeFlag[]
local function flags(ctx)
  local result = {}

  for _, node in block_query:iter_captures(ctx.root, ctx.buf) do
    local delimiters, content, language = parts(node)
    local opening = delimiters[1]

    if opening then
      local row, col = opening:range()
      local highlight, text
      if #delimiters < 2 then
        highlight, text = M.unclosed_highlight, M.unclosed_text
      elseif not content then
        highlight, text = M.empty_highlight, M.empty_text
      end

      if highlight then
        -- Un fence vacío tiene dos filas que rescatar; uno sin cerrar, solo la
        -- suya: el resto del bloque ya se ve (de más), no hace falta tocarlo.
        local rows = { row }
        if #delimiters > 1 then
          rows[#rows + 1] = (delimiters[2]:range())
        end

        result[#result + 1] = {
          row = row,
          col = col,
          rows = rows,
          language = language and vim.treesitter.get_node_text(language, ctx.buf) or nil,
          highlight = highlight,
          text = text,
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
    return (" ▲ %s · %s "):format(flag.language, flag.text)
  end
  return (" ▲ %s "):format(flag.text)
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

--- Marcas para los fences vacíos o sin cerrar, y las filas donde el render del
--- plugin (el `conceal_lines` que las hace desaparecer y su etiqueta de
--- lenguaje) hay que descartar para que se vean, cada una con la columna donde
--- empieza su ```.
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
