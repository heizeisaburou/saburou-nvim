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

  local function run(name, lines)
    local result
    conform.formatters[name].format(nil, nil, lines, function(err, value)
      assert.is_nil(err)
      result = value
    end)
    return result
  end

  it("keeps the semantic formatter order", function()
    assert.are.same({
      "markdown_callouts",
      "markdown_spoilers_prepare",
      "prettier",
      "markdown_spoilers_restore",
      "markdown_reference_definitions",
      "markdown_wrap",
      "markdown_tabs",
    }, conform.formatters_by_ft.markdown)
  end)

  it("round-trips spoiler fences through Prettier's embedded Markdown parser", function()
    local source = {
      "```spoiler",
      "#  Heading",
      "",
      "text      with spaces",
      "```",
      "",
      "~~~lua",
      "print('untouched')",
      "~~~",
      "",
      "````markdown",
      "```spoiler",
      "literal example",
      "```",
      "````",
    }
    local prepared = run("markdown_spoilers_prepare", source)
    assert.are.equal("```markdown hzsr-internal-spoiler-fence", prepared[1])
    assert.are.equal("~~~lua", prepared[7])
    assert.are.equal("```spoiler", prepared[12])

    -- Salida representativa de Prettier: el marcador `markdown` hace que
    -- normalice el cuerpo como Markdown embebido.
    local restored = run("markdown_spoilers_restore", {
      "```markdown hzsr-internal-spoiler-fence",
      "# Heading",
      "",
      "text with spaces",
      "```",
      "",
      "```lua",
      "print('untouched')",
      "```",
    })
    assert.are.equal("```spoiler", restored[1])
    assert.are.equal("# Heading", restored[2])
    assert.are.equal("text with spaces", restored[4])
    assert.are.equal("```lua", restored[7])
  end)

  it("protects inline spoilers from Prettier without stealing escaped, code or table pipes", function()
    local source = {
      "before ||a very long hidden value with spaces|| after",
      "\\||escaped|| and `||code||`",
      "[||label||](other)",
      "",
      "| A | B |",
      "| --- | --- |",
      "| ||table|| | value |",
    }
    local prepared = run("markdown_spoilers_prepare", source)
    assert.is_nil(prepared[1]:find("a very long hidden value", 1, true))
    local token = prepared[1]:match "`S%d%d%d%d%dS`"
    assert.is_not_nil(token)
    assert.are.equal(9, vim.fn.strdisplaywidth(token))
    assert.are.equal(source[2], prepared[2])
    assert.are.equal(source[3], prepared[3])
    assert.are.equal(source[7], prepared[7])
    assert.are.same(source, run("markdown_spoilers_restore", prepared))
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
