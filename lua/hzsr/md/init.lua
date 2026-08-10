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
--   [label](url "title") -> label
--   [label][ref]         -> label
--   `codigo`             -> codigo
--   <url>                -> url
--   **x** / *x* / __x__  -> x
--   \x                   -> x
--   [[dest|display]]     -> display
--
-- Los enlaces son atómicos: no se parten nunca, y el tokenizer tampoco los
-- parte aunque su destino o título contengan espacios.

local M = {}

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

-- Intenta parsear un enlace inline empezando en `s[i] == "["`.
--
-- Soporta: [label](dest), [label](dest "title"), [label][ref], [label][] y
-- el [label] suelto (referencia).
--
---@param s string
---@param i integer Posición del `[` de apertura.
---@return integer? label_width Ancho visible del label.
---@return integer? end_index Índice del último carácter consumido.
local function parse_link(s, i)
  local n = #s
  local j = i + 1
  local label_width = 0

  while j <= n do
    local c = s:sub(j, j)

    if c == "\\" and j < n then
      -- Escapado: `\[`, `\]`... cuenta como un carácter visible.
      label_width = label_width + 1
      j = j + 1 + char_len(s, j + 1)
    elseif c == "]" then
      local after = s:sub(j + 1, j + 1)

      if after == "(" then
        local close = s:find(")", j + 2, true)
        if close then
          return label_width, close
        end
        return nil
      end

      if after == "[" then
        local ref_end = s:find("]", j + 2, true)
        if ref_end then
          return label_width, ref_end
        end
        return nil
      end

      if after == "]" then
        -- [label][] (referencia colapsada)
        return label_width, j + 1
      end

      if after == "" or after:match "^%s$" then
        -- [label] suelto; en prosa se trata como referencia.
        return label_width, j
      end

      return nil
    else
      label_width = label_width + 1
      j = j + char_len(s, j)
    end
  end

  return nil
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
local function parse_wiki_link(s, i)
  local close = s:find("]]", i + 2, true)

  if not close then
    return nil
  end

  local inner = s:sub(i + 2, close - 1)
  local display = inner:match "^[^|]*|(.*)$" or inner
  local width = 0
  local j = 1

  while j <= #display do
    width = width + 1
    j = j + char_len(display, j)
  end

  return width, close + 1
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
      width = width + 1
      j = j + char_len(s, j)
    end

    return width, close
  end

  return nil
end

-- Intenta parsear un autolink `<url>` (sin espacios internos) en `s[i] == "<"`.
--
---@param s string
---@param i integer Posición de la apertura.
---@return integer? inner_width Ancho visible del contenido.
---@return integer? end_index Índice del último carácter consumido.
local function parse_autolink(s, i)
  local n = #s
  local j = i + 1
  local width = 0

  while j <= n do
    local c = s:sub(j, j)

    if c == ">" then
      return width, j
    end

    if c:match "%s" then
      return nil
    end

    width = width + 1
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
---@return integer
function M.visible_width(s)
  vim.validate("s", s, "string")

  local n = #s
  local i = 1
  local width = 0

  while i <= n do
    local c = s:sub(i, i)

    if c == "\\" then
      -- Escapado: `\*`, `\[`... cuenta como un carácter visible.
      i = i + 1 + char_len(s, i + 1)
      width = width + 1
    elseif c == "[" then
      local label, stop

      if s:sub(i, i + 1) == "[[" then
        label, stop = parse_wiki_link(s, i)
      end

      if not label then
        label, stop = parse_link(s, i)
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
    elseif c == "<" then
      local inner, stop = parse_autolink(s, i)
      if inner then
        width = width + inner
        i = stop + 1
      else
        width = width + 1
        i = i + 1
      end
    else
      width = width + 1
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
        _, stop = parse_wiki_link(s, pos)
      end

      if not stop then
        _, stop = parse_link(s, pos)
      end

      pos = (stop and stop + 1) or pos + 1
    elseif c == "`" then
      local _, stop = parse_code_span(s, pos)
      pos = (stop and stop + 1) or pos + 1
    elseif c == "<" then
      local _, stop = parse_autolink(s, pos)
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
local function wrap_segment(text, width)
  local lines = {}
  local cur = ""
  local cur_width = 0
  local pos = 1

  while true do
    local word, next_pos = next_word(text, pos)

    if not word then
      break
    end

    local word_width = M.visible_width(word)

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
---@return string Párrafo envuelto, con `\n` entre líneas.
function M.wrap_paragraph(text, width)
  vim.validate("text", text, "string")
  vim.validate("width", width, "number")

  local segments = vim.split(text, "\n", { plain = true })
  local out = {}

  for index, segment in ipairs(segments) do
    -- Un `\` final de segmento es el marcador del salto duro que ya añadió
    -- el llamante; se descarta aquí para no duplicarlo al re-emitir.
    local wrapped = wrap_segment(segment:gsub("\\$", ""), width)

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
