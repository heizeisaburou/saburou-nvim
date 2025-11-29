local statuscol = require "statuscol"
local builtin = require "statuscol.builtin"

---@class SCFold
---@field width number -- current width of the fold column
---@field close string? -- 'fillchars' -> foldclose
---@field open string? -- 'fillchars' -> foldopen
---@field sep string? -- 'fillchars' -> foldsep

---@class SCArgs
---@field lnum number  -- v:lnum
---@field relnum number -- v:relnum
---@field virtnum number -- v:virtnum
---@field buf number -- buffer handle of drawn window
---@field win number -- window hanlde of drawn window
---@field actual_curbuf number -- buffer handle of |g:actual_curwin|
---@field actual_curwin number -- window handle of |g:actual_curbuf|
---@field nu boolean -- 'number' option value
---@field rnu boolean -- 'relativenumber' option value
---@field empty boolean -- statuscolumn is currently empty
---@field fold SCFold
---@field tick number -- FFI data: display_tick value
---@field wp userdata -- FFI data: win_T pointer handle

---@class SCSign
---@field name string[]?       -- patrones de nombres de signos legacy (ej. "DapBreakpoint")
---@field text string[]?       -- patrones de textos de extmarks
---@field namespace string[]?  -- patrones de namespace de extmarks
---@field maxwidth number?     -- ancho máximo de signos que se mostrarán en el segmento
---@field colwidth number?     -- número de celdas de ancho por signo
---@field auto boolean|string? -- valor a dibujar si no hay signos
---@field wrap boolean?        -- si true, dibuja signos también en líneas virtuales
---@field fillchar string?     -- carácter usado para rellenar cuando faltan signos
---@field fillcharhl string?   -- highlight group usado para fillchar
---@field foldclosed boolean?  -- si true, muestra signos en líneas de fold cerrado
---@field wins table?          -- tabla interna: por ventana, qué signos están en qué línea

---@class SCInternalSegment
---@field cond boolean -- si el segmento debe mostrarse
---@field text fun(args: SCArgs, segment: SCInternalSegment):string  -- función que genera/string (si misma?)
---@field textfunc boolean -- true si `text` es función, false si es un string
---@field sign SCSign?

local M = {}

