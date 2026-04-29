-- lzy.l_render-markdown

-- TODO Con el sistema de persistencia, recordar el estado en el que estabamos al
-- reiniciar

local M = {}

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

---@type boolean
local is_setup = false

-- -----------------------------------------------------------------------------
-- Base opts
-- -----------------------------------------------------------------------------

---@module 'render-markdown'
---@type render.md.UserConfig
M.opts = {
  enabled = true,
  file_types = { "markdown", "quarto", "markdown.mdx" },

  completions = {
    lsp = {
      enabled = false,
    },
  },
}

-- -----------------------------------------------------------------------------
-- Theme opts
-- -----------------------------------------------------------------------------

local function moonfly_config()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.render_markdown then
    return {}
  end

  return sabunv.moonfly.render_markdown.config()
end

local function setup_moonfly()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.setup then
    return
  end

  if not sabunv.moonfly.setup.render_markdown then
    return
  end

  sabunv.moonfly.setup.render_markdown()
end

local function build_opts()
  return vim.tbl_deep_extend("force", vim.deepcopy(M.opts), moonfly_config())
end

local function setup_plugin()
  require("render-markdown").setup(build_opts())

  local ok, render_markdown = pcall(require, "render-markdown")
  if ok then
    pcall(render_markdown.enable)
  end
end

-- -----------------------------------------------------------------------------
-- Keymaps
-- -----------------------------------------------------------------------------

local function setup_keymaps()
  local map = vim.keymap.set

  map("n", "<leader>mr", "<cmd>RenderMarkdown toggle<CR>", {
    desc = "Markdown: toggle render",
  })
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

---@return boolean
function M.is_setup()
  return is_setup
end

function M.resetup()
  setup_moonfly()
  setup_plugin()
end

function M.setup()
  setup_moonfly()
  setup_plugin()

  is_setup = true

  setup_keymaps()
end

return M
