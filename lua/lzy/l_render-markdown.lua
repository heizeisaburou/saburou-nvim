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
-- Contextual rendering
-- -----------------------------------------------------------------------------

local inline_code_query = vim.treesitter.query.parse("markdown_inline", "(code_span) @code")

---@param bufnr integer
---@param row integer
---@return integer?
local function heading_level(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 2, false)
  local marker = (lines[1] or ""):match "^%s*(#+)%s"

  if marker and #marker <= 6 then
    return #marker
  end

  local underline = lines[2] or ""
  if underline:match "^%s*=+%s*$" then
    return 1
  elseif underline:match "^%s*%-+%s*$" then
    return 2
  end
end

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
local function render_heading_inline_code(ctx)
  local marks = {}

  for id, node in inline_code_query:iter_captures(ctx.root, ctx.buf) do
    if inline_code_query.captures[id] == "code" then
      local start_row, start_col, end_row, end_col = node:range()
      local level = heading_level(ctx.buf, start_row)

      if level then
        marks[#marks + 1] = {
          modes = { "i" },
          conceal = "code_background",
          start_row = start_row,
          start_col = start_col,
          opts = {
            end_row = end_row,
            end_col = end_col,
            hl_group = "RenderMarkdownCodeInline",
            -- Los fondos de heading usan la prioridad por defecto de Neovim
            -- (4096), por encima del 140 del código inline del plugin.
            priority = 4097,
          },
        }
      end
    end
  end

  return marks
end

-- -----------------------------------------------------------------------------
-- Base opts
-- -----------------------------------------------------------------------------

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
    markdown_inline = {
      extends = true,
      parse = render_heading_inline_code,
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
