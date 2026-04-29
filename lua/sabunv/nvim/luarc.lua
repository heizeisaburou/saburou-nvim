-- sabunv.nvim.luarc

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("Luarc", function(opts)
    hzsr.nvim.luarc.create_buffer(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "Create .luarc.json buffer",
  })
end

return M
