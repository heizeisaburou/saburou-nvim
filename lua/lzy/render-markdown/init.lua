-- Configuración e integración de render-markdown.nvim.

local M = {}

local is_setup = false

---@module 'render-markdown'
---@type render.md.UserConfig
M.opts = {
  enabled = true,
  file_types = { "markdown", "quarto", "markdown.mdx", "opencode_output" },

  completions = {
    lsp = {
      enabled = false,
    },
  },

  code = {
    render_modes = { "i" },
  },

  custom_handlers = {
    markdown = {
      parse = require("lzy.render-markdown.spoilers").parse_markdown,
    },
    markdown_inline = {
      extends = true,
      parse = require("lzy.render-markdown.inline").parse,
    },
  },
}

local function moonfly_config()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.render_markdown then
    return {}
  end
  return sabunv.moonfly.render_markdown.config()
end

local function setup_moonfly()
  if
    sabunv
    and sabunv.moonfly
    and sabunv.moonfly.setup
    and sabunv.moonfly.setup.render_markdown
  then
    sabunv.moonfly.setup.render_markdown()
  end
end

local function build_opts()
  return vim.tbl_deep_extend("force", vim.deepcopy(M.opts), moonfly_config())
end

local function setup_plugin()
  require("lzy.render-markdown.links").patch_linked_images()
  require("lzy.render-markdown.spoilers").setup()
  require("render-markdown").setup(build_opts())

  local ok, render_markdown = pcall(require, "render-markdown")
  if ok then
    pcall(render_markdown.enable)
  end
end

local function setup_keymaps()
  vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<CR>", {
    desc = "Markdown: toggle render",
  })
end

---@return boolean
function M.is_setup()
  return is_setup
end

function M.resetup()
  setup_moonfly()
  require("lzy.render-markdown.cursor").update_highlight()
  setup_plugin()
end

function M.setup()
  setup_moonfly()
  local cursor = require "lzy.render-markdown.cursor"
  cursor.update_highlight()
  setup_plugin()

  is_setup = true
  setup_keymaps()
  cursor.setup(M.opts)
end

return M
