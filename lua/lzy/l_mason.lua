-- lzy/l_mason

local M = {}

M.opts = {
  PATH = "skip",

  ui = {
    icons = {
      package_pending = " ",
      package_installed = " ",
      package_uninstalled = " ",
    },
  },

  max_concurrent_installers = 10,
}

function M.init_setup()
  local mason_bin = vim.fn.stdpath "data" .. "/mason/bin"

  require("hzsr.sys.path").prepend_env_path(mason_bin)

  vim.api.nvim_create_user_command("MasonInstallAll", function()
    -- Carga mason.nvim si sigue lazy.
    local ok_lazy, lazy = pcall(require, "lazy")
    if ok_lazy then
      lazy.load { plugins = { "mason.nvim" } }
    end

    require("hzsr.mason").install_all()
  end, {})
end

function M.setup()
  ---@diagnostic disable-next-line
  require("mason").setup(M.opts)
end

return M
