-- sabunv.edt.edit

local M = {}

-- =============================================================================
-- Cut mappings
-- =============================================================================

M.cut = {}

-- Descripción corta de cada objeto de recorte.
M.cut.desc = {
  l = "Line",
  t = "Line (same indent)",
  w = "Word",
  e = "Up to Line End",
}

-- Opciones base según la categoría:
--   <leader>d  → borrar sin copiar y sin entrar en insert
--   <leader>D  → borrar copiando, sin entrar en insert
--   <leader>e  → borrar sin copiar y entrar en insert
--   <leader>c  → borrar copiando y entrar en insert
M.cut.cat_opts = {
  d = { copy = false, insert = false },
  D = { insert = false },
  e = { copy = false },
  c = {},
}

-- Opciones específicas de recortes de línea:
--   l → línea completa
--   t → línea conservando indentación
M.cut.line_opts = {
  l = { copy_indent = false, keep_indent = false },
  t = { copy_indent = false },
}

-- Todos estos mappings usan el prefijo <leader> y se construyen combinando:
--
--   1. Una categoría:
--      d, D, e, c
--
--   2. Un objeto:
--      l, t, w, e
--
-- Ejemplos:
--   <leader>dw → borrar palabra sin copiar
--   <leader>Dw → borrar palabra copiando
--   <leader>el → borrar línea y entrar en insert
--   <leader>ct → borrar línea con indentación, copiar y entrar en insert
function M.cut.create_mappings()
  local map = vim.keymap.set
  local edit = hzsr.edt.edit.cut
  local opts = sabunv.util.mapping.with { prefix = "Edit" }

  -- Desde cursor hasta final de línea: <leader>de, <leader>De, <leader>ee, <leader>ce
  for cat, cat_opts in pairs(M.cut.cat_opts) do
    local keys = cat .. "e"

    map("n", "<leader>" .. keys, function()
      edit.delete_up_to_line_end(cat_opts)
    end, opts(M.cut.desc.e))
  end

  -- Palabra: <leader>dw, <leader>Dw, <leader>ew, <leader>cw
  for cat, cat_opts in pairs(M.cut.cat_opts) do
    local keys = cat .. "w"

    map("n", "<leader>" .. keys, function()
      edit.delete_word(cat_opts)
    end, opts(M.cut.desc.w))
  end

  -- Línea / línea con indentación: <leader>dl, <leader>dt, <leader>el, <leader>ct, etc.
  for cat, cat_opts in pairs(M.cut.cat_opts) do
    for cmd, cmd_opts in pairs(M.cut.line_opts) do
      local keys = cat .. cmd
      local dl_opts = vim.tbl_extend("force", {}, cat_opts, cmd_opts)

      map("n", "<leader>" .. keys, function()
        edit.delete_line(dl_opts)
      end, opts(M.cut.desc[cmd]))
    end
  end
end

-- =============================================================================
-- Append line suffix mappings
-- =============================================================================
-- Gracias a @iilegion (discord)

M.append_line_suffix = {}

M.append_line_suffix.items = {
  {
    lhs = "<leader>;",
    suffix = ";",
    desc = "Insert semicolon at the end of the line",
    opts = {
      allow_dups = false,
      strip = true,
    },
  },
  {
    lhs = "<leader>,",
    suffix = ",",
    desc = "Insert comma at the end of the line",
    opts = {
      allow_dups = false,
      strip = true,
    },
  },
}

function M.append_line_suffix.create_mappings()
  local map = vim.keymap.set
  local edit = hzsr.edt.edit.append_line_suffix
  local opts = sabunv.util.mapping.with { prefix = "Edit" }

  for _, item in ipairs(M.append_line_suffix.items) do
    map("n", item.lhs, edit.gen(item.suffix, item.opts), opts(item.desc))
  end
end

-- =============================================================================
-- Setup
-- =============================================================================

function M.create_edit_commands()
  M.cut.create_mappings()
  M.append_line_suffix.create_mappings()
end

return M
