-- lzy/l_statuscol

local statuscol = require "statuscol"
local builtin = require "statuscol.builtin"

local M = {}

M.opts = {
  -- Hace que el plugin configure automáticamente 'statuscolumn'.
  -- Si fuera false, tendrías que montarlo tú a mano.
  setopt = true,

  -- Sin separador de miles en los números de línea.
  thousands = false,

  -- Con relativenumber, alinea a la derecha la línea actual.
  relculright = true,

  -- No ignorar ningún filetype ni buftype.
  ft_ignore = nil,
  bt_ignore = nil,

  -- Orden de columnas: folds -> signos -> número de línea.
  segments = {
    -- Columna de folds.
    { text = { builtin.foldfunc }, click = "v:lua.ScFa" },

    -- Signos: git, diagnósticos, breakpoints, etc.
    { text = { "%s" }, click = "v:lua.ScSa" },

    -- Número de línea.
    {
      -- Función de numeración + un espacio
      text = { builtin.lnumfunc, " " },

      -- Solo en líneas no vacías.
      condition = { true, builtin.not_empty },

      -- Al hacer click se pone B (dap)
      click = "v:lua.ScLa",
    },
  },

  -- Modificador usado por algunos handlers de click.
  -- "c" = Ctrl
  clickmod = "c",

  -- Acciones al hacer click en cada tipo de elemento.
  clickhandlers = {
    Lnum = builtin.lnum_click,
    FoldClose = builtin.foldclose_click,
    FoldOpen = builtin.foldopen_click,
    FoldOther = builtin.foldother_click,
    DapBreakpointRejected = builtin.toggle_breakpoint,
    DapBreakpoint = builtin.toggle_breakpoint,
    DapBreakpointCondition = builtin.toggle_breakpoint,
    ["diagnostic/signs"] = builtin.diagnostic_click,
    gitsigns = builtin.gitsigns_click,
  },
}

M.setup = function()
  ---@diagnostic disable-next-line
  statuscol.setup(M.opts)
end

return M