---@param args SCArgs
---@param segment SCInternalSegment
---@return string
local function lnumfunc(args, segment)
    -- vim.notify("tick type: " .. type(args.tick) , vim.log.levels.ERROR)
    -- vim.notify("args:\n" .. vim.inspect(args) .. "segment:\n" .. vim.inspect(segment))
    -- local result = builtin.lnumfunc(args, segment)
    -- vim.notify("result |" .. vim.inspect(result) .. "|")

    -- vim.notify(
    --   string.format(
    --     "segment.text id: %s\nlnumfunc id: %s\n¿Son iguales? %s",
    --     tostring(segment.text),
    --     tostring(lnumfunc),
    --     tostring(segment.text == lnumfunc)
    --   ),
    --   vim.log.levels.ERROR

    return builtin.lnumfunc(args, segment)
end

-- M.default_opts = {
--   -- setopt: Decidir si debe establecer o no la opción 'statuscolumn', puede configurarse como false para
--   --  aquellos que quieran usar los manejadores de clic en su propio 'statuscolumn': _G.Sc[SFL]a().
--   --  Aunque recomiendo simplemente usar el campo segments más abajo para construir tu
--   --  statuscolumn y así beneficiarte de las optimizaciones de rendimiento de este plugin.
--   --
--   --    true  — El plugin llama internamente a vim.opt.statuscolumn = ... usando tus opts o segments.
--   --    false — El plugin no toca vim.opt.statuscolumn en absoluto.
--   --
--   setopt = true,
--   -- --------------------------------------------------------------------------
--   -- builtin.lnumfunc number string options
--   -- or line number thousands separator string ("." / ",")
--   thousands = false,
--   -- whether to right-align the cursor line number with 'relativenumber' set
--   relculright = true,
--   -- --------------------------------------------------------------------------
--   -- Builtin 'statuscolumn' options
--   -- Lua table with 'filetype' values for which 'statuscolumn' will be unset
--   ft_ignore = nil,
--   -- Lua table with 'buftype' values for which 'statuscolumn' will be unset
--   bt_ignore = nil,
--   -- --------------------------------------------------------------------------
--   -- Default segments (fold -> sign -> line number + separator), explained below
--   segments = {
--     { text = { "%C" }, click = "v:lua.ScFa" },
--     { text = { "%s" }, click = "v:lua.ScSa" },
--     {
--       -- text = { builtin.lnumfunc, " " },
--       condition = { true, builtin.not_empty },
--       click = "v:lua.ScLa",
--       hl = function(args)
--         return args.relnum == 0 and "WarningMsg" or "Comment"
--       end,
--     },
--   },
--   -- --------------------------------------------------------------------------
--   -- clickmod: modifier used for certain actions in the builtin clickhandlers:
--   --  "a" for Alt, "c" for Ctrl and "m" for Meta.
--   clickmod = "c",
--   -- --------------------------------------------------------------------------
--   -- builtin click handlers, keys are pattern matched
--   clickhandlers = {
--     Lnum = builtin.lnum_click,
--     FoldClose = builtin.foldclose_click,
--     FoldOpen = builtin.foldopen_click,
--     FoldOther = builtin.foldother_click,
--     DapBreakpointRejected = builtin.toggle_breakpoint,
--     DapBreakpoint = builtin.toggle_breakpoint,
--     DapBreakpointCondition = builtin.toggle_breakpoint,
--     ["diagnostic/signs"] = builtin.diagnostic_click,
--     gitsigns = builtin.gitsigns_click,
--   },
-- }

M.opts = {
    -- setopt: Decidir si debe establecer o no la opción 'statuscolumn', puede configurarse como false para
    --  aquellos que quieran usar los manejadores de clic en su propio 'statuscolumn': _G.Sc[SFL]a().
    --  Aunque recomiendo simplemente usar el campo segments más abajo para construir tu
    --  statuscolumn y así beneficiarte de las optimizaciones de rendimiento de este plugin.
    --
    --    true  — El plugin llama internamente a vim.opt.statuscolumn = ... usando tus opts o segments.
    --    false — El plugin no toca vim.opt.statuscolumn en absoluto.
    --
    setopt = true,
    -- --------------------------------------------------------------------------
    -- builtin.lnumfunc number string options
    -- or line number thousands separator string ("." / ",")
    thousands = false,
    -- whether to right-align the cursor line number with 'relativenumber' set
    relculright = true,
    -- --------------------------------------------------------------------------
    -- Builtin 'statuscolumn' options
    -- Lua table with 'filetype' values for which 'statuscolumn' will be unset
    ft_ignore = nil,
    -- Lua table with 'buftype' values for which 'statuscolumn' will be unset
    bt_ignore = nil,
    -- --------------------------------------------------------------------------
    -- Default segments (fold -> sign -> line number + separator), explained below
    segments = {
        { text = { builtin.foldfunc }, click = "v:lua.ScFa" }, -- fold column
        { text = { "%s" }, click = "v:lua.ScSa" }, -- signos (git, diagnostics, etc.)
        { -- número de línea
            text = { builtin.lnumfunc, " " },
            condition = { true, builtin.not_empty }, -- solo se muestran las líneas no vacías
            click = "v:lua.ScLa", -- al hacer click se pone B (dap)
        },
    },
    -- --------------------------------------------------------------------------
    -- clickmod: modifier used for certain actions in the builtin clickhandlers:
    --  "a" for Alt, "c" for Ctrl and "m" for Meta.
    clickmod = "c",
    -- --------------------------------------------------------------------------
    -- builtin click handlers, keys are pattern matched
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
    vim.opt.relativenumber = true
    statuscol.setup(M.opts)
end

return M
