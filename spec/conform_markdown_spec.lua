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

  it("discounts an emphasis that spans several words, not only one", function()
    -- Los marcadores se repartían entre la primera palabra y la última, y
    -- midiendo palabra a palabra ninguna de las dos veía a su pareja: cuatro
    -- columnas de más bastaban para partir una línea que cabía.
    local input = {
      "- **[tree-sitter-cli](/docs/tree-sitter-cli.md) 0.26.1 o superior** — necesario para que",
      "  `nvim-treesitter` compile los parsers.",
    }
    local expected = {
      "- **[tree-sitter-cli](/docs/tree-sitter-cli.md) 0.26.1 o superior** — necesario para que "
        .. "`nvim-treesitter` compile los parsers.",
    }
    assert.are.same(expected, run("markdown_wrap", input))
    assert.are.equal(95, hzsr.md.visible_width(expected[1]))

    -- Y sólo el énfasis de verdad: un `_` dentro de una palabra, un `*` de
    -- multiplicación o un marcador sin pareja siguen ocupando su columna.
    local literal = "un foo_bar con 10 * 5 y un _suelto"
    assert.are.equal(#literal, hzsr.md.visible_width(literal))
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

  it("reflows quoted prose by visible width, discounting the marker", function()
    -- Prettier parte la cita por lo mismo que el resto: cuenta el destino
    -- entero del enlace (104 columnas en bruto) aunque lo que se ve quepa de
    -- sobra (66 contando icono + label).
    local input = {
      "> NOTA: Si vienes desde otra nota, empieza a leer desde",
      "> [Windows](/docs/Compilador%20de%20C.md#windows).",
    }
    local expected = {
      "> NOTA: Si vienes desde otra nota, empieza a leer desde "
        .. "[Windows](/docs/Compilador%20de%20C.md#windows).",
    }
    local wrapped = run("markdown_wrap", input)
    assert.are.same(expected, wrapped)
    assert.are.same(expected, run("markdown_wrap", wrapped))
    assert.is_true(#wrapped[1] > 97)
    assert.is_true(hzsr.md.visible_width(wrapped[1]) <= 97)
  end)

  it("reflows the body of a callout without touching its header or separators", function()
    local input = {
      "> [!NOTE] Un título que se queda como está",
      ">",
      "> Cuerpo con [Windows](/docs/Compilador%20de%20C.md#windows) y texto que",
      "> debería juntarse.",
      ">",
      "> - ítem con [Windows](/docs/Compilador%20de%20C.md#windows) y texto que",
      ">   también debería juntarse.",
    }
    local expected = {
      "> [!NOTE] Un título que se queda como está",
      ">",
      "> Cuerpo con [Windows](/docs/Compilador%20de%20C.md#windows) y texto que debería juntarse.",
      ">",
      "> - ítem con [Windows](/docs/Compilador%20de%20C.md#windows) y texto que también debería "
        .. "juntarse.",
    }
    local wrapped = run("markdown_wrap", input)
    assert.are.same(expected, wrapped)
    assert.are.same(expected, run("markdown_wrap", wrapped))
  end)

  it("discounts one quote marker per level when measuring nested content", function()
    local input = {
      "> > cita anidada con [Windows](/docs/Compilador%20de%20C.md#windows) y texto",
      "> > que debería juntarse.",
    }
    local expected = {
      "> > cita anidada con [Windows](/docs/Compilador%20de%20C.md#windows) y texto que debería "
        .. "juntarse.",
    }
    assert.are.same(expected, run("markdown_wrap", input))

    -- El ancho disponible baja lo que ocupa el marcador: medido como se ve, el
    -- contenido de la cita anidada cabe en 97 menos las cuatro columnas de
    -- `> > `.
    local content = expected[1]:sub(5)
    assert.is_true(4 + hzsr.md.visible_width(content) <= 97)
  end)

  it("leaves fences, tables and deeper indentation inside a quote untouched", function()
    local fence = {
      "> ```powershell",
      "> cl   /nologo    algo.c",
      "> ```",
    }
    assert.are.same(fence, run("markdown_wrap", fence))

    local table_in_quote = {
      "> | a | b |",
      "> | - | - |",
    }
    assert.are.same(table_in_quote, run("markdown_wrap", table_in_quote))

    -- Con más de tres espacios ya no es una cita de primer nivel, así que no
    -- se toca (aquí sería la cita de un ítem de lista).
    local indented = {
      "    > cita muy sangrada con [Windows](/docs/Compilador%20de%20C.md#windows) y",
      "    > texto que se queda como está.",
    }
    assert.are.same(indented, run("markdown_wrap", indented))
  end)
end)
