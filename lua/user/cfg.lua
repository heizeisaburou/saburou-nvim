-- cfg.config

local map = vim.keymap.set

-- =============================================================================
-- Clipboard
-- =============================================================================

-- Recomiendo desactivar la sincronización del clipboard del sistema y aprender a sincronizar
-- el cliboard manualmente, a menos que sean tus primeros meses utilizando Neovim.
local sync_clipboard = true
if sync_clipboard and vim.fn.has "clipboard" == 1 then
  sabunv.util.clipboard.sync(true)
end

map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "Clipboard: Copy file" })

local function read_register(name)
  local ok, info = pcall(vim.fn.getreginfo, name)
  if not ok then
    return false, info
  elseif
    type(info) ~= "table"
    or type(info.regcontents) ~= "table"
    or type(info.regtype) ~= "string"
    or info.regtype == ""
  then
    return false, "el registro está vacío o no disponible"
  end
  return true, info.regcontents, info.regtype
end

local function write_register(name, contents, register_type)
  return pcall(vim.fn.setreg, name, contents, register_type)
end

map("n", "<leader>cs", function()
  if vim.fn.has "clipboard" == 0 then
    vim.notify("Clipboard del sistema no disponible", vim.log.levels.ERROR)
    return
  end
  local read_ok, contents, register_type = read_register '"'
  if not read_ok then
    vim.notify(
      "No se pudo leer el registro de Neovim: " .. tostring(contents),
      vim.log.levels.ERROR
    )
    return
  end
  local write_ok, err = write_register("+", contents, register_type)
  if not write_ok then
    vim.notify("Clipboard del sistema no disponible: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.notify "Clipboard: Neovim → sistema"
end, { desc = "Clipboard: Neovim → sistema" })

map("n", "<leader>cn", function()
  if vim.fn.has "clipboard" == 0 then
    vim.notify("Clipboard del sistema no disponible", vim.log.levels.ERROR)
    return
  end
  local read_ok, contents, register_type = read_register "+"
  if not read_ok then
    vim.notify(
      "Clipboard del sistema no disponible: " .. tostring(contents),
      vim.log.levels.ERROR
    )
    return
  end

  -- Como un yank normal: el contenido queda disponible tanto en el registro
  -- sin nombre como en el registro 0, conservando si era character/line/block.
  local zero_ok, zero_err = write_register("0", contents, register_type)
  local unnamed_ok, unnamed_err = write_register('"', contents, register_type)
  if not zero_ok or not unnamed_ok then
    vim.notify(
      "No se pudo actualizar el registro de Neovim: " .. tostring(zero_err or unnamed_err),
      vim.log.levels.ERROR
    )
    return
  end
  vim.notify "Clipboard: sistema → Neovim"
end, { desc = "Clipboard: Sistema → Neovim" })

-- -> Los mappings legacy se quedaron a medio hacer y van a dar problemas.
-- sabunv.util.clipboard.saburou.legacy_mappings.set(true)

-- =============================================================================
-- Core
-- =============================================================================

map("n", ";", ":", { desc = "Command: Enter command mode" })

-- =============================================================================
-- Buffers
-- =============================================================================

vim.api.nvim_create_user_command("Bp", function()
  hzsr.edt.go_previous_buffer()
end, { desc = "Buffer: Previous" })

-- =============================================================================
-- Search
-- =============================================================================

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Search: Clear highlight" })

map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Telescope: Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Telescope: Find text" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Telescope: Find buffers" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "Telescope: Find old files" })
map("n", "<leader>fc", function()
  require("telescope.builtin").find_files {
    cwd = vim.fn.stdpath "config",
    hidden = true,
    prompt_title = "Neovim config",
  }
end, { desc = "Telescope: Find config files" })

-- =============================================================================
-- Editor
-- =============================================================================

-- Save, close and previous buffer
sabunv.edt.mappings.setup()

-- Special cut operations
sabunv.edt.edit.cut.create_mappings()
-- sabunv.edt.edit.append_line_suffix.create_mappings()

map("n", "ñ", ':call append(line("."), "")<CR>==', { desc = "Editor: Insert line below" })
map("n", "Ñ", ':call append(line(".") - 1, "")<CR>==', { desc = "Editor: Insert line above" })

map("n", "U", "<C-r>", { desc = "Editor: Redo" })

map("i", "<S-Tab>", function()
  vim.notify("[!] Putting real \\t ...", vim.log.levels.INFO)
  vim.api.nvim_put({ "\t" }, "c", false, true)
end, { desc = "Editor: Insert literal tab" })

-- =============================================================================
-- Windows / view
-- =============================================================================

map("n", "<C-h>", "<C-w>h", { desc = "Window: Focus left" })
map("n", "<C-l>", "<C-w>l", { desc = "Window: Focus right" })
map("n", "<C-k>", "<C-w>k", { desc = "Window: Focus above" })
map("n", "<C-j>", "<C-w>j", { desc = "Window: Focus below" })
map({ "n", "i", "t" }, "<A-z>", hzsr.win.zoom.toggle, { desc = "Window: Toggle zoom" })

map({ "n", "i" }, "<A-H>", "zh", { desc = "View: scroll left" })
map({ "n", "i" }, "<A-L>", "zl", { desc = "View: scroll right" })
map({ "n", "i" }, "<A-h>", "10zh", { desc = "View: scroll left fast" })
map({ "n", "i" }, "<A-l>", "10zl", { desc = "View: scroll right fast" })

-- =============================================================================
-- LSP
-- =============================================================================

map("n", "gr", vim.lsp.buf.references, { desc = "LSP: References" })
map("n", "<C-A-r>", vim.lsp.buf.rename, { desc = "LSP: Rename" })

-- =============================================================================
-- Terminal
-- =============================================================================

map("t", "<C-x>", "<C-\\><C-N>", { desc = "Terminal: Leave terminal mode" })
map("n", "<A-v>", sabunv.terminal.open_vertical_split, { desc = "Terminal: Vertical split" })
map("n", "<A-b>", sabunv.terminal.open_horizontal_split, { desc = "Terminal: Horizontal split" })

map({ "n", "i", "t" }, "<A-i>", sabunv.terminal.toggle_float, {
  desc = "Terminal: Toggle floating terminal",
})

-- =============================================================================
-- Session
-- =============================================================================

-- sabunv.restart.setup()

vim.api.nvim_create_user_command("Rs", function()
  sabunv.restart.restart()
end, { desc = "Restart session" })

map("n", "<leader>rs", function()
  sabunv.restart.restart()
end, { desc = "Restart session" })

-- =============================================================================
-- UI
-- =============================================================================

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank {
      higroup = "IncSearch",
      timeout = 200,
    }
  end,
})

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

map("n", "<leader>gc", "<cmd>Telescope git_commits<CR>", { desc = "Git: Commits" })

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
