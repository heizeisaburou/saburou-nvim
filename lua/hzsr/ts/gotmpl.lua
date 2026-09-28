-- hzsr.ts.gotmpl

local M = {}

-- Predicado y directivas que necesita `after/queries/gotmpl/injections.scm`.
--
-- La gramática de `gotmpl` sólo parsea las acciones (`{{ … }}`) y mete todo lo
-- demás en nodos `text` opacos: ni el marcado ni el frontmatter tienen nodo
-- propio. Para inyectar `html` en el cuerpo y `yaml` en la cabecera hay que
-- recortar a mano la región de esos `text`, y el recorte no se puede expresar
-- con `#offset!` porque el frontmatter no mide siempre lo mismo.
--
-- El delimitador es sólo `---`, que es lo que usan los generadores de sitios
-- estáticos con plantillas Go. TOML (`+++`) queda fuera a propósito: no hay
-- parser de TOML garantizado en esta configuración.

local DELIMITER = "---"

-- Opciones de registro. `all = true` hace que `match` guarde listas de nodos.
local REGISTER_OPTS = { force = true, all = true }

--- Lee una línea del búfer.
---
--- @param bufnr integer
--- @param row integer Fila 0-indexada.
--- @return string line Cadena vacía si la fila no existe.
local function line_at(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
end

--- Localiza el `---` de cierre del frontmatter dentro de un nodo `text`.
---
--- Sólo reconoce el frontmatter si el nodo abre el búfer (fila 0, columna 0) y la
--- primera línea es exactamente el delimitador. Así un `---` suelto en medio de
--- la plantilla (un `<hr>` escrito a mano, una lista YAML incrustada) nunca se
--- confunde con una cabecera.
---
--- @param node TSNode Nodo `text` a inspeccionar.
--- @param bufnr integer
--- @return integer|nil close_row Fila del `---` de cierre, o `nil` si el nodo no
---   lleva un frontmatter cerrado que empiece el búfer.
local function close_row(node, bufnr)
  local start_row, start_col, end_row = node:range()

  if start_row ~= 0 or start_col ~= 0 or line_at(bufnr, 0) ~= DELIMITER then
    return nil
  end

  for row = 1, end_row do
    if line_at(bufnr, row) == DELIMITER then
      return row
    end
  end

  return nil
end

--- Devuelve el único nodo capturado por un predicado o directiva.
---
--- @param match table<integer, TSNode[]>
--- @param capture_id integer
--- @return TSNode|nil
local function captured(match, capture_id)
  local nodes = match[capture_id]

  return nodes and nodes[1] or nil
end

--- Fija la región de una captura.
---
--- @param metadata table
--- @param capture_id integer
--- @param range integer[] `{ start_row, start_col, end_row, end_col }`
local function set_range(metadata, capture_id, range)
  metadata[capture_id] = metadata[capture_id] or {}
  metadata[capture_id].range = range
end

--- Cierto sólo para el nodo `text` que lleva el frontmatter del búfer.
---
--- Descartar aquí la match, y no dejar que la directiva devuelva una región
--- vacía, evita que se cree un árbol de `yaml` inútil.
---
--- @return boolean
local function is_frontmatter(match, _, bufnr, pred)
  local node = captured(match, pred[2])

  return node ~= nil and close_row(node, bufnr) ~= nil
end

--- Recorta la captura al bloque del frontmatter, delimitadores incluidos.
---
--- Incluirlos mantiene un documento YAML válido y resalta también los `---`,
--- igual que hace la inyección de frontmatter de Markdown.
local function narrow_to_frontmatter(match, _, bufnr, pred, metadata)
  local capture_id = pred[2]
  local node = captured(match, capture_id)
  local close = node and close_row(node, bufnr)

  if not close then
    return
  end

  set_range(metadata, capture_id, { 0, 0, close + 1, 0 })
end

--- Recorta la captura a lo que va después del frontmatter.
---
--- Es un no-op en todos los demás nodos `text`, que es justo lo que hace falta:
--- va en el mismo patrón que el resto para que `injection.combined` los siga
--- uniendo en un único documento.
local function narrow_to_body(match, _, bufnr, pred, metadata)
  local capture_id = pred[2]
  local node = captured(match, capture_id)
  local close = node and close_row(node, bufnr)

  if not close then
    return
  end

  local _, _, end_row, end_col = node:range()

  set_range(metadata, capture_id, { close + 1, 0, end_row, end_col })
end

--- Registra el predicado y las directivas de `gotmpl`.
---
--- Tiene que correr antes de que se resalte el primer búfer `gotmpl`: una query
--- que use un nombre sin registrar no compila y el resaltado se caería entero.
--- Por eso se llama desde `lzy.treesitter.setup`, que es quien crea el autocmd de
--- `FileType` que arranca Tree-sitter.
function M.register()
  local query = vim.treesitter.query

  query.add_predicate("hzsr-gotmpl-frontmatter?", is_frontmatter, REGISTER_OPTS)
  query.add_directive("hzsr-gotmpl-frontmatter!", narrow_to_frontmatter, REGISTER_OPTS)
  query.add_directive("hzsr-gotmpl-body!", narrow_to_body, REGISTER_OPTS)
end

return M
