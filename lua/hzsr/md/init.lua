-- hzsr.md

-- Utilidades de texto Markdown.
--
-- La pieza central es `hzsr.md.wrap_paragraph`: un re-envolvido de párrafos de
-- prosa que mide el ancho "visible" del texto en lugar del ancho bruto.
--
-- El problema que resuelve: Prettier y mdformat cuentan TODO el markup de un
-- enlace (`[label](https://url-larga...)`) al calcular el ancho de línea, así
-- que una URL larga arrastra el enlace a su propia línea aunque el texto que
-- se ve sea corto. Aquí cada palabra se mide con el markup inline descontado:
--
--   [label](url "title") -> icono + label
--   [label][ref]         -> icono + label
--   `codigo`             -> codigo
--   <url>                -> icono + url
--   **x** / *x* / __x__  -> x
--   \x                   -> x
--   [[dest|display]]     -> icono + display
--   ||spoiler||          -> indicador compacto de spoiler
--
-- Los enlaces son atómicos: no se parten nunca, y el tokenizer tampoco los
-- parte aunque su destino o título contengan espacios.

local M = {}

---@class hzsr.md.WidthOpts
---@field bufnr? integer Buffer del que obtener la configuración y definiciones.
---@field icons? boolean Incluye los iconos virtuales de render-markdown (default true).

-- -----------------------------------------------------------------------------
-- Parsing inline
-- -----------------------------------------------------------------------------

-- Longitud en bytes del carácter UTF-8 que empieza en `s[i]`. ASCII → 1.
--
---@param s string
---@param i integer
---@return integer
local function char_len(s, i)
  local b = s:byte(i)

  if not b or b < 0x80 then
    return 1
  end

  if b >= 0xF0 then
    return 4
  end

  if b >= 0xE0 then
    return 3
  end

  if b >= 0xC0 then
    return 2
  end

  return 1
end

---@param s string
---@param i integer
---@return integer
local function char_width(s, i)
  local length = char_len(s, i)
  return vim.fn.strdisplaywidth(s:sub(i, i + length - 1))
end

---@param kind "wiki"|"link"|"image"|"email"
---@param opts hzsr.md.WidthOpts|nil
---@param destination string|nil
---@return integer
local function icon_width(kind, opts, destination)
  if opts and opts.icons == false then
    return 0
  end
  return require("lzy.render-markdown.links").icon_width(kind, opts and opts.bufnr, destination)
end

-- Intenta parsear un enlace inline empezando en `s[i] == "["`.
--
-- Soporta: [label](dest), [label](dest "title"), [label][ref], [label][] y
-- el [label] suelto (referencia).
--
---@param s string
---@param i integer Posición del `[` de apertura.
---@param opts hzsr.md.WidthOpts|nil
---@return integer? label_width Ancho visible del label.
---@return integer? end_index Índice del último carácter consumido.
---@return "inline"|"full_reference"|"collapsed_reference"|"shortcut_reference"|nil kind
---@return string? destination_or_id
local function parse_link(s, i, opts)
  local n = #s
  local j = i + 1
  local label_width = 0
  -- Índice del `)` de una imagen que empieza justo al principio del label. Si
  -- al llegar al cierre resulta que la imagen era TODO el label, estamos ante
  -- un enlace-imagen (`[![alt](img)](url)`, el patrón de los badges): una sola
  -- cosa, con un solo icono, el de imagen. Ver `linked_image` en
  -- lzy.render-markdown.links.
  local image_end

  while j <= n do
    local c = s:sub(j, j)

    if c == "\\" and j < n then
      -- Escapado: `\[`, `\]`... cuenta como un carácter visible.
      label_width = label_width + char_width(s, j + 1)
      j = j + 1 + char_len(s, j + 1)
    elseif c == "!" and s:sub(j + 1, j + 1) == "[" and s:sub(j + 2, j + 2) ~= "[" then
      -- Una imagen dentro del label: su `]` no cierra el enlace de fuera.
      local inner, stop = parse_link(s, j + 1, {
        bufnr = opts and opts.bufnr,
        icons = false,
      })
      if inner then
        if j == i + 1 then
          image_end = stop
        end
        label_width = label_width + inner + icon_width("image", opts)
        j = stop + 1
      else
        label_width = label_width + 1
        j = j + 1
      end
    elseif c == "]" then
      local after = s:sub(j + 1, j + 1)

      if after == "(" then
        local close = s:find(")", j + 2, true)
        if close then
          local body = vim.trim(s:sub(j + 2, close - 1))
          local destination = body:match "^<([^>]*)>" or body:match "^([^%s]+)"
          -- El icono de imagen ya está contado; el enlace no añade otro.
          local icon = image_end == j - 1 and 0 or icon_width("link", opts, destination)
          return label_width + icon, close, "inline", destination
        end
        return nil
      end

      if after == "[" then
        local ref_end = s:find("]", j + 2, true)
        if ref_end then
          local id = s:sub(j + 2, ref_end - 1)
          local kind = id == "" and "collapsed_reference" or "full_reference"
          if id == "" then
            id = s:sub(i + 1, j - 1)
          end
          local has_icon = kind == "full_reference"
            or not opts
            or not opts.bufnr
            or require("lzy.render-markdown.links").has_definition(opts.bufnr, id)
          return label_width + (has_icon and icon_width("link", opts) or 0), ref_end, kind, id
        end
        return nil
      end

      if after == "]" then
        -- [label][] (referencia colapsada)
        local id = s:sub(i + 1, j - 1)
        local has_icon = not opts
          or not opts.bufnr
          or require("lzy.render-markdown.links").has_definition(opts.bufnr, id)
        return label_width + (has_icon and icon_width("link", opts) or 0),
          j + 1,
          "collapsed_reference",
          id
      end

      if after == "" or after:match "^%s$" then
        -- [label] suelto; en prosa se trata como referencia.
        local id = s:sub(i + 1, j - 1)
        local has_icon = not opts
          or not opts.bufnr
          or require("lzy.render-markdown.links").has_definition(opts.bufnr, id)
        return label_width + (has_icon and icon_width("link", opts) or 0),
          j,
          "shortcut_reference",
          id
      end

      return nil
    else
      label_width = label_width + char_width(s, j)
      j = j + char_len(s, j)
    end
  end

  return nil
