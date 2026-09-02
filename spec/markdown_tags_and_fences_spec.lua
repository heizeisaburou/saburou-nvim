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
  "lzy.render-markdown.code",
  "lzy.render-markdown.inline",
  "lzy.render-markdown.links",
  "lzy.render-markdown.spoilers",
  "lzy.render-markdown.tags",
}) do
  package.loaded[name] = nil
end

local function extmarks(bufnr, namespace)
  return vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
end

describe("Sabunv Markdown tags", function()
  local bufnr
  local namespace
  local lines = {
    "Notas sueltas #tag y #otro/anidado al final",
    "",
    "## Título con #dentro",
    "",
    "Código `#include <stdio.h>` y enlace [Windows](/docs/nota.md#windows)",
    "",
    "Nada de tags: # solo, #123 y #ff00ff",
  }

  --- Rangos (fila, columna inicial, columna final) con el chip de tag.
  local function chips()
    local result = {}
    for _, mark in ipairs(extmarks(bufnr, namespace)) do
      local details = mark[4]
      if details.hl_group == "RenderMarkdownTag" then
        result[#result + 1] = { mark[2], mark[3], details.end_col }
      end
    end
    table.sort(result, function(a, b)
      return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
    end)
    return result
  end

  before_each(function()
    require("lzy.render-markdown.spoilers").setup()
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
        return #chips() > 0
      end, 10),
      "render-markdown no llegó a pintar ningún tag"
    )
  end)

  after_each(function()
    vim.cmd "silent! %bwipeout!"
  end)

  it("marks every tag the index would find, hash included", function()
    local line = lines[1]
    local tag = line:find("#tag", 1, true) - 1
    local nested = line:find("#otro/anidado", 1, true) - 1
    local heading = lines[3]:find("#dentro", 1, true) - 1

    assert.are.same({
      { 0, tag, tag + #"#tag" },
      { 0, nested, nested + #"#otro/anidado" },
      -- Dentro de un heading también: el chip va por encima de la banda.
      { 2, heading, heading + #"#dentro" },
    }, chips())
  end)

  it("leaves code spans, link destinations and non-tags alone", function()
    for _, chip in ipairs(chips()) do
      assert.are_not.equal(4, chip[1])
      assert.are_not.equal(6, chip[1])
    end
  end)
end)

describe("Sabunv Markdown code fences", function()
  local bufnr
  local namespace
  local code
  local lines = {
    "Antes",
    "",
    "```",
    "```",
    "",
    "```lua",
    "```",
    "",
    "```lua",
    "local x = 1",
    "```",
    "",
    "> [!tip]",
    ">",
    "> ```",
    "> ```",
    "",
    "```",
    "",
    "```",
    "",
    "```",
    "   ",
    "```",
    "",
    "> [!note]",
    ">",
    "> ```",
    ">",
    "> ```",
    "",
    "```",
    ">",
    "```",
    "",
    "```",
    "texto sin lenguaje",
    "```",
    "",
    "```sh",
    "echo sin cerrar",
    "",
    "y esto ya no debería ser código",
  }

  local function virtual_texts(row)
    local result = {}
    for _, mark in ipairs(extmarks(bufnr, namespace)) do
      if mark[2] == row then
        for _, chunk in ipairs(mark[4].virt_text or {}) do
          result[#result + 1] = chunk[1]
        end
      end
    end
    return result
  end

  --- ¿Hay una banda de color que devuelva esta fila a la pantalla?
  local function band(row)
    for _, mark in ipairs(extmarks(bufnr, namespace)) do
      local details = mark[4]
      if mark[2] == row and details.hl_eol and not details.virt_text then
        return details.hl_group
      end
    end
  end

  --- ¿Está esta banda concreta en la fila? El fondo del propio plugin también
  --- llega hasta el final de la línea, así que hay que buscar la nuestra.
  local function has_band(row, group)
    for _, mark in ipairs(extmarks(bufnr, namespace)) do
      local details = mark[4]
      if mark[2] == row and details.hl_eol and details.hl_group == group then
        return true
      end
    end
    return false
  end

  local function hidden_line(row)
    for _, mark in ipairs(extmarks(bufnr, namespace)) do
      if mark[2] == row and mark[4].conceal_lines then
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
    code = require "lzy.render-markdown.code"
    require("lzy.render-markdown.spoilers").setup()
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
    move(0)

    assert(
      vim.wait(1000, function()
        return band(2) ~= nil
      end, 10),
      "render-markdown no llegó a marcar el bloque vacío"
    )
  end)

  after_each(function()
    vim.cmd "silent! %bwipeout!"
  end)

  it("gives an empty fence its lines back, with a label on the opening one", function()
    assert.are.equal("RenderMarkdownCodeEmpty", band(2))
    assert.are.equal("RenderMarkdownCodeEmpty", band(3))
    assert.is_false(hidden_line(2))
    assert.is_false(hidden_line(3))
    assert.are.same({ " ▲ " .. code.empty_text .. " " }, virtual_texts(2))
    assert.are.same({}, virtual_texts(3))
  end)

  it("keeps the language of an empty fence in its own label", function()
    assert.are.equal("RenderMarkdownCodeEmpty", band(5))
    assert.is_false(hidden_line(5))
    assert.are.same({ " ▲ lua · " .. code.empty_text .. " " }, virtual_texts(5))
  end)

  it("flags a fence that was never closed", function()
    assert.are.equal("RenderMarkdownCodeUnclosed", band(39))
    assert.is_false(hidden_line(39))
    assert.are.same({ " ▲ sh · " .. code.unclosed_text .. " " }, virtual_texts(39))
  end)

  it("treats a body of only blank lines as empty", function()
    -- Un salto de línea suelto sí crea `code_fence_content`, pero no es nada.
    assert.is_true(has_band(17, "RenderMarkdownCodeEmpty"))
    assert.is_true(has_band(19, "RenderMarkdownCodeEmpty"))
    assert.is_false(hidden_line(17))
    assert.is_false(hidden_line(19))
    assert.are.same({ " ▲ " .. code.empty_text .. " " }, virtual_texts(17))

    -- Y un cuerpo de solo espacios, tampoco.
    assert.is_true(has_band(21, "RenderMarkdownCodeEmpty"))
    assert.is_true(has_band(23, "RenderMarkdownCodeEmpty"))
    assert.are.same({ " ▲ " .. code.empty_text .. " " }, virtual_texts(21))
  end)

  it("does not count the quote markers of a callout as body", function()
    assert.is_true(has_band(27, "RenderMarkdownCodeEmpty"))
    assert.is_true(has_band(29, "RenderMarkdownCodeEmpty"))
    assert.is_false(hidden_line(27))
    assert.is_false(hidden_line(29))
    assert.are.same({ "▋", " ▲ " .. code.empty_text .. " " }, virtual_texts(27))
  end)

  it("counts a > written inside the block as body", function()
    -- Fuera de una cita ese `>` es código, no el prefijo de nadie: el bloque
    -- tiene cuerpo, y lo que le falta es el lenguaje.
    assert.is_false(has_band(31, "RenderMarkdownCodeEmpty"))
    assert.is_true(has_band(31, "RenderMarkdownCodePlain"))
  end)

  it("gives a fence without language a header of its own", function()
    assert.is_true(has_band(35, "RenderMarkdownCodePlain"))
    assert.is_false(hidden_line(35))
    assert.are.same({ " " .. code.plain_text .. " " }, virtual_texts(35))
    -- El cierre se oculta, igual que el de un bloque con lenguaje: la cabecera
    -- ya dice dónde empieza, y con eso el bloque deja de ser invisible.
    assert.is_true(hidden_line(37))
  end)

  it("hides the plain header under the cursor and keeps its band", function()
    move(35)
    assert(
      vim.wait(1000, function()
        return #virtual_texts(35) == 0
      end, 10),
      "la cabecera de texto plano no se apartó con el cursor encima"
    )
    assert.is_true(has_band(35, "RenderMarkdownCodePlain"))
  end)

  it("rescues an empty fence inside a callout without losing its quote bar", function()
    assert.are.equal("RenderMarkdownCodeEmpty", band(14))
    assert.are.equal("RenderMarkdownCodeEmpty", band(15))
    -- La banda empieza detrás del `> `, y la barra de la cita sigue puesta.
    assert.are.same({ "▋", " ▲ " .. code.empty_text .. " " }, virtual_texts(14))
    assert.are.same({ "▋" }, virtual_texts(15))
  end)

  it("does not touch a normal code block", function()
    assert.is_false(has_band(8, "RenderMarkdownCodeEmpty"))
    assert.is_false(has_band(8, "RenderMarkdownCodeUnclosed"))
    assert.is_false(has_band(8, "RenderMarkdownCodePlain"))
    -- La etiqueta de lenguaje del plugin sigue en su sitio y el cierre oculto.
    assert.are.same({ "lua" }, vim.list_slice(virtual_texts(8), 1, 1))
    assert.is_true(hidden_line(10))
  end)

  it("hides the label under the cursor and keeps the band", function()
    move(2)
    assert(
      vim.wait(1000, function()
        return #virtual_texts(2) == 0
      end, 10),
      "la etiqueta no se apartó con el cursor encima"
    )
    assert.are.equal("RenderMarkdownCodeEmpty", band(2))
  end)
end)
