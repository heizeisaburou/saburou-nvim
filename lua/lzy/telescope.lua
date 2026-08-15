-- lzy.l_telescope

local M = {}

local telescope = require "telescope"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local function scroll_preview(columns)
  return function(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local previewer = picker and picker.previewer

    if type(previewer) == "table" and previewer.scroll_horizontal_fn then
      previewer:scroll_horizontal_fn(columns)
    end
  end
end

local preview_left = scroll_preview(-1)
local preview_right = scroll_preview(1)
local preview_left_fast = scroll_preview(-10)
local preview_right_fast = scroll_preview(10)

local function horizontal_preview_mappings(mappings)
  mappings["<A-H>"] = preview_left
  mappings["<A-L>"] = preview_right
  mappings["<A-h>"] = preview_left_fast
  mappings["<A-l>"] = preview_right_fast
  return mappings
end

-- <C-u> y <C-BS> borran la palabra anterior en el prompt, igual que <C-w>
-- (que ya viene así por default en Telescope). Les damos el mismo mapeo
-- tipo "command" que Telescope usa internamente para su <C-w> (ver
-- telescope/mappings.lua: `["<C-w>"] = { "<c-s-w>", type = "command" }`).
--
-- Importante: NO usar una función con nvim_feedkeys() para esto.
-- feedkeys() es una llamada BLOQUEANTE; invocarla desde dentro del
-- callback de un mapeo la anida dentro del mismo loop de eventos de un
-- solo hilo y Neovim se queda esperando una tecla que nunca llega — el
-- picker se congela, el cursor cambia de forma (como si hubiera caído a
-- modo Normal) y la siguiente tecla que pulses "libera" ese bloqueo
-- interpretada fuera de contexto (p.ej. como comando de ventana),
-- cerrando Telescope.
local delete_word_backward = { "<c-s-w>", type = "command" }

---@type table
M.config = {
  defaults = {
    prompt_prefix = "   ",
    selection_caret = " ",
    entry_prefix = " ",
    sorting_strategy = "ascending",
    layout_config = {
      horizontal = {
        prompt_position = "top",
        preview_width = 0.55,
      },
      width = 0.87,
      height = 0.80,
    },
    mappings = {
      i = horizontal_preview_mappings {
        ["<C-p>"] = actions.cycle_history_prev,
        ["<C-n>"] = actions.cycle_history_next,
        ["<C-u>"] = delete_word_backward,
        ["<C-BS>"] = delete_word_backward,
      },
      n = horizontal_preview_mappings {
        ["q"] = actions.close,
      },
    },
  },

  extensions = {},
}

M.extensions = {
  "themes",
  "terms",
}

function M.setup(config)
  if config == true then
    config = M.config
  end

  config = config or M.config

  telescope.setup(config)

  for _, extension in ipairs(M.extensions) do
    pcall(telescope.load_extension, extension)
  end

  pcall(vim.keymap.del, "n", "<leader>fo")

  vim.keymap.set("n", "<leader>fr", function()
    require("telescope.builtin").oldfiles()
  end, { desc = "Telescope: Find recent Files" })
end

return M
