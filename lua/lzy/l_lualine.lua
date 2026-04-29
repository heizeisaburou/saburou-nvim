-- lzy.l_lualine

-- TODO: Hecho a última hora de mala manera, mover funciones de filesystem, etc,
-- a biblioteca para simplificar esto.

local M = {}

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

---@type boolean
local is_setup = false

local filename_depth = 10
local filename_shortened_prefix = true

-- -----------------------------------------------------------------------------
-- Theme
-- -----------------------------------------------------------------------------

local FALLBACK_CONFIG = {
  theme = "auto",

  component_colors = {
    appname = {
      icon = "",
      fg = "#1B2949",
    },
    claude = {
      icon = "",
      fg = "#d19a66",
    },
    codex = {
      icon = "󰞶",
      fg = "#51afef",
    },
    copilot = {
      icon = "",
      fg = "#98c379",
    },
    filename = {
      fg = "#c0caf5",
    },
    filename_inactive = {
      fg = "#808080",
    },
  },
}

local function moonfly_config()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.lualine then
    return vim.deepcopy(FALLBACK_CONFIG)
  end

  return vim.tbl_deep_extend(
    "force",
    vim.deepcopy(FALLBACK_CONFIG),
    sabunv.moonfly.lualine.config()
  )
end

-- -----------------------------------------------------------------------------
-- Components
-- -----------------------------------------------------------------------------

local function appname()
  return "saburou-nvim"
end

local function encoding()
  return vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
end

local function path_separator()
  if hzsr and hzsr.sys and hzsr.sys.os_separator then
    return hzsr.sys.os_separator
  end

  return package.config:sub(1, 1)
end

local function filename()
  local path = vim.api.nvim_buf_get_name(0)

  if path == "" then
    return "[No Name]"
  end

  local sep = path_separator()
  local basename = vim.fn.fnamemodify(path, ":t")

  if filename_depth <= 1 then
    local dir = vim.fn.fnamemodify(path, ":h")
    local shortened = dir ~= "" and dir ~= "."

    if filename_shortened_prefix and shortened then
      return ".." .. sep .. basename
    end

    return basename
  end

  local is_absolute = path:sub(1, 1) == "/" or path:match "^%a:[/\\]"
  local root = ""

  if path:match "^%a:[/\\]" then
    root = path:sub(1, 3)
  elseif path:sub(1, 1) == "/" then
    root = sep
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  local parents = {}

  while dir and dir ~= "" do
    local tail = vim.fn.fnamemodify(dir, ":t")

    if tail == "" or tail == "." or tail == "/" or tail == "\\" then
      break
    end

    table.insert(parents, 1, tail)

    local parent = vim.fn.fnamemodify(dir, ":h")

    if parent == dir then
      break
    end

    dir = parent
  end

  local parent_count = filename_depth - 1
  local start = math.max(#parents - parent_count + 1, 1)
  local selected = {}

  for i = start, #parents do
    table.insert(selected, parents[i])
  end

  table.insert(selected, basename)

  local shortened = start > 1

  if filename_shortened_prefix and shortened then
    return ".." .. sep .. table.concat(selected, sep)
  end

  local result = table.concat(selected, sep)

  if is_absolute and not shortened then
    return root .. result
  end

  return result
end

local function has_terminal_matching(pattern)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
      local name = vim.api.nvim_buf_get_name(bufnr):lower()

      if name:match(pattern) then
        return true
      end
    end
  end

  return false
end

local function claude_statusline()
  if has_terminal_matching "claude" then
    return "Claude"
  end

  return ""
end

local function codex_statusline()
  if has_terminal_matching "codex" then
    return "Codex"
  end

  return ""
end

local function copilot_statusline()
  local ok, client = pcall(require, "copilot.client")

  if not ok or not client or not client.is_disabled then
    return ""
  end

  if client.is_disabled() then
    return ""
  end

  return "Copilot"
end

local function component(fn, item)
  return {
    fn,
    cond = function()
      return fn() ~= ""
    end,
    icon = item.icon,
    color = { fg = item.fg },
  }
end

-- -----------------------------------------------------------------------------
-- Options
-- -----------------------------------------------------------------------------

local function build_opts()
  local config = moonfly_config()
  local theme = config.component_colors

  return {
    options = {
      theme = config.theme,
      globalstatus = true,
      component_separators = "",
      section_separators = "",
    },

    sections = {
      lualine_a = {
        "mode",
      },

      lualine_b = {
        "branch",
        "diff",
        "diagnostics",
      },

      lualine_c = {
        component(claude_statusline, theme.claude),
        component(codex_statusline, theme.codex),
        component(copilot_statusline, theme.copilot),
        {
          filename,
          color = { fg = theme.filename.fg },
        },
      },

      lualine_x = {
        encoding,
        "fileformat",
        "filetype",
      },

      lualine_y = {
        "progress",
        "location",
      },

      lualine_z = {
        {
          appname,
          icon = theme.appname.icon,
          color = { fg = theme.appname.fg, gui = "bold" },
        },
      },
    },

    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {
        {
          filename,
          color = { fg = theme.filename_inactive.fg },
        },
      },
      lualine_x = {
        encoding,
        "fileformat",
        "filetype",
      },
      lualine_y = {
        "location",
      },
      lualine_z = {
        {
          appname,
          icon = theme.appname.icon,
          color = { fg = theme.appname.fg, gui = "bold" },
        },
      },
    },
  }
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

---@return boolean
function M.is_setup()
  return is_setup
end

function M.resetup()
  require("lualine").setup(build_opts())
end

function M.setup()
  require("lualine").setup(build_opts())
  is_setup = true
end

return M
