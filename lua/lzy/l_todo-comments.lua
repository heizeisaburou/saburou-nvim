local M = {}

-- NOTE: algo

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

M.opts = {
  signs = true, -- show icons in the signs column
  sign_priority = 8, -- sign priority
  -- keywords recognized as todo comments
  keywords = {
    CATEGORY = { icon = "", color = "type", alt = { "GROUP", "CAT", "GRP" } },
    TODO = { icon = " ", color = "info" },
    NOTE = { icon = " ", color = "info" },
    INFO = { icon = " ", color = "hint", alt = { "HINT" } },
    UNUSED = {
      icon = "",
      color = "hint",
      alt = { "UNREFERENCED", "UNIMPORT" },
    },
    REVIEW = {
      icon = "󰛨 ",
      color = "hint",
      alt = { "QUESTION", "EXPLAIN", "DISCUSS", "VERIFY" },
    },
    FUTURE = {
      icon = " ", -- Un telescopio (Nerd Font) para "mirar hacia adelante"
      color = "hint", -- El lila/violeta queda muy bien para ideas y planes
      alt = { "NEXT", "ROADMAP", "VERSION", "UPCOMING", "PROPOSAL" },
    },
    WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
    HACK = { icon = " ", color = "warning" },
    DEPRECATED = {
      icon = "󰅖 ",
      color = "warning",
      alt = { "OLD", "OBSOLETE", "REMOVE" },
    },
    REFACTOR = {
      icon = " ",
      color = "warning",
      alt = { "CLEANUP", "REORGANIZE", "REWRITE" },
    },
    DEBT = {
      icon = "󱖫 ",
      color = "warning",
      alt = { "QUICKFIX", "UGLY", "TEMPORARY" },
    },
    STUB = { -- codigo fake
      icon = "󰇝 ",
      color = "warning",
      alt = { "MOCK" },
    },
    PERF = { icon = " ", color = "warning", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
    ERROR = {
      icon = "󰅖 ",
      color = "error",
    },
    TEST = {
      icon = "⏲ ",
      color = "warning",
      alt = { "TESTING", "PASSED", "FAILED" },
    },
    FIX = {
      icon = " ", -- icon used for the sign, and in search results
      color = "error", -- can be a hex color, or a named color (see below)
      alt = { "FIXME", "BUG", "FIXIT", "ISSUE" }, -- a set of other keywords that all map to this FIX keywords
      -- signs = false, -- configure signs for some keywords individually
    },
    SECURITY = {
      icon = "󰒃 ",
      color = "error",
      alt = { "VULN", "AUTH", "SECRET", "PRIVACY" },
    },
    CONSTRUCTOR = {
      icon = "",
      color = "func",
      alt = { "CONSTRUCTORS", "INIT", "INITIALIZE", "NEW" },
    },
    COMMENT = {
      icon = "󰆉 ",
      color = "comment",
      alt = { "COMM", "ANNOTATION", "REMARK" },
    },
    PLACEHOLDER = {
      icon = "",
      color = "comment",
      alt = { "PLACEHOLDERS", "TBD", "TOBEFILLED", "TOBEIMPLEMENTED", "FILLME" },
    },
    DONE = {
      icon = " ",
      color = "comment",
      alt = { "COMPLETED", "FINISHED", "OK", "CHECKED" },
    },
    DOCS = {
      icon = "󰈙 ",
      color = "comment",
      alt = { "DOCUMENTATION", "README", "GUIDE" },
    },
    GETTER = {
      icon = "",
      color = "getter",
      alt = { "GETTERS", "GET", "PROPERTY", "PROPERTIES", "FETCH" },
    },
    SETTER = {
      icon = "",
      color = "setter",
      alt = { "SETTERS", "SET", "STORE" },
    },
    NORMAL = { color = "normal" },
    FUNC = { color = "func" },
    CONST = { color = "const" },
    PREPROC = { color = "preproc" },
    SPECIAL = { color = "special" },
  },
  gui_style = {
    fg = "NONE", -- The gui style to use for the fg highlight group.
    bg = "BOLD", -- The gui style to use for the bg highlight group.
  },
  merge_keywords = true, -- when true, custom keywords will be merged with the defaults
  -- highlighting of the line containing the todo comment
  -- * before: highlights before the keyword (typically comment characters)
  -- * keyword: highlights of the keyword
  -- * after: highlights after the keyword (todo text)
  highlight = {
    multiline = true, -- enable multine todo comments
    multiline_pattern = "^.", -- lua pattern to match the next multiline from the start of the matched keyword
    multiline_context = 10, -- extra lines that will be re-evaluated when changing a line
    before = "fg", -- "fg" or "bg" or empty
    keyword = "wide", -- "fg", "bg", "wide", "wide_bg", "wide_fg" or empty. (wide and wide_bg is the same as bg, but will also highlight surrounding characters, wide_fg acts accordingly but with fg)
    after = "fg", -- "fg" or "bg" or empty
    pattern = [[.*<(KEYWORDS)\s*:]],
    comments_only = false, -- uses treesitter to match keywords in comments only
    max_line_len = 400, -- ignore lines longer than this
    exclude = {}, -- list of file types to exclude highlighting
  },
  -- list of named colors where we try to extract the guifg from the
  -- list of highlight groups or use the hex color if hl not found as a fallback
  colors = {
    info = { "DiagnosticInfo", "#77B791" }, -- verde
    hint = { "DiagnosticHint", "#C48BEB" }, -- lila
    warning = { "DiagnosticWarn", "WarningMsg", "#EBD18A" }, -- amarillo
    error = { "DiagnosticError", "ErrorMsg", "#DE5B61" }, -- rojo
    comment = { "Comment", "#515354" }, -- gris

    type = { "Type", "Structure", "#E69780" }, -- naranja/amarillo/azul/negro (en temas claros) [cambia mucho según el tema]

    normal = { "Normal", "#C2CED8" }, -- blanco
    func = { "Function", "#69C2FF" }, -- azul
    const = { "Constant", "#FF945C" }, -- suele ser naranja/amarillo
    preproc = { "PreProc", "#E9CC61" }, -- suele ser amarillo/naranja
    special = { "Special", "#76ACD6" }, -- tiende a ser algo más claro que func (azul); pero puede ser cualquier otro

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
    -- regex that will be used to match keywords.
    -- don't replace the (KEYWORDS) comment
    pattern = [[\b(KEYWORDS):]], -- ripgrep regex
  },
}

function M.setup()
  require("todo-comments").setup(M.opts)
end

return M
