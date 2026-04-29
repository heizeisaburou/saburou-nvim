-- lzy/l_snacks

local M = {}

---@type snacks.dashboard.Config
M.dashboard = {
  width = 60,
  row = nil, -- dashboard position. nil for center
  col = nil, -- dashboard position. nil for center
  pane_gap = 4, -- empty columns between vertical panes
  autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", -- autokey sequence
  -- These settings are used by some built-in sections
  preset = {
    -- Defaults to a picker that supports `fzf-lua`, `telescope.nvim` and `mini.pick`
    ---@type fun(cmd:string, opts:table)|nil
    pick = nil,
    -- Used by the `keys` section to show keymaps.
    -- Set your custom keymaps here.
    -- When using a function, the `items` argument are the default keymaps.
    ---@type snacks.dashboard.Item[]
    keys = {
      { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
      {
        icon = "󱀫 ",
        desc = "Workspaces",
        key = "w",
        action = ":lua require('telescope').extensions.workspaces.workspaces {}",
      },
      {
        icon = " ",
        key = "f",
        desc = "Find File",
        action = ":lua Snacks.dashboard.pick('files')",
      },
      {
        icon = " ",
        key = "r",
        desc = "Recent Files",
        action = ":lua Snacks.dashboard.pick('oldfiles')",
      },
      {
        icon = " ",
        key = "t",
        desc = "Find Text",
        action = ":lua Snacks.dashboard.pick('live_grep')",
      },
      {
        icon = " ",
        key = "c",
        desc = "Config",
        action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
      },
      {
        icon = " ",
        key = "g",
        desc = "GitHub",
        action = ":lua vim.ui.open('https://github.com/heizeisaburou/saburou-nvim')",
      },
      { icon = " ", key = "q", desc = "Quit", action = ":qa" },
    },
    -- Used by the `header` section
    header = [[
███████╗██████╗ ███╗   ██╗██╗   ██╗
██╔════╝██╔══██╗████╗  ██║██║   ██║
███████╗██████╔╝██╔██╗ ██║██║   ██║
╚════██║██╔══██╗██║╚██╗██║╚██╗ ██╔╝
███████║██████╔╝██║ ╚████║ ╚████╔╝ 
╚══════╝╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  
                                   
 heizeisaburou/saburou-nvim
v0.1.0-alpha.1 for Neovim 0.12+]],
  },
  -- item field formatters
  formats = {
    icon = function(item)
      if item.file and item.icon == "file" or item.icon == "directory" then
        return Snacks.dashboard.icon(item.file, item.icon)
      end
      return { item.icon, width = 2, hl = "icon" }
    end,
    footer = { "%s", align = "center" },
    header = { "%s", align = "center" },
    file = function(item, ctx)
      local fname = vim.fn.fnamemodify(item.file, ":~")
      fname = ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname
      if #fname > ctx.width then
        local dir = vim.fn.fnamemodify(fname, ":h")
        local file = vim.fn.fnamemodify(fname, ":t")
        if dir and file then
          file = file:sub(-(ctx.width - #dir - 2))
          fname = dir .. "/…" .. file
        end
      end
      local dir, file = fname:match "^(.*)/(.+)$"
      return dir and { { dir .. "/", hl = "dir" }, { file, hl = "file" } }
        or { { fname, hl = "file" } }
    end,
  },
  sections = {
    { section = "header" },
    { section = "keys", gap = 1 },
    { text = { { "" } }, align = "center" },
    { text = { { "" } }, align = "center" },
    { section = "startup" },
  },
}

M.opts = {
  bigfile = { enabled = true },
  dashboard = M.dashboard,
  explorer = { enabled = false },
  indent = { enabled = true },
  input = { enabled = false },
  picker = { enabled = true },
  notifier = { enabled = false },
  quickfile = { enabled = true },
  scope = { enabled = true },
  scroll = { enabled = true },
  statuscolumn = { enabled = false },
  words = { enabled = true },
}

function M.setup()
  ---@diagnostic disable-next-line
  require("snacks").setup(M.opts)
end

return M