end

-- Una definición se renderiza como `icono + label + (title)`: el destino es
-- operativo, pero no forma parte de la vista. Este parser pequeño replica ese
-- contrato para que el formateador mida lo mismo que Neovim.
--
---@param s string
---@param opts hzsr.md.WidthOpts|nil
---@return integer|nil
local function definition_width(s, opts)
  if s:sub(1, 1) ~= "[" then
    return nil
  end

  local label_width = 0
  local close = 2
  while close <= #s do
    local char = s:sub(close, close)
    if char == "\\" and close < #s then
      label_width = label_width + char_width(s, close + 1)
      close = close + 1 + char_len(s, close + 1)
    elseif char == "]" then
      break
    else
      label_width = label_width + char_width(s, close)
      close = close + char_len(s, close)
    end
  end
  if close > #s or s:sub(close + 1, close + 1) ~= ":" then
    return nil
  end

  local rest = vim.trim(s:sub(close + 2))
  local destination
  if rest:sub(1, 1) == "<" then
    local destination_end = rest:find(">", 2, true)
    if not destination_end then
      return nil
    end
    destination = rest:sub(2, destination_end - 1)
    rest = vim.trim(rest:sub(destination_end + 1))
  else
    destination, rest = rest:match("^(%S+)%s*(.*)$")
    if not destination then
      return nil
    end
  end

  local width = icon_width("link", opts, destination) + label_width
  if rest == "" then
    return width
  end

  local opening, closing = rest:sub(1, 1), rest:sub(-1)
  if not (
    (opening == '"' and closing == '"')
    or (opening == "'" and closing == "'")
    or (opening == "(" and closing == ")")
  ) then
    return nil
  end
  local title = vim.trim(rest:sub(2, -2)):gsub("%s+", " "):gsub("\\([%p])", "%1")
  return width + (title ~= "" and vim.fn.strdisplaywidth(" (" .. title .. ")") or 0)
end

-- Intenta parsear un wiki-link `[[dest|display]]` empezando en `s[i..i+1] ==
-- "[["`.
--
-- Solo cuenta el texto visible: el contenido entero si no hay `|`, o la parte
-- posterior al primer `|` si lo hay.
--
---@param s string
---@param i integer Posición del `[[` de apertura.
---@return integer? display_width Ancho visible del display.
---@return integer? end_index Índice del último carácter consumido.
local function parse_wiki_link(s, i, opts)
  local close = s:find("]]", i + 2, true)

  if not close then
    return nil
  end

  local inner = s:sub(i + 2, close - 1)
  local display = inner:match "^[^|]*|(.*)$" or inner
  local width = 0
  local j = 1

  while j <= #display do
    width = width + char_width(display, j)
    j = j + char_len(display, j)
  end

  return width + icon_width("wiki", opts, inner:match "^[^|]*"), close + 1
