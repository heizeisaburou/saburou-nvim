-- hzsr.lzy

local M = {}

M.opts = {
  defaults = { lazy = true },
  -- install = { colorscheme = { "???" } },

  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },

  performance = {
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
        "matchit",
        "tar",
        "tarPlugin",
        "rrhelper",
        "spellfile_plugin",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
        "tutor",
        "rplugin",
        "syntax",
        "synmenu",
        "optwin",
        "compiler",
        "bugreport",
        "ftplugin",
      },
    },
  },
}

function M.setup()
  local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system {
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=stable",
      lazyrepo,
      lazypath,
    }
    if vim.v.shell_error ~= 0 then
      error("Error cloning lazy.nvim:\n" .. out)
    end
  end

  vim.opt.rtp:prepend(lazypath)

  require("lazy").setup({
    { import = "lzy.plg" },
  }, M.opts)
end

---@param name string
---@return boolean available
function M.spec_available(name)
  local ok, Config = pcall(require, "lazy.core.config")
  return ok and Config.plugins[name] ~= nil
end

---@param name string
---@return boolean available
function M.plugin_available(name)
  local ok, _ = pcall(require, name)
  return ok
end

---@param name string
---@return boolean ready
function M.plugin_ready(name)
  local ok, Config = pcall(require, "lazy.core.config")
  if not ok then
    return false
  end

  local plugin = Config.plugins[name]
  if plugin == nil or plugin._ == nil then
    return false
  end

  ---@diagnostic disable-next-line: undefined-field
  return plugin._.loaded ~= nil
end

---@return boolean
function M.available()
  local ok, _ = pcall(require, "lazy")
  return ok
end

---@return boolean
function M.ready()
  local ok, Config = pcall(require, "lazy.core.config")
  return ok and type(Config.plugins) == "table"
end

return M
