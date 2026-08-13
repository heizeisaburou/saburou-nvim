local plugin = "/home/saburou/.local/share/hzsr12/lazy/render-markdown.nvim"
local treesitter = "/home/saburou/.local/share/hzsr12/lazy/nvim-treesitter/runtime"
local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:prepend(treesitter)
vim.opt.runtimepath:prepend(plugin)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path
for _, name in ipairs({
  "lzy.render-markdown",
  "lzy.render-markdown.cursor",
  "lzy.render-markdown.inline",
  "sabunv.moonfly.render_markdown",
}) do
  package.loaded[name] = nil
end

describe("Sabunv heading italics", function()
  local bufnr
  local namespace
  local expected = {
    { fg = 0x702044, bg = 0xC7C9CC },
    { fg = 0xFFF0F4, bg = 0x9C4A4A },
    { fg = 0x4B1730, bg = 0xB5995F },
    { fg = 0x40142D, bg = 0x4F98A7 },
    { fg = 0xFFF0F4, bg = 0x5064B0 },
    { fg = 0x27112F, bg = 0x8479D0 },
  }
  local lines = {
    "# *cursiva*",
    "## *cursiva*",
    "### *cursiva*",
    "#### *cursiva*",
    "##### *cursiva*",
    "###### *cursiva*",
    "",
    "*cursiva*",
    "",
    "# _v1_",
  }

  local function extmarks()
    return vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
  end

  local function has_highlight(row, highlight, priority)
    for _, mark in ipairs(extmarks()) do
      local details = mark[4]
      if mark[2] == row and details.hl_group == highlight and details.priority == priority then
        return true
      end
    end
    return false
  end

  before_each(function()
    package.loaded["sabunv.moonfly.tty"] = {
      is_pure = function()
        return false
      end,
    }
    _G.sabunv = { moonfly = { hl = require "sabunv.moonfly.hl" } }
    require("sabunv.moonfly.render_markdown").setup({ style = "solid" })

    require("render-markdown").setup(vim.tbl_deep_extend("force", require("lzy.render-markdown").opts, {
      debounce = 0,
      anti_conceal = { enabled = false },
    }))

    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "markdown"
    vim.wo.conceallevel = 2
    vim.treesitter.start(bufnr, "markdown")
    require("render-markdown.core.manager").attach(bufnr)
    namespace = vim.api.nvim_get_namespaces()["render-markdown.nvim"]

    assert(
      vim.wait(1000, function()
        return has_highlight(0, "RenderMarkdownH1Italic", 4098)
      end, 10),
      "render-markdown did not produce the contextual italic extmarks"
    )
  end)

  after_each(function()
    vim.cmd "silent! %bwipeout!"
  end)

  it("selects an italic highlight for each solid heading band", function()
    for level = 1, 6 do
      assert.is_true(has_highlight(level - 1, "RenderMarkdownH" .. level .. "Italic", 4098))
    end
  end)

  it("installs the contrast-safe berry and porcelain palette", function()
    for level, colors in ipairs(expected) do
      local highlight = vim.api.nvim_get_hl(0, {
        name = "RenderMarkdownH" .. level .. "Italic",
        link = false,
      })
      assert.are.equal(colors.fg, highlight.fg)
      assert.are.equal(colors.bg, highlight.bg)
      assert.is_true(highlight.italic)
    end
  end)

  it("keeps body italics global and covers the underscore fallback in headings", function()
    for level = 1, 6 do
      assert.is_false(has_highlight(7, "RenderMarkdownH" .. level .. "Italic", 4098))
    end
    assert.is_true(has_highlight(9, "RenderMarkdownH1Italic", 4098))
  end)
end)