end

-- Intenta parsear un code span `` `code` `` empezando en `s[i] == "`"`.
--
---@param s string
---@param i integer Posición de la apertura.
---@return integer? inner_width Ancho visible del contenido.
---@return integer? end_index Índice del último carácter consumido.
local function parse_code_span(s, i)
  local close = s:find("`", i + 1, true)

  if close then
    local width = 0
    local j = i + 1

    while j < close do
      width = width + char_width(s, j)
      j = j + char_len(s, j)
    end

    return width, close
  end

  return nil
end

-- Un spoiler es una unidad atómica aunque contenga espacios. Su medida es la
-- del indicador estable que se muestra cuando el cursor está fuera.
---@param s string
---@param i integer
---@return integer? display_width
---@return integer? end_index
local function parse_spoiler(s, i)
  if s:sub(i, i + 1) ~= "||" then
    return nil
  end
  local close = s:find("||", i + 2, true)
  if not close or close == i + 2 then
    return nil
  end
  return require("lzy.render-markdown.spoilers").inline_width(), close + 1
end

-- Intenta parsear un autolink `<url>` (sin espacios internos) en `s[i] == "<"`.
--
---@param s string
---@param i integer Posición de la apertura.
---@return integer? inner_width Ancho visible del contenido.
---@return integer? end_index Índice del último carácter consumido.
local function parse_autolink(s, i, opts)
  local n = #s
  local j = i + 1
  local width = 0

  while j <= n do
    local c = s:sub(j, j)

    if c == ">" then
      local destination = s:sub(i + 1, j - 1)
      local kind = destination:find("@", 1, true) and not destination:find(":", 1, true) and "email"
        or "link"
      return width + icon_width(kind, opts, destination), j
    end

    if c:match "%s" then
      return nil
    end

    width = width + char_width(s, j)
    j = j + char_len(s, j)
  end

  return nil
end

-- -----------------------------------------------------------------------------
-- Medición
-- -----------------------------------------------------------------------------

-- Ancho "visible" de una palabra: descuenta el markup inline (enlaces, code
-- spans, autolinks, énfasis/negrita, escapes) manteniendo el resto.
--
---@param s string
---@param opts hzsr.md.WidthOpts|nil
---@return integer
function M.visible_width(s, opts)
  vim.validate("s", s, "string")

  local rendered_definition = definition_width(s, opts)
  if rendered_definition then
    return rendered_definition
  end

  local n = #s
  local i = 1
  local width = 0

  while i <= n do
    local c = s:sub(i, i)

    if c == "\\" then
      -- Escapado: `\*`, `\[`... cuenta como un carácter visible.
      local escaped = i + 1
      width = width + char_width(s, escaped)
      i = escaped + char_len(s, escaped)
    elseif c == "!" and s:sub(i + 1, i + 1) == "[" then
      local label, stop
      if s:sub(i + 1, i + 2) == "[[" then
        label, stop = parse_wiki_link(s, i + 1, opts)
      else
        label, stop = parse_link(s, i + 1, {
          bufnr = opts and opts.bufnr,
          icons = false,
        })
        if label then
          label = label + icon_width("image", opts)
        end
      end
      if label then
        width = width + label
        i = stop + 1
      else
        width = width + 1
        i = i + 1
      end
    elseif c == "[" then
      local label, stop

      if s:sub(i, i + 1) == "[[" then
        label, stop = parse_wiki_link(s, i, opts)
      end

      if not label then
        label, stop = parse_link(s, i, opts)
      end

      if label then
        width = width + label
        i = stop + 1
      else
        width = width + 1
        i = i + 1
      end
    elseif c == "`" then
      local inner, stop = parse_code_span(s, i)
      if inner then
        width = width + inner
        i = stop + 1
      else
        width = width + 1
        i = i + 1
      end
    elseif c == "|" then
      local spoiler, stop = parse_spoiler(s, i)
      if spoiler then
        width = width + spoiler
        i = stop + 1
      else
        width = width + 1
        i = i + 1
      end
    elseif c == "<" then
      local inner, stop = parse_autolink(s, i, opts)
      if inner then
        width = width + inner
        i = stop + 1
      else
        width = width + 1
        i = i + 1
      end
    else
      width = width + char_width(s, i)
      i = i + char_len(s, i)
    end
  end

  -- Marcadores de énfasis/negrita emparejados en los extremos de la palabra.
  -- La comprobación es conservadora: sólo cuando la palabra empieza Y termina
  -- con el mismo marcador, para no restar `_`/`*` con otro significado
  -- (p. ej. `foo_bar`, `10 * 5`).
  if #s >= 4 and s:sub(1, 2) == "**" and s:sub(-2) == "**" then
    width = width - 4
  elseif #s >= 4 and s:sub(1, 2) == "__" and s:sub(-2) == "__" then
    width = width - 4
  elseif #s >= 2 and s:sub(1, 1) == "*" and s:sub(-1) == "*" then
    width = width - 2
  elseif #s >= 2 and s:sub(1, 1) == "_" and s:sub(-1) == "_" then
    width = width - 2
  end

  return math.max(0, width)
