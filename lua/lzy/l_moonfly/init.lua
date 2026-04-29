-- lzy/l_moonfly

local M = {}

local plg = require "hzsr.plg"
local validation = require "hzsr.moonfly_manager.validation"

---@type table<HzsrIntegrationName, HzsrIntegrationSpec>
local INTEGRATIONS = {
  bufferline = {
    plugin = "bufferline.nvim",
    module = require "hzsr.moonfly_manager.integrations.i_bufferline",
  },
  statuscol = {
    plugin = "statuscol.nvim",
    module = require "hzsr.moonfly_manager.integrations.i_statuscol",
  },
  nvimtree = {
    plugin = "nvim-tree.lua",
    module = require "hzsr.moonfly_manager.integrations.i_nvimtree",
  },
  lualine = {
    plugin = "lualine.nvim",
    module = require "hzsr.moonfly_manager.integrations.i_lualine",
  },
}

---@type HzsrIntegrationName[]
local INTEGRATION_ORDER = {
  "bufferline",
  "statuscol",
  "nvimtree",
  "lualine",
}

local BASE_DEFAULT_OPTS = {
  transparent = "none",
  bufferline = {
    sep_style = "thin",
    sep_color = "gray",
  },
}

---@return table<string, { enabled: boolean }>
local function build_generated_default_opts()
  local opts = {}

  for _, name in ipairs(INTEGRATION_ORDER) do
    local integration = INTEGRATIONS[name]

    opts[name] = {
      enabled = plg.has(integration.plugin),
    }
  end

  return opts
end

---@param user_opts? HzsrThemeOpts
function M.setup(user_opts)
  validation.user_opts(user_opts)

  local generated_default_opts = build_generated_default_opts()
  local default_opts = vim.tbl_deep_extend("force", BASE_DEFAULT_OPTS, generated_default_opts or {})

  ---@type HzsrThemeInternalOpts
  ---@diagnostic disable-next-line: assign-type-mismatch
  local opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})

  -- Integraciones
  for _, name in ipairs(INTEGRATION_ORDER) do
    INTEGRATIONS[name].module.integrate(opts)
  end
end

return M
