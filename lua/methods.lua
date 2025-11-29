---@class Methods
---@field delete_line fun(opts: DeleteLineOpts?): nil
---@field find_word fun(winid: integer?, over_lines: boolean?, cur_row: integer?,  cur_col: integer?): number? , number? , number?
---@field delete_word fun(opts: DeleteLineOpts): nil
---@field delete_up_to_line_end fun(opts: DeleteToLineEndOpts):nil
local M = {}

--------------------------------------------------------------------------------

---@class DeleteLineOpts
---@field copy boolean? Copiar el contenido al clipboard, por defecto true
---@field copy_indent boolean? Copiar incluyendo indentación, por defecto true
---@field insert boolean? Entrar en modo insert después de borrar, por defecto true
---@field keep_indent boolean? Mantener la indentación inicial, por defecto true
---@field winid number? Ventana donde actuar (default=0)
---@field row integer? Línea a borrar (1-index), por defecto la actual

---@class InternalDeleteLineOpts
---@field copy boolean
---@field copy_indent boolean
---@field insert boolean
---@field keep_indent boolean
---@field winid number
---@field row integer?
local DefaultDeleteLineOpts = {
    copy = true,
    copy_indent = true,
    insert = true,
    keep_indent = true,
    winid = 0,
    row = nil,
}

---@param opts DeleteLineOpts?
---@return nil
function M.delete_line(opts)
    local iopts = vim.tbl_extend("force", DefaultDeleteLineOpts, opts or {})

    local winid = iopts.winid
    local bufnr = vim.api.nvim_win_get_buf(winid)

    -- Determinar la línea a borrar
    local row = iopts.row or vim.api.nvim_win_get_cursor(winid)[1]

    -- Obtener línea real del buffer del winid
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
    local indent = line:match "^%s*" or ""

    -- Copiar
    if iopts.copy then
        local content_to_copy = iopts.copy_indent and line or line:sub(#indent + 1)
        vim.fn.setreg("+", content_to_copy)
    end

    -- Borrar la línea
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { "" })

    -- Mantener indentación
    if iopts.keep_indent then
        vim.api.nvim_buf_set_text(bufnr, row - 1, 0, row - 1, 0, { indent })
    end

    -- Mover cursor en esa ventana
    vim.api.nvim_win_set_cursor(winid, { row, iopts.keep_indent and #indent or 0 })

    -- Entrar en insert
    if iopts.insert then
        vim.api.nvim_feedkeys("a", "n", false)
    end
end

--------------------------------------------------------------------------------

---@param winid number? ventana donde buscar
---@param over_lines boolean? si true busca más allá de la línea actual
---@param cur_row integer? fila inicial (1-based)
---@param cur_col integer? columna inicial (0-based)
---@return integer? row
---@return integer? start
---@return integer? count
function M.find_word(winid, over_lines, cur_row, cur_col)
    winid = winid or 0
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if not cur_row or not cur_col then
        cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(winid))
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    local start_idx, count, line
    local row = cur_row
    local ln_start = cur_row - 1 -- cero-indexado
    local ln_end = over_lines and line_count - 1 or ln_start

    for ln = ln_start, ln_end do
        line = vim.api.nvim_buf_get_lines(bufnr, ln, ln + 1, false)[1]
        if line then
            local s, e = line:find "%w+"
            while s and e and e < (ln == ln_start and cur_col + 1 or 0) do
                s, e = line:find("%w+", e + 1)
            end
            if s and e then
                start_idx = s
                count = e - s + 1
                row = ln + 1
                break
            end
        end
    end

    -- local found_word = (start_idx and count) and line:sub(start_idx, start_idx + count - 1) or "nil"
    --
    -- vim.notify(
    --   string.format(
    --     "row=%d, start=%d, count=%d, word='%s'\nline='%s'",
    --     row,
    --     start_idx or 0,
    --     count or 0,
    --     found_word,
    --     line or ""
    --   ),
    --   vim.log.levels.ERROR
    -- )

    return row, start_idx, count
end

--------------------------------------------------------------------------------

---@class DeleteWordOpts
---@field copy boolean?
---@field insert boolean?
---@field winid number? Ventana donde operar (default=0)
---@field row integer? Fila del cursor (1-based)
---@field col integer? Columna del cursor (0-based)

---@class InternalDeleteWordOpts

---@class InternalDeleteWordOpts
---@field copy boolean
---@field insert boolean
---@field winid number
---@field row integer?
---@field col integer?
local DefaultDeleteWordOpts = {
    copy = true,
    insert = true,
    winid = 0,
    row = nil,
    col = nil,
}

---@param opts DeleteWordOpts?
---@return nil
function M.delete_word(opts)
    local iopts = vim.tbl_extend("force", DefaultDeleteWordOpts, opts or {})

    local winid = iopts.winid
    local bufnr = vim.api.nvim_win_get_buf(winid)

    -- Coordenadas iniciales del cursor: si no se pasan, se usan las del winid
    local cur_row, cur_col
    if iopts.row ~= nil and iopts.col ~= nil then
        cur_row = iopts.row
        cur_col = iopts.col
    else
        cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(winid))
    end

    -- Buscar palabra desde esa posición
    local row, start_idx, count = M.find_word(winid, true, cur_row, cur_col)
    if not row or not start_idx or not count then
        return
    end

    -- Obtener línea real
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
    local word = line:sub(start_idx, start_idx + count - 1)

    -- Copiar
    if iopts.copy then
        vim.fn.setreg("+", word)
    end

    -- Borrar palabra
    local new_line = line:sub(1, start_idx - 1) .. line:sub(start_idx + count)

    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

    -- Colocar cursor donde estaba la palabra
    vim.api.nvim_win_set_cursor(winid, { row, start_idx - 1 })

    -- entrar en modo insert si se pidió
    if iopts.insert then
        vim.api.nvim_feedkeys("a", "n", false)
    end
