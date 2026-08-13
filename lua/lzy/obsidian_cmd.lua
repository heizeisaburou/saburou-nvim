-- lzy/obsidian_cmd.lua
-- Registra los comandos Nyabsidian* al arranque, sin que obsidian.nvim (ni el
-- módulo lzy.obsidian) tenga que estar cargado. Cada comando carga el módulo
-- bajo demanda y lo inicializa la primera vez (plugin + setup).

local M = {}

local COMMANDS = {
  {
    cmd = "NyabsidianRefresh",
    fn = "refresh",
    args = { notify = true },
    desc = "Refresh Nyabsidian workspaces",
  },
  { cmd = "NyabsidianInfo", fn = "info", desc = "Show Nyabsidian workspace info" },
  { cmd = "NyabsidianDebug", fn = "debug_info", desc = "Dump Nyabsidian LSP debug info" },
  {
    cmd = "NyabsidianFrontmatter",
    fn = "frontmatter",
    desc = "Regenerate note frontmatter (forced)",
  },
  { cmd = "NyabsidianMake", fn = "nyabsidian_make", desc = "New .nyabsidian template buffer" },
}

function M.setup()
  for _, spec in ipairs(COMMANDS) do
    pcall(vim.api.nvim_del_user_command, spec.cmd)
    vim.api.nvim_create_user_command(spec.cmd, function()
      -- require fresco en cada invocación: si el módulo se recarga (dofile),
      -- el comando sigue apuntando a la versión nueva.
      local mod = require "lzy.obsidian"
      mod.ensure_setup()
      local ok, err = pcall(mod[spec.fn], spec.args)
      if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Nyabsidian" })
      end
    end, { desc = spec.desc })
  end
end

return M
