-- lzy.l_copilot

local M = {}

local function is_enabled()
  return not require("copilot.client").is_disabled()
end

local function copilot_status()
  vim.notify(is_enabled() and "Copilot: habilitado ✓" or "Copilot: deshabilitado")
end

local function copilot_enable()
  if is_enabled() then
    vim.notify "Copilot: ya estaba habilitado ✓"
  else
    require("copilot.command").enable()
    vim.notify "Copilot: habilitando..."
  end
end

local function copilot_disable()
  if not is_enabled() then
    vim.notify "Copilot: ya estaba deshabilitado"
  else
    require("copilot.command").disable()
    vim.notify "Copilot: deshabilitado"
  end
end

local function copilot_toggle()
  if is_enabled() then
    copilot_disable()
  else
    copilot_enable()
  end
end

local function copilot_dismiss()
  require("copilot.suggestion").dismiss()
end

local function copilot_suggest()
  if not is_enabled() then
    copilot_enable()
  end
  require("copilot.suggestion").next()
end

local function copilot_next()
  require("copilot.suggestion").next()
end

local function copilot_prev()
  require("copilot.suggestion").prev()
end

local function copilot_accept_line()
  require("copilot.suggestion").accept_line()
end

local function copilot_accept()
  require("copilot.suggestion").accept()
end

local function copilot_accept_word()
  require("copilot.suggestion").accept_word()
end

M.opts = {
  filetypes = {
    markdown = true,
    ["markdown.mdx"] = true,
    quarto = true,
  },
  panel = {
    enabled = true,
    auto_refresh = false,
    keymap = {
      jump_prev = false,
      jump_next = false,
      accept = false,
      refresh = false,
      open = false,
    },
  },
  suggestion = {
    enabled = true,
    auto_trigger = true,
    hide_during_completion = true,
    debounce = 15,
    keymap = {
      accept = false,
      accept_word = false,
      accept_line = false,
      next = false,
      prev = false,
      dismiss = false,
    },
  },
}

M.keys = {
  { "<leader>gt", copilot_toggle, desc = "Copilot: Toggle" },
  { "<leader>ge", copilot_enable, desc = "Copilot: Enable" },
  { "<leader>gd", copilot_disable, desc = "Copilot: Disable" },
  { "<leader>gs", copilot_status, desc = "Copilot: Status" },

  { "<C-]>", copilot_dismiss, mode = "i", desc = "Copilot: Dismiss suggestion" },
  { "<C-\\>", copilot_suggest, mode = "i", desc = "Copilot: Suggest" },

  { "<A-]>", copilot_next, mode = "i", desc = "Copilot: Next suggestion" },
  { "<A-[>", copilot_prev, mode = "i", desc = "Copilot: Previous suggestion" },

  { "<A-Right>", copilot_accept_word, mode = "i", desc = "Copilot: Accept word" },
  { "<A-\\>", copilot_accept_line, mode = "i", desc = "Copilot: Accept line" },
  { "<A-CR>", copilot_accept, mode = "i", desc = "Copilot: Accept suggestion" },
}

function M.setup()
  require("copilot").setup(M.opts)
  require("copilot.command").disable()
end

return M
