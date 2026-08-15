local plugin = "/home/saburou/.local/share/hzsr12/lazy/render-markdown.nvim"
local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:prepend(plugin)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

-- `markdown_wrap` mide con `hzsr.md`; el spec no carga la configuración
-- entera, sólo el módulo que necesita esa pasada.
_G.hzsr = _G.hzsr or { md = require "hzsr.md" }

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
      "markdown_frontmatter_prepare",
      "markdown_spoilers_prepare",
      "prettier",
      "markdown_spoilers_restore",
      "markdown_frontmatter_restore",
      "markdown_reference_definitions",
      "markdown_wrap",
      "markdown_tabs",
    }, conform.formatters_by_ft.markdown)
  end)

  it("preserves frontmatter indentation while formatting the Markdown body", function()
    local source = {
      "---",
      "title: Solo propiedades",
      "aliases:",
      "  - sin cuerpo",
      "tags:",
      "  - vacia",
      "---",
      "",
      "Body      still handled by Prettier.",
    }
    local prepared = run("markdown_frontmatter_prepare", source)
    assert.are.equal("---", prepared[1])
    assert.matches("^hzsr%-internal%-frontmatter:", prepared[2])
    assert.are.equal("---", prepared[3])
    assert.are.equal("Body      still handled by Prettier.", prepared[5])

    -- Salida representativa de Prettier: el cuerpo cambia, el marcador queda.
    prepared[5] = "Body still handled by Prettier."
    local restored = run("markdown_frontmatter_restore", prepared)
    assert.are.same({
      "---",
      "title: Solo propiedades",
      "aliases:",
      "  - sin cuerpo",
      "tags:",
      "  - vacia",
      "---",
      "",
      "Body still handled by Prettier.",
    }, restored)
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

  it("reflows list items by visible width, keeping each marker and its alignment", function()
    -- Salida de Prettier con --print-width 97: parte los ítems porque cuenta
    -- el destino completo del wiki-link, no lo que se ve (icono + display).
    local input = {
      "- Visita [[Windows 11 - Maquina Virtual]], especialmente la sección de",
      "  [[Windows 11 - Maquina Virtual#drivers|drivers]].",
      "- [ ] revisa [[Windows 11 - Maquina Virtual]] y la sección de",
      "      [[Windows 11 - Maquina Virtual#drivers|drivers]].",
      "  - anidado hacia [[Windows 11 - Maquina Virtual]], sobre todo la parte de",
      "    [[Windows 11 - Maquina Virtual#drivers|drivers]].",
      "10. ordenado con [[Windows 11 - Maquina Virtual]] y la sección de",
      "    [[Windows 11 - Maquina Virtual#drivers|drivers]].",
    }
    local expected = {
      "- Visita [[Windows 11 - Maquina Virtual]], especialmente la sección de "
        .. "[[Windows 11 - Maquina Virtual#drivers|drivers]].",
      "- [ ] revisa [[Windows 11 - Maquina Virtual]] y la sección de "
        .. "[[Windows 11 - Maquina Virtual#drivers|drivers]].",
      "  - anidado hacia [[Windows 11 - Maquina Virtual]], sobre todo la parte de "
        .. "[[Windows 11 - Maquina Virtual#drivers|drivers]].",
      "10. ordenado con [[Windows 11 - Maquina Virtual]] y la sección de "
        .. "[[Windows 11 - Maquina Virtual#drivers|drivers]].",
    }
    local wrapped = run("markdown_wrap", input)
    assert.are.same(expected, wrapped)
    assert.are.same(expected, run("markdown_wrap", wrapped))

    for _, line in ipairs(wrapped) do
      local prefix = line:match "^ *[-*+] +%[.%] +"
        or line:match "^ *[-*+] +"
        or line:match "^ *%d+[%.)] +"
      assert.is_true(#prefix + hzsr.md.visible_width(line:sub(#prefix + 1)) <= 97)
    end
  end)

  it("splits list items that stay long once measured, aligned under the marker", function()
    local input = {
      "- [ ] revisa [[Windows 11 - Maquina Virtual#drivers|drivers]] antes de instalar nada, "
        .. "porque el instalador no trae los controladores de red y te quedas sin conexión.",
    }
    local expected = {
      "- [ ] revisa [[Windows 11 - Maquina Virtual#drivers|drivers]] antes de instalar nada, "
        .. "porque el instalador no trae los controladores de",
      "      red y te quedas sin conexión.",
    }
    local wrapped = run("markdown_wrap", input)
    assert.are.same(expected, wrapped)
    -- La primera línea llega justo al límite medida como se ve, aunque en
    -- bruto ocupe mucho más que 97 columnas.
    assert.is_true(#wrapped[1] > 97)
    assert.is_true(6 + hzsr.md.visible_width(wrapped[1]:sub(7)) <= 97)
  end)

  it("leaves lists with non-prose content and thematic breaks untouched", function()
    local input = {
      "- ítem con tabla",
      "  | a | b |",
      "  | - | - |",
    }
    assert.are.same(input, run("markdown_wrap", input))
    assert.are.same({ "* * *" }, run("markdown_wrap", { "* * *" }))
    assert.are.same({ "---" }, run("markdown_wrap", { "---" }))
  end)

  it("keeps the indentation of a standalone paragraph while reflowing it", function()
    local input = {
      "  Párrafo sangrado con [[Windows 11 - Maquina Virtual]] y la sección de",
      "  [[Windows 11 - Maquina Virtual#drivers|drivers]].",
    }
    assert.are.same({
      "  Párrafo sangrado con [[Windows 11 - Maquina Virtual]] y la sección de "
        .. "[[Windows 11 - Maquina Virtual#drivers|drivers]].",
    }, run("markdown_wrap", input))
  end)
end)
