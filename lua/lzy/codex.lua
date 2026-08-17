-- lzy.l_codex

local M = {}
local mode = require "sabunv.mode"
local origin = nil

local function toggle()
  local state = require "codex.state"
  local was_open = state.win and vim.api.nvim_win_is_valid(state.win)

  if not was_open then
    origin = mode.capture()
  end

  require("codex").toggle()

  if was_open then
    local context = origin
    origin = nil
    mode.restore(context)
  end
end

M.keys = {
  {
    "<A-]>",
    toggle,
    desc = "Toggle Codex popup or side-panel",
    mode = { "n", "i", "t" },
  },
}

M.opts = {
  keymaps = {
    toggle = nil, -- Keybind to toggle Codex window (Disabled by default, watch out for conflicts)
    -- quit = "<C-q>", -- Keybind to close the Codex window (default: Ctrl + q)
    quit = false, -- Keybind to close the Codex window (default: Ctrl + q)
  },
  border = "rounded", -- Options: 'single', 'double', or 'rounded'
  width = 0.8, -- Width of the floating window (0.0 to 1.0)
  height = 0.8, -- Height of the floating window (0.0 to 1.0)
  model = nil, -- Optional: pass a string to use a specific model (e.g., 'o3-mini')
  autoinstall = false, -- Automatically install the Codex CLI if not found
  panel = false, -- Open Codex in a side-panel (vertical split) instead of floating window
  use_buffer = false, -- Capture Codex stdout into a normal buffer instead of a terminal buffer
}

function M.setup()
  require("codex").setup(M.opts)
end

return M