end

--------------------------------------------------------------------------------

---@class DeleteToLineEndOpts
---@field copy boolean? Copiar al clipboard, por defecto true
---@field insert boolean? Entrar en modo insert después de borrar, por defecto true

---@class InternalDeleteToLineEndOpts
---@field copy boolean Copiar al clipboard, por defecto true
---@field insert boolean Entrar en modo insert después de borrar, por defecto true
local DefaultDeleteToLineEndOpts = {
    copy = true,
    insert = true,
}

---@param opts DeleteToLineEndOpts?
---@return nil
function M.delete_up_to_line_end(opts)
    local iopts = vim.tbl_extend("force", DefaultDeleteToLineEndOpts, opts or {})

    -- ventana y buffer actuales
    local winid = 0
    local bufnr = vim.api.nvim_win_get_buf(winid)

    -- obtener posición actual del cursor
    local row, col = unpack(vim.api.nvim_win_get_cursor(winid))
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

    if not line then
        return
    end

    -- extraer desde cursor hasta final
    local text_to_delete = line:sub(col + 1) -- col es 0-based
    if iopts.copy then
        vim.fn.setreg("+", text_to_delete)
    end

    -- construir nueva línea: lo que queda antes del cursor
    local new_line = line:sub(1, col)
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

    -- colocar cursor al mismo lugar
    vim.api.nvim_win_set_cursor(winid, { row, col })

    -- entrar en modo insert si se pidió
    if iopts.insert then
        vim.api.nvim_feedkeys("a", "n", false)
    end
end

--------------------------------------------------------------------------------

-- selectlines: devuelve líneas de la tabla desde i hasta j
---@param t string[] Tabla de strings.
---@param i number Índice inicial (1-based).
---@param j number|nil Índice final (opcional, por defecto el último).
---@return string[] Subtabla con las líneas seleccionadas.
function M.tbl_select(t, i, j)
    j = j or #t
    local out = {}
    for k = i, j do
        if t[k] then
            table.insert(out, t[k])
        end
    end
    return out
end

return M
