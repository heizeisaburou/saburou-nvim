local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Conform Markdown pipeline", function()
  local conform = require("lzy.conform").opts

  local function normalize(lines)
    local result
    conform.formatters.markdown_reference_definitions.format(nil, nil, lines, function(err, value)
      assert.is_nil(err)
      result = value
    end)
    return result
  end

  it("keeps the semantic formatter order", function()
    assert.are.same({
      "markdown_callouts",
      "prettier",
      "markdown_reference_definitions",
      "markdown_wrap",
      "markdown_tabs",
    }, conform.formatters_by_ft.markdown)
  end)

  it("collapses only Prettier-style multiline reference definitions", function()
    local input = {
      "[algoa]:",
      "  other_a.md",
      '  "Descripción opcional suficientemente extensa"',
      "",
      "[short]: other_b.md 'Short'",
      "",
      "Paragraph",
    }
    local expected = {
      '[algoa]: other_a.md "Descripción opcional suficientemente extensa"',
      "",
      "[short]: other_b.md 'Short'",
      "",
      "Paragraph",
    }
    assert.are.same(expected, normalize(input))
    assert.are.same(expected, normalize(expected))
  end)
end)
