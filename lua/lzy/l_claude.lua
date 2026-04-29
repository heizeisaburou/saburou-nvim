-- lzy.l_claude

local M = {}

local last_float = {
  width = nil,
  height = nil,
  row = nil,
  col = nil,
}

local function float_width()
  return math.floor(vim.o.columns * 0.8)
end

local function float_height()
  return math.floor(vim.o.lines * 0.8)
end

local function float_row()
  return math.floor((vim.o.lines - float_height()) / 2)
end

local function float_col()
  return math.floor((vim.o.columns - float_width()) / 2)
end

local function float_geometry()
  return {
    width = float_width(),
    height = float_height(),
    row = float_row(),
    col = float_col(),
  }
end

local function same_geometry(a, b)
  return a.width == b.width and a.height == b.height and a.row == b.row and a.col == b.col
end

local function refresh_float_geometry()
  local next_float = float_geometry()

  if same_geometry(last_float, next_float) then
    return false
  end

  M.opts.window.float.width = next_float.width -- Width: number of columns or percentage string
  M.opts.window.float.height = next_float.height -- Height: number of rows or percentage string
  M.opts.window.float.row = next_float.row -- Row position: number, "center", or percentage string
  M.opts.window.float.col = next_float.col -- Column position: number, "center", or percentage string

  last_float = next_float

  return true
end

local function setup_if_geometry_changed()
  if refresh_float_geometry() then
    require("claude-code").setup(M.opts)
  end
end

local function toggle()
  setup_if_geometry_changed()
  require("claude-code").toggle()
end

local function toggle_with_variant(variant)
  setup_if_geometry_changed()
  require("claude-code").toggle_with_variant(variant)
end

-- Keybinds definidos a mano, en formato lazy.nvim
M.keys = {
  {
    "<C-,>",
    toggle,
    mode = { "n", "t" },
    desc = "Claude Code: toggle",
  },
  {
    "<leader>,c",
    function()
      toggle_with_variant "continue"
    end,
    mode = "n",
    desc = "Claude Code: continue conversation",
  },
  {
    "<leader>,v",
    function()
      toggle_with_variant "verbose"
    end,
    mode = "n",
    desc = "Claude Code: verbose",
  },
  {
    "<leader>,r",
    function()
      toggle_with_variant "resume"
    end,
    mode = "n",
    desc = "Claude Code: resume (picker)",
  },
}

M.opts = {
  -- Terminal window settings
  window = {
    split_ratio = 0.3, -- Percentage of screen for the terminal window (height for horizontal, width for vertical splits)
    position = "float", -- Position of the window: "botright", "topleft", "vertical", "float", etc.
    enter_insert = true, -- Whether to enter insert mode when opening Claude Code
    hide_numbers = true, -- Hide line numbers in the terminal window
    hide_signcolumn = true, -- Hide the sign column in the terminal window

    -- Floating window configuration (only applies when position = "float")
    float = {
      width = float_width(), -- Width: number of columns or percentage string
      height = float_height(), -- Height: number of rows or percentage string
      row = float_row(), -- Row position: number, "center", or percentage string
      col = float_col(), -- Column position: number, "center", or percentage string
      relative = "editor", -- Relative to: "editor" or "cursor"
      border = "rounded", -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
    },
  },

  -- File refresh settings
  refresh = {
    enable = true, -- Enable file change detection
    updatetime = 100, -- updatetime when Claude Code is active (milliseconds)
    timer_interval = 1000, -- How often to check for file changes (milliseconds)
    show_notifications = true, -- Show notification when files are reloaded
  },

  -- Git project settings
  git = {
    use_git_root = true, -- Set CWD to git root when opening Claude Code (if in git project)
  },

  -- Shell-specific settings
  shell = {
    separator = "&&", -- Command separator used in shell commands
    pushd_cmd = "pushd", -- Command to push directory onto stack (e.g., 'pushd' for bash/zsh, 'enter' for nushell)
    popd_cmd = "popd", -- Command to pop directory from stack (e.g., 'popd' for bash/zsh, 'exit' for nushell)
  },

  -- Command settings
  command = "claude", -- Command used to launch Claude Code

  -- Command variants
  command_variants = {
    continue = "--continue", -- Resume the most recent conversation
    resume = "--resume", -- Display an interactive conversation picker
    verbose = "--verbose", -- Enable verbose logging with full turn-by-turn output
  },

  -- Desactivamos todos los keymaps internos del plugin; los definimos en M.keys
  keymaps = {
    toggle = {
      normal = false, -- Normal mode keymap for toggling Claude Code, false to disable
      terminal = false, -- Terminal mode keymap for toggling Claude Code, false to disable
      variants = {
        continue = false, -- Normal mode keymap for Claude Code with continue flag
        verbose = false, -- Normal mode keymap for Claude Code with verbose flag
      },
    },
    window_navigation = true,
    scrolling = true,
  },
}

function M.setup()
  refresh_float_geometry()
  require("claude-code").setup(M.opts)
end

return M
