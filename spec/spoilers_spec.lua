local plugin = "/home/saburou/.local/share/hzsr12/lazy/render-markdown.nvim"
local treesitter = "/home/saburou/.local/share/hzsr12/lazy/nvim-treesitter/runtime"
local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:prepend(treesitter)
vim.opt.runtimepath:prepend(plugin)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path
for _, name in ipairs({
  "hzsr.md",
  "lzy.render-markdown",
  "lzy.render-markdown.inline",
  "lzy.render-markdown.links",
  "lzy.render-markdown.spoilers",
}) do
  package.loaded[name] = nil
end

describe("Sabunv Markdown spoilers", function()
  local bufnr
  local namespace
  local spoilers
  local lines = {
    "Antes ||secreto muy largo|| después",
    "\\||escapado||",
    "`||código||`",
    "[||label||](other)",
    "",
    "```spoiler",
    "# Título",
    "texto **fuerte**",
    "```",
    "",
    "| A | B |",
    "| --- | --- |",
    "| ||tabla|| | valor |",
    "",
    "```spoiler-block",
    "# Nombre largo",
    "```",
  }

  local function extmarks()
    return vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
  end

  local function virtual_texts(row)
    local result = {}
    for _, mark in ipairs(extmarks()) do
      local details = mark[4]
      if mark[2] == row then
        for _, chunk in ipairs(details.virt_text or {}) do
          result[#result + 1] = chunk[1]
        end
      end
    end
    return result
  end

  local function spoiler_virtual_count()
    local count = 0
    for _, mark in ipairs(extmarks()) do
      for _, chunk in ipairs(mark[4].virt_text or {}) do
        if chunk[2] == "RenderMarkdownSpoiler" then
          count = count + 1
        end
      end
    end
    return count
  end

  local function has_block_controller()
    for _, mark in ipairs(extmarks()) do
      local details = mark[4]
      if mark[2] == 6 and details.end_row == 8 and not details.virt_text then
        return true
      end
    end
    return false
  end

  local function move(row, col)
    vim.api.nvim_win_set_cursor(0, { row + 1, col or 0 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
  end

  before_each(function()
    spoilers = require "lzy.render-markdown.spoilers"
    spoilers.setup()
    require("render-markdown").setup(
      vim.tbl_deep_extend("force", require("lzy.render-markdown").opts, {
        debounce = 0,
        anti_conceal = { enabled = true, above = 0, below = 0 },
      })
    )

    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "markdown"
    vim.wo.conceallevel = 2
    vim.treesitter.start(bufnr, "markdown")
    require("render-markdown.core.manager").attach(bufnr)
    namespace = vim.api.nvim_get_namespaces()["render-markdown.nvim"]
    move(4)

    assert(
      vim.wait(1000, function()
        return spoiler_virtual_count() == 3
      end, 10),
      "render-markdown did not render every spoiler form"
    )
  end)

  after_each(function()
    vim.cmd "silent! %bwipeout!"
  end)

  it("renders only complete, unescaped spoilers outside code, links and tables", function()
    assert.are.same({ spoilers.inline_text }, virtual_texts(0))
    assert.are.same({}, virtual_texts(1))
    assert.are.same({}, virtual_texts(2))
    assert.are.same({ "󰌹 " }, virtual_texts(3))
    assert.are.same({ "󰈉 SPOILER · 2 líneas" }, virtual_texts(5))
    assert.are.same({}, virtual_texts(12))
  end)

  it("reveals each form across its logical cursor range and hides it again", function()
    move(0, 10)
    assert(
      vim.wait(1000, function()
        return not vim.tbl_contains(virtual_texts(0), spoilers.inline_text)
          and vim.tbl_contains(virtual_texts(5), "󰈉 SPOILER · 2 líneas")
      end, 10),
      "inline spoiler did not reveal"
    )

    move(7, 3)
    assert(
      vim.wait(1000, function()
        return vim.tbl_contains(virtual_texts(0), spoilers.inline_text)
          and vim.tbl_contains(virtual_texts(5), "󰈉 SPOILER · 2 líneas")
          and not has_block_controller()
      end, 10),
      "block spoiler did not reveal from its body"
    )

    move(4)
    assert(
      vim.wait(1000, function()
        return spoiler_virtual_count() == 3 and has_block_controller()
      end, 10),
      "spoilers did not conceal again"
    )

    move(9)
    assert(
      vim.wait(1000, has_block_controller, 10),
      "the line immediately after the closing fence still revealed the block"
    )
  end)

  it("treats the long fence name exactly like the short one", function()
    -- `spoiler-block` y `spoiler` son el mismo bloque con dos nombres.
    assert.are.same({ "󰈉 SPOILER · 1 línea" }, virtual_texts(14))

    move(15, 3)
    assert(
      vim.wait(1000, function()
        return #virtual_texts(15) > 0
      end, 10),
      "el bloque con nombre largo no se reveló desde su cuerpo"
    )

    move(13)
    assert(
      vim.wait(1000, function()
        return spoiler_virtual_count() == 3
      end, 10),
      "el bloque con nombre largo no se volvió a ocultar"
    )
  end)

  it("injects the revealed block as nested Markdown", function()
    local roots = {}
    local parser = vim.treesitter.get_parser(bufnr, "markdown")
    parser:parse(true)
    parser:for_each_tree(function(tree, language_tree)
      if language_tree:lang() == "markdown" then
        local start_row, _, end_row = tree:root():range()
        roots[#roots + 1] = { start_row, end_row }
      end
    end)
    local function injected(row)
      return #vim.tbl_filter(function(range)
        return range[1] == row and range[2] > range[1]
      end, roots) > 0
    end
    assert.is_true(injected(6), "nested Markdown roots: " .. vim.inspect(roots))
    assert.is_true(injected(15), "nested Markdown roots: " .. vim.inspect(roots))
  end)

  it("uses the exact hidden display width for wrapping", function()
    local md = require "hzsr.md"
    local visible = "Antes " .. spoilers.inline_text .. " después"
    assert.are.equal(vim.fn.strdisplaywidth(visible), md.visible_width(lines[1], { bufnr = bufnr }))

    local exact = vim.fn.strdisplaywidth("aa " .. spoilers.inline_text)
    assert.are.equal(
      "aa ||secreto con espacios||",
      md.wrap_paragraph("aa ||secreto con espacios||", exact, { bufnr = bufnr })
    )
    assert.are.equal(
      "aa\n||secreto con espacios||",
      md.wrap_paragraph("aa ||secreto con espacios||", exact - 1, { bufnr = bufnr })
    )
  end)
end)