end

-- -----------------------------------------------------------------------------
-- Tokenización
-- -----------------------------------------------------------------------------

-- Devuelve la siguiente palabra de `s` a partir de `pos`, junto con la
-- posición donde empieza la siguiente.
--
-- Las palabras se separan por espacios, pero los enlaces, code spans y
-- autolinks se consumen completos: un destino o título con espacios no parte
-- la palabra.
--
---@param s string
---@param pos integer
---@return string? word
---@return integer? next_pos
local function next_word(s, pos)
  local n = #s

  while pos <= n and s:sub(pos, pos):match "%s" do
    pos = pos + 1
  end

  if pos > n then
    return nil
  end

  local start = pos

  while pos <= n do
    local c = s:sub(pos, pos)

    if c:match "%s" then
      break
    end

    if c == "\\" then
      pos = pos + 1 + char_len(s, pos + 1)
    elseif c == "[" then
      local _, stop

      if s:sub(pos, pos + 1) == "[[" then
        _, stop = parse_wiki_link(s, pos, { icons = false })
      end

      if not stop then
        _, stop = parse_link(s, pos, { icons = false })
      end

      pos = (stop and stop + 1) or pos + 1
    elseif c == "`" then
      local _, stop = parse_code_span(s, pos)
      pos = (stop and stop + 1) or pos + 1
    elseif c == "<" then
      local _, stop = parse_autolink(s, pos, { icons = false })
      pos = (stop and stop + 1) or pos + 1
    elseif c == "|" then
      local _, stop = parse_spoiler(s, pos)
      pos = (stop and stop + 1) or pos + 1
    else
      pos = pos + 1
    end
  end

  return s:sub(start, pos - 1), pos
end

-- -----------------------------------------------------------------------------
-- Envolvido
-- -----------------------------------------------------------------------------

-- Envuelve un segmento de prosa (sin saltos duros) al ancho visible dado.
--
-- Los enlaces se tratan como palabras indivisibles: si un enlace no cabe, va
-- solo a la siguiente línea, nunca se parte.
--
---@param text string
---@param width integer
---@return string[]
local function wrap_segment(text, width, opts)
  local lines = {}
  local cur = ""
  local cur_width = 0
  local pos = 1

  while true do
    local word, next_pos = next_word(text, pos)

    if not word then
      break
    end

    local word_width = M.visible_width(word, opts)

    if cur ~= "" and cur_width + 1 + word_width <= width then
      cur = cur .. " " .. word
      cur_width = cur_width + 1 + word_width
    else
      if cur ~= "" then
        lines[#lines + 1] = cur
      end
      cur = word
      cur_width = word_width
    end

    pos = next_pos or pos
  end

  if cur ~= "" then
    lines[#lines + 1] = cur
  end

  return lines
end

-- Envuelve un párrafo completo (ya unido en una sola línea lógica) al ancho
-- visible dado.
--
-- `text` puede contener `\n` para marcar saltos de línea duros: cada segmento
-- se envuelve por separado y su última línea termina en `\` (la convención de
-- Prettier para hard breaks).
--
---@param text string
---@param width integer
---@param opts hzsr.md.WidthOpts|nil
---@return string Párrafo envuelto, con `\n` entre líneas.
function M.wrap_paragraph(text, width, opts)
  vim.validate("text", text, "string")
  vim.validate("width", width, "number")

  local segments = vim.split(text, "\n", { plain = true })
  local out = {}

  for index, segment in ipairs(segments) do
    -- Un `\` final de segmento es el marcador del salto duro que ya añadió
    -- el llamante; se descarta aquí para no duplicarlo al re-emitir.
    local wrapped = wrap_segment(segment:gsub("\\$", ""), width, opts)

    for _, line in ipairs(wrapped) do
      out[#out + 1] = line
    end

    if index < #segments and #out > 0 then
      out[#out] = out[#out] .. "\\"
    end
  end

  return table.concat(out, "\n")
end

return M
