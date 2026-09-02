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

  --- Un directorio temporal con los archivos de configuración indicados.
  ---@param files table<string, string>
  ---@return conform.Context
  local function project(files)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")

    for name, contents in pairs(files) do
      vim.fn.writefile(vim.split(contents, "\n"), vim.fs.joinpath(dir, name))
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"

    return {
      buf = buf,
      filename = vim.fs.joinpath(dir, "nota.md"),
      dirname = dir,
    }
  end

  --- `markdown_wrap` con un ancho explícito.
  ---
  --- Estos tests comprueban *dónde* parte y cómo alinea, no con qué ancho por
  --- defecto. Fijarlo aquí los desacopla de `line_length`: cuando pasó de 97 a
  --- 85 (e4157d2, que solo tocó conform.lua) dos de ellos se quedaron en rojo
  --- sin que nada estuviera roto. El ancho se pide por el mismo camino que un
  --- proyecto real, un `.prettierrc`.
  local wrap_contexts = {}

  ---@param width integer
  ---@param lines string[]
  ---@return string[]
  local function wrap_at(width, lines)
    wrap_contexts[width] = wrap_contexts[width]
      or project { [".prettierrc"] = ('{ "printWidth": %d }'):format(width) }

    local result
    conform.formatters.markdown_wrap.format(nil, wrap_contexts[width], lines, function(err, value)
      assert.is_nil(err)
      result = value
    end)
    return result
  end

  describe("prose wrapping is opt-in", function()
    -- Cortar la prosa a un ancho fijo rompe el archivo en Obsidian y en
    -- cualquier editor gráfico, que vuelve a ajustar al ancho del panel encima
    -- de nuestros cortes. Por defecto no se corta; quien lo quiera lo pide en
    -- la configuración de Prettier de su proyecto.
    local markdown_wrap = require("lzy.conform").opts.formatters.markdown_wrap

    it("does not run in a project without Prettier configuration", function()
      assert.is_false(markdown_wrap.condition(nil, project {}))
    end)

    it("does not run when the project asks Prettier not to wrap", function()
      assert.is_false(
        markdown_wrap.condition(nil, project { [".prettierrc"] = '{ "proseWrap": "never" }' })
      )
    end)

    it("runs when the project asks Prettier to wrap", function()
      assert.is_true(
        markdown_wrap.condition(nil, project { [".prettierrc"] = '{ "proseWrap": "always" }' })
      )
    end)

    it("takes the width from the project, not from ours", function()
      local ctx = project { [".prettierrc"] = '{ "proseWrap": "always", "printWidth": 40 }' }
      local input = {
        "Un párrafo bastante largo que tiene que acabar cortado a cuarenta columnas "
          .. "y no a las ochenta y cinco de la configuración.",
      }
      local result

      markdown_wrap.format(nil, ctx, input, function(err, value)
        assert.is_nil(err)
        result = value
      end)

      for _, line in ipairs(result) do
        assert.is_true(#line <= 40, ("línea de %d columnas: %s"):format(#line, line))
      end
      assert.is_true(#result > 1)
    end)

    it("asks Prettier to join paragraphs, not to wrap them", function()
      -- `never` junta cada párrafo en una línea, así que además de no cortar
      -- repara los que quedaron cortados. Un salto suelto dentro de un párrafo
      -- no es un salto en CommonMark, así que juntarlo no cambia lo que se ve.
      local prettier = require("lzy.conform").opts.formatters.prettier
      local args = prettier.append_args(nil, project { ["nota.md"] = "# t" })
      local index
      for i, value in ipairs(args) do
        if value == "--prose-wrap" then
          index = i
          break
        end
      end

      -- luassert acepta el mensaje; su stub de tipos dice que no.
      ---@diagnostic disable-next-line: redundant-parameter
      assert.is_not_nil(index, "faltan los argumentos de ajuste de prosa")
      assert.are.equal("never", args[index + 1])

      -- Y aun así el proyecto manda: con `--config-precedence file-override` un
      -- `.prettierrc` con `proseWrap: always` gana a este `never`.
      assert.is_true(vim.tbl_contains(args, "--config-precedence"))
      assert.is_true(vim.tbl_contains(args, "file-override"))
    end)
  end)

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
      "",
      "```spoiler-block",
      "otro      cuerpo",
      "```",
    }
    local prepared = run("markdown_spoilers_prepare", source)
    assert.are.equal("```markdown hzsr-internal-spoiler-fence", prepared[1])
    assert.are.equal("~~~lua", prepared[7])
    assert.are.equal("```spoiler", prepared[12])
    -- El nombre largo lleva su propio marcador: la vuelta tiene que devolver
    -- el que había escrito, no el otro.
    assert.are.equal("```markdown hzsr-internal-spoiler-block-fence", prepared[17])

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
      "",
      "```markdown hzsr-internal-spoiler-block-fence",
      "otro cuerpo",
      "```",
    })
    assert.are.equal("```spoiler", restored[1])
    assert.are.equal("# Heading", restored[2])
    assert.are.equal("text with spaces", restored[4])
    assert.are.equal("```lua", restored[7])
    assert.are.equal("```spoiler-block", restored[11])
    assert.are.equal("otro cuerpo", restored[12])
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
    local wrapped = wrap_at(97, input)
    assert.are.same(expected, wrapped)
    assert.are.same(expected, wrap_at(97, wrapped))

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
    local wrapped = wrap_at(97, input)
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
    assert.are.same(expected, wrap_at(97, input))
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
    assert.are.same(input, wrap_at(97, input))
    assert.are.same({ "* * *" }, wrap_at(97, { "* * *" }))
    assert.are.same({ "---" }, wrap_at(97, { "---" }))
  end)

  it("keeps the indentation of a standalone paragraph while reflowing it", function()
    local input = {
      "  Párrafo sangrado con [[Windows 11 - Maquina Virtual]] y la sección de",
      "  [[Windows 11 - Maquina Virtual#drivers|drivers]].",
    }
    assert.are.same({
      "  Párrafo sangrado con [[Windows 11 - Maquina Virtual]] y la sección de "
        .. "[[Windows 11 - Maquina Virtual#drivers|drivers]].",
    }, wrap_at(97, input))
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
    local wrapped = wrap_at(97, input)
    assert.are.same(expected, wrapped)
    assert.are.same(expected, wrap_at(97, wrapped))
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
    local wrapped = wrap_at(97, input)
    assert.are.same(expected, wrapped)
    assert.are.same(expected, wrap_at(97, wrapped))
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
    assert.are.same(expected, wrap_at(97, input))

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
    assert.are.same(fence, wrap_at(97, fence))

    local table_in_quote = {
      "> | a | b |",
      "> | - | - |",
    }
    assert.are.same(table_in_quote, wrap_at(97, table_in_quote))

    -- Con más de tres espacios ya no es una cita de primer nivel, así que no
    -- se toca (aquí sería la cita de un ítem de lista).
    local indented = {
      "    > cita muy sangrada con [Windows](/docs/Compilador%20de%20C.md#windows) y",
      "    > texto que se queda como está.",
    }
    assert.are.same(indented, wrap_at(97, indented))
  end)
end)
