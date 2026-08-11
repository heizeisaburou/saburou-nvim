-- sabunv.nvim.sync — comandos :Synco y :Harness.

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("Synco", function(opts)
    local args = vim.split(opts.args or "", "%s+", { trimempty = true })
    require("hzsr.sync").deploy(args[1], args[2])
  end, { nargs = "*", desc = "Sync origen → destino (defaults hzsr12 → nvim)" })

  vim.api.nvim_create_user_command("Harness", function(opts)
    require("hzsr.test").run(vim.split(opts.args or "", "%s+", { trimempty = true }))
  end, { nargs = "*", desc = "Run hzsr test harness (flags: --root=, --config=, --plenary)" })
end

return M
