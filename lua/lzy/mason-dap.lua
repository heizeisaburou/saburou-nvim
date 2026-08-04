-- lzy.l_mason-dap

-- Al igual que dap-ui, PENDIENTE

local M = {}

M.opts = {
  ensure_installed = {
    -- "python",
    -- "delve",
  },

  -- Handlers por adaptador.
  -- Vacío de momento: usa el comportamiento predefinido del plugin.
  handlers = {
    -- function(config)
    --     require("mason-nvim-dap").default_setup(config)
    -- end,

    -- python = function(config)
    --     require("mason-nvim-dap").default_setup(config)
    -- end,
  },
}

function M.setup()
  require("mason-nvim-dap").setup(M.opts)
end

return M
