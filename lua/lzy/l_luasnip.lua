-- lzy.l_luasnip

local M = {}

M.opts = { history = true, updateevents = "TextChanged,TextChangedI" }

function M.setup()
  local luasnip = require "luasnip"

  luasnip.config.set_config(M.opts)

  -- --- [ vscode ] ------------------------------------------------------------
  local from_vscode = require "luasnip.loaders.from_vscode"
  from_vscode.lazy_load { exclude = vim.g.vscode_snippets_exclude or {} }
  from_vscode.lazy_load { paths = vim.g.vscode_snippets_path or "" }

  -- --- [ snipmate ] ----------------------------------------------------------
  local from_snipmate = require "luasnip.loaders.from_snipmate"
  from_snipmate.load()
  from_snipmate.lazy_load { paths = vim.g.snipmate_snippets_path or "" }

  -- --- [ lua ] ---------------------------------------------------------------
  local from_lua = require "luasnip.loaders.from_lua"
  from_lua.load()
  from_lua.lazy_load { paths = vim.g.lua_snippets_path or "" }

  -- fix luasnip #258
  local group = vim.api.nvim_create_augroup("lzy_luasnip", { clear = true })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      if
        luasnip.session.current_nodes[vim.api.nvim_get_current_buf()]
        and not luasnip.session.jump_active
      then
        luasnip.unlink_current()
      end
    end,
  })
end

return M
