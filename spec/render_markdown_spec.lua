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
  "lzy.render-markdown.cursor",
  "lzy.render-markdown.inline",
  "lzy.render-markdown.links",
}) do
  package.loaded[name] = nil
end

describe("Sabunv render-markdown links", function()
  local bufnr
  local namespace

  local lines = {
    "[[other_a]]",
    "",
    "[blabla](other_a)",
    "",
    '[label]: enlace.md "description"',
    "[plain]: other.md",
    "[texto][label]",
    "[label][]",
    "[label]",
    "[missing]",
    "",
    "[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://example.com/donate)",
    "",
    "![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)",
  }

  local function extmarks()
    return vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
  end

  local function virtual_texts(row)
    local result = {}
    for _, mark in ipairs(extmarks()) do
      local details = mark[4]
      if mark[2] == row and details.virt_text then
        for _, chunk in ipairs(details.virt_text) do
          result[#result + 1] = chunk[1]
        end
      end
    end
    return result
  end

  local function add_interval(intervals, row, start_col, end_col)
    if end_col > start_col then
      intervals[row] = intervals[row] or {}
      intervals[row][#intervals[row] + 1] = { start_col, end_col }
    end
  end

  -- Reproduce el ancho que Neovim obtiene de los conceals de Tree-sitter,
  -- los conceals propios del plugin y su texto virtual inline.
  local function rendered_widths()
    local intervals = {}
    local parser = vim.treesitter.get_parser(bufnr, "markdown")
    parser:parse(true)
    parser:for_each_tree(function(tree, language_tree)
      local query = vim.treesitter.query.get(language_tree:lang(), "highlights")
      if query then
        for _, node, metadata in query:iter_captures(tree:root(), bufnr) do
          if metadata.conceal ~= nil then
            local row, start_col, end_row, end_col = node:range()
            if row == end_row then
              add_interval(intervals, row, start_col, end_col)
            end
          end
        end
      end
    end)

    local virtual = {}
    for _, mark in ipairs(extmarks()) do
      local row, start_col, details = mark[2], mark[3], mark[4]
      if details.conceal ~= nil and details.end_row == row then
        add_interval(intervals, row, start_col, details.end_col)
      end
      for _, chunk in ipairs(details.virt_text or {}) do
        virtual[row] = (virtual[row] or 0) + vim.fn.strdisplaywidth(chunk[1])
      end
    end

    local result = {}
    for row, line in ipairs(lines) do
      row = row - 1
      local hidden = intervals[row] or {}
      table.sort(hidden, function(a, b)
        return a[1] < b[1]
      end)
      local merged = {}
      for _, range in ipairs(hidden) do
        local last = merged[#merged]
        if last and range[1] <= last[2] then
          last[2] = math.max(last[2], range[2])
        else
          merged[#merged + 1] = { range[1], range[2] }
        end
      end
      local width = vim.fn.strdisplaywidth(line) + (virtual[row] or 0)
      for _, range in ipairs(merged) do
        width = width - vim.fn.strdisplaywidth(line:sub(range[1] + 1, range[2]))
      end
      result[row] = width
    end
    return result
  end

  before_each(function()
    require("lzy.render-markdown.links").patch_linked_images()
    require("render-markdown").setup(
      vim.tbl_deep_extend("force", require("lzy.render-markdown").opts, {
        debounce = 0,
        anti_conceal = { enabled = false },
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

    assert(
      vim.wait(1000, function()
        return #extmarks() >= 10
      end, 10),
      "render-markdown did not produce the expected extmarks"
    )
  end)

  after_each(function()
    vim.cmd "silent! %bwipeout!"
  end)

  it("keeps native icons and fills only unsupported reference forms", function()
    assert.are.same({ "󱗖 " }, virtual_texts(0))
    assert.are.same({ "󰌹 " }, virtual_texts(2))
    assert.are.same({ "󰌹 ", " (description)" }, virtual_texts(4))
    assert.are.same({ "󰌹 " }, virtual_texts(5))
    assert.are.same({ "󰌹 " }, virtual_texts(6))
    assert.are.same({ "󰌹 " }, virtual_texts(7))
    assert.are.same({ "󰌹 " }, virtual_texts(8))
    assert.are.same({}, virtual_texts(9))
  end)

  it("measures the exact rendered cell width including virtual icons", function()
    local actual = rendered_widths()
    assert.are.equal(9, actual[0])
    assert.are.equal(8, actual[2])
    assert.are.equal(21, actual[4])
    assert.are.equal(7, actual[5])
    assert.are.equal(7, actual[6])
    assert.are.equal(7, actual[7])
    assert.are.equal(7, actual[8])
    assert.are.equal(7, actual[9])

    local md = require "hzsr.md"
    local opts = { bufnr = bufnr }
    assert.are.equal(9, md.visible_width(lines[1]))
    assert.are.equal(actual[0], md.visible_width(lines[1], opts))
    assert.are.equal(actual[2], md.visible_width(lines[3], opts))
    assert.are.equal(actual[4], md.visible_width(lines[5], opts))
    assert.are.equal(actual[5], md.visible_width(lines[6], opts))
    assert.are.equal(actual[6], md.visible_width(lines[7], opts))
    assert.are.equal(actual[7], md.visible_width(lines[8], opts))
    assert.are.equal(actual[8], md.visible_width(lines[9], opts))
    assert.are.equal(actual[9], md.visible_width(lines[10], opts))
  end)

  it("draws a linked image as one thing, not as two links", function()
    -- `[![alt](img)](url)` es el patrón de los badges. Para tree-sitter son dos
    -- nodos anidados —el enlace y, dentro de su etiqueta, la imagen— y el
    -- plugin pintaba un icono por nodo: salían dos pegados, como si hubiera dos
    -- enlaces distintos. Es una sola cosa, y es una imagen.
    local badge, image = virtual_texts(11), virtual_texts(13)
    assert.are.equal(1, #badge)
    assert.are.same(image, badge)

    -- Y los formateadores tienen que medir eso mismo, no el markup entero.
    local actual = rendered_widths()
    assert.are.equal(actual[13], actual[11])
    assert.are.equal(
      actual[11],
      require("hzsr.md").visible_width(lines[12], { bufnr = bufnr })
    )
  end)

  it("wraps against rendered width instead of raw or label-only width", function()
    local md = require "hzsr.md"
    assert.are.equal("aa\n[[other_a]]", md.wrap_paragraph("aa [[other_a]]", 11, { bufnr = bufnr }))
    assert.are.equal(
      "aa [blabla](other_a)",
      md.wrap_paragraph("aa [blabla](other_a)", 11, { bufnr = bufnr })
    )
  end)
end)
