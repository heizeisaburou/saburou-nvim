-- sabunv.nvim.harness — comando :Harness.

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("Harness", function(opts)
    require("hzsr.test").run(vim.split(opts.args or "", "%s+", { trimempty = true }))
  end, { nargs = "*", desc = "Run hzsr test harness (flags: --root=, --config=, --plenary)" })
end

return M
