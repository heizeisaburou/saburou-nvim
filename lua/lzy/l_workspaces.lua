-- lzy.l_telescope

local M = {}

-- -----------------------------------------------------------------------------
-- Workspaces / persistencia futura
--
-- `workspaces.nvim` puede combinarse con bufferline para construir un sistema de
-- espacios de trabajo avanzado: recordar cwd/proyecto, archivos abiertos, orden
-- visual de pestañas, grupos y buffer actual.
--
-- La misma base serviría para un sistema de restart/session restore: cerrar
-- Neovim y volver a abrirlo conservando el estado visual y editorial.
--
-- La dificultad es que esa persistencia quedaría atada a plugins concretos. Por
-- ejemplo, el orden de pestañas y los grupos dependen de bufferline; si se cambia
-- de plugin, habría que escribir otro adaptador o restaurar sólo lo genérico.

local map = vim.keymap.set

M.opts = {
  -- path to a file to store workspaces data in
  -- on a unix system this would be ~/.local/share/nvim/workspaces
  path = vim.fn.stdpath "data" .. "/workspaces",

  -- to change directory for nvim (:cd), or only for window (:lcd)
  -- deprecated, use cd_type instead
  -- global_cd = true,

  -- controls how the directory is changed. valid options are "global", "local", and "tab"
  --   "global" changes directory for the neovim process. same as the :cd command
  --   "local" changes directory for the current window. same as the :lcd command
  --   "tab" changes directory for the current tab. same as the :tcd command
  --
  -- if set, overrides the value of global_cd
  cd_type = "global",

  -- sort the list of workspaces by name after loading from the workspaces path.
  sort = true,

  -- sort by recent use rather than by name. requires sort to be true
  mru_sort = true,

  -- option to automatically activate workspace when opening neovim in a workspace directory
  auto_open = false,

  -- option to automatically activate workspace when changing directory not via this plugin
  -- set to "autochdir" to enable auto_dir when using :e and vim.opt.autochdir
  -- valid options are false, true, and "autochdir"
  auto_dir = false,

  -- enable info-level notifications after adding or removing a workspace
  notify_info = true,

  -- lists of hooks to run after specific actions
  -- hooks can be a lua function or a vim command (string)
  -- lua hooks take a name, a path, and an optional state table
  -- if only one hook is needed, the list may be omitted
  hooks = {
    add = {},
    remove = {},
    rename = {},
    open_pre = {},
    open = {},
  },
}

function M.setup()
  require("workspaces").setup(M.opts)
  require("telescope").load_extension "workspaces"
  require("telescope").setup {
    extensions = {
      workspaces = {
        -- keep insert mode after selection in the picker, default is false
        keep_insert = true,
        -- Highlight group used for the path in the picker, default is "String"
        path_hl = "String",
      },
    },
  }

  map("n", "<leader>wf", function()
    require("telescope").extensions.workspaces.workspaces {}
  end, { desc = "Telescope: Workspaces" })

  map("n", "<leader>wa", "<cmd>WorkspacesAdd<CR>", { desc = "Workspaces: add current workspace" })
  map(
    "n",
    "<leader>wr",
    "<cmd>WorkspacesRemove<CR>",
    { desc = "Workspaces: remove current workspace" }
  )

  map("n", "<leader>wo", "<cmd>WorkspacesOpen<CR>", { desc = "Workspaces: open workspace" })
  map(
    "n",
    "<leader>wn",
    "<cmd>WorkspacesRename<CR>",
    { desc = "Workspaces: rename current workspace" }
  )

  map("n", "<leader>wds", "<cmd>WorkspacesSyncDirs<CR>", { desc = "Workspaces dirs: sync" })
  map(
    "n",
    "<leader>wda",
    "<cmd>WorkspacesAddDir<CR>",
    { desc = "Workspaces dirs: add current directory" }
  )
  map(
    "n",
    "<leader>wdr",
    "<cmd>WorkspacesRemoveDir<CR>",
    { desc = "Workspaces dirs: remove current directory" }
  )
end

return M
