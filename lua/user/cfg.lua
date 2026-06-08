-- cfg.config

local map = vim.keymap.set
-- =============================================================================
-- Core
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Command mode
-- -----------------------------------------------------------------------------

map("n", ";", ":", { desc = "CMD enter command mode" })

-- =============================================================================
-- Buffers
-- =============================================================================

vim.api.nvim_create_user_command("Bp", function()
  hzsr.edt.go_previous_buffer()
end, { desc = "hzsr: Previous" })

-- =============================================================================
-- Search
-- =============================================================================

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "clear search" })

---

map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Telescope: Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Telescope: Find text" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Telescope: Find buffers" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "Telescope: Find old files" })

-- -----------------------------------------------------------------------------
-- Yank highlight
-- -----------------------------------------------------------------------------

vim.api.nvim_set_hl(0, "YankHighlight", { bg = "#3b4261", fg = "#ffffff" })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank {
      -- higroup = "YankHighlight",
      -- higroup = "Visual",
      higroup = "IncSearch",
      -- higroup = "DiffAdd",
      timeout = 200,
    }
  end,
})

-- =============================================================================
-- Clipboard
-- =============================================================================

map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "File: Copy" })

-- Opcional -> Puedes activarlo si quieres sincronizar el clipboard.
-- sabunv.util.clipboard.sync(true)

-- A medio hacer -> Tampoco es recomendable
-- sabunv.util.clipboard.saburou.legacy_mappings.set(true)

-- =============================================================================
-- Editor
-- =============================================================================

-- Save/Close/Previous Tab
sabunv.edt.mappings.setup()

-- Agregar líneas en modo normal con la tecla ñÑ
map("n", "ñ", ':call append(line("."), "")<CR>==')
map("n", "Ñ", ':call append(line(".") - 1, "")<CR>==')

-- -----------------------------------------------------------------------------
-- Undo / redo
-- -----------------------------------------------------------------------------

map("n", "U", "<C-r>", { desc = "Redo" })

-- -----------------------------------------------------------------------------
-- Insert helpers
-- -----------------------------------------------------------------------------

-- Tab real
map("i", "<S-Tab>", function()
  vim.notify("[!] Putting real \\t ...", vim.log.levels.INFO)
  vim.api.nvim_put({ "\t" }, "c", false, true)
end)

-- -----------------------------------------------------------------------------
-- Edit commands
-- -----------------------------------------------------------------------------

sabunv.edt.edit.cut.create_mappings() -- mapeos relacionados con recortes especiales
-- sabunv.edt.edit.append_line_suffix.create_mappings() -- agregar ;, al final de la línea

-- =============================================================================
-- Windows / view
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Focus
-- -----------------------------------------------------------------------------

map("n", "<C-h>", "<C-w>h", { desc = "Move focus: to the left" })
map("n", "<C-l>", "<C-w>l", { desc = "Move focus: to the right" })
map("n", "<C-k>", "<C-w>k", { desc = "Move focus: to upper" })
map("n", "<C-j>", "<C-w>j", { desc = "Move focus: to lower" })

-- -----------------------------------------------------------------------------
-- Horizontal scroll / nowrap navigation
-- -----------------------------------------------------------------------------
-- [TIP] También puedes usar zH y zL que vienen por defecto.

map("n", "<A-h>", "10zh", { desc = "View: scroll left fast" })
map("n", "<A-l>", "10zl", { desc = "View: scroll right fast" })
map("n", "<A-H>", "zh", { desc = "View: scroll left" })
map("n", "<A-L>", "zl", { desc = "View: scroll right" })

map("i", "<A-h>", "<C-o>10zh", { desc = "View: scroll left fast" })
map("i", "<A-l>", "<C-o>10zl", { desc = "View: scroll right fast" })
map("i", "<A-H>", "<C-o>zh", { desc = "View: scroll left" })
map("i", "<A-L>", "<C-o>zl", { desc = "View: scroll right" })

-- =============================================================================
-- LSP / diagnostics
-- =============================================================================

map("n", "gr", vim.lsp.buf.references, { desc = "LSP references" })
map("n", "<C-A-r>", vim.lsp.buf.rename, { desc = "LSP rename" })

-- =============================================================================
-- Terminal
-- =============================================================================

map("t", "<C-x>", "<C-\\><C-N>", { desc = "Mode: Exit terminal mode" })
map("n", "<A-v>", sabunv.terminal.open_vertical_split, { desc = "Terminal: Vertical split" })
map("n", "<A-b>", sabunv.terminal.open_horizontal_split, { desc = "Terminal: Horizontal split" })

map({ "n", "t" }, "<A-i>", sabunv.terminal.toggle_float, {
  desc = "Terminal: Toggle floating terminal",
})

-- =============================================================================
-- Session / restart
-- =============================================================================

sabunv.restart.setup()

vim.api.nvim_create_user_command("Re", function()
  sabunv.restart.restart()
end, { desc = "hzsr: Previous" })

map("n", "<A-r>", function()
  sabunv.restart.restart()
end, { desc = "hzsr: Restart" })

-- =============================================================================
-- UI / mouse
-- =============================================================================

local menu_first_open = true

map("n", "<RightMouse>", function()
  vim.cmd.exec '"normal! \\<RightMouse>"'

  local mouse = vim.fn.getmousepos()

  if mouse.line == 0 or mouse.column == 0 then
    return
  end

  if menu_first_open then
    menu_first_open = false

    local group = vim.api.nvim_create_augroup("SabunvVoltMenuFirstOpen", {
      clear = true,
    })

    local autocmd_id

    autocmd_id = vim.api.nvim_create_autocmd("WinNew", {
      group = group,
      callback = function()
        if autocmd_id then
          pcall(vim.api.nvim_del_autocmd, autocmd_id)
        end

        vim.schedule(function()
          sabunv.moonfly.apply { force = true }
        end)
      end,
    })
  end

  local options = vim.bo.ft == "NvimTree" and "nvimtree" or "default"

  require("menu").open(options, { mouse = true })
end, { desc = "Menu: Open context menu" })

-- =============================================================================
-- Git
-- =============================================================================

map("n", "<leader>gC", "<cmd>Telescope git_commits<CR>", { desc = "Git commits" })

-- =============================================================================
-- Discarded / notes
-- =============================================================================

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- map("n", "<C-left>", "<C-w>H", { desc = "Move window: to the left" })
-- map("n", "<C-right>", "<C-w>L", { desc = "Move window: to the right" })
-- map("n", "<C-up>", "<C-w>K", { desc = "Move window: to the upper" })
-- map("n", "<C-down>", "<C-w>J", { desc = "Move window: to the lower" })

-- TIP: Disable arrow keys in normal mode
-- map("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
-- map("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
-- map("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
-- map("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Borrar con ctrl + x/s -> Falta de espacio para binderalos
-- map("i", "<C-s>", "<Del>", opts { noremap = true })
-- map("i", "<C-x>", "<BS>", opts { noremap = true })
