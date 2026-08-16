local plugin = "/home/saburou/.local/share/hzsr12/lazy/obsidian.nvim"
local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:prepend(plugin)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Nyabsidian structured links and attachments", function()
  local uv = vim.uv or vim.loop
  local root = vim.fn.tempname()
  local notifications = {}
  local initialized = false

  local function write(path, lines)
    local absolute = vim.fs.joinpath(root, path)
    vim.fn.mkdir(vim.fs.dirname(absolute), "p")
    vim.fn.writefile(lines, absolute)
  end

  local function write_binary(path)
    local absolute = vim.fs.joinpath(root, path)
    vim.fn.mkdir(vim.fs.dirname(absolute), "p")
    local fd = assert(uv.fs_open(absolute, "w", 420))
    assert(uv.fs_write(fd, "\137PNG\r\n\26\n\0binary", -1))
    assert(uv.fs_close(fd))
  end

  local function reset_fixture()
    vim.cmd "silent! %bwipeout!"
    write("nota.md", {
      "# Header",
      "",
      "## Subheader",
      "",
      "### Child",
    })
    write("source.md", {
      "[[nota#header#subheader]]",
      "[[nota#subheader]]",
      "[[nota#header#subheader#child]]",
      "[[nota#child]]",
      "[label](nota.md#header#subheader)",
      "[[nota#missing]]",
    })
    notifications = {}
    vim.cmd.edit(vim.fs.joinpath(root, "source.md"))
  end

  before_each(function()
    vim.fn.mkdir(root, "p")
    vim.fn.chdir(root)
    if not initialized then
      require("lzy.obsidian.links").setup {
        notify = function(msg, level)
          notifications[#notifications + 1] = { msg = msg, level = level }
        end,
      }
      require("obsidian").setup {
        legacy_commands = false,
        workspaces = { { path = root } },
        picker = { name = false },
        footer = { enabled = false },
        frontmatter = { enabled = false },
        ui = { enable = false },
        log_level = vim.log.levels.ERROR,
        search = { max_lines = 2 }, -- Nyabsidian debe leer la nota completa.
      }
      initialized = true
    end
    assert(require("lzy.obsidian.attachments").configure(root, nil))
    reset_fixture()
  end)

  after_each(function()
    vim.cmd "silent! %bwipeout!"
    vim.fn.delete(root, "rf")
    vim.fn.delete(root .. "-external", "rf")
    -- Algunos tests sustituyen el prompt de creación de nota; que no se
    -- filtre a los siguientes.
    local new_note = require "lzy.obsidian.new_note"
    new_note.confirm = new_note.default_confirm
    new_note.notify = new_note.default_notify
  end)

  it("resolves nested headings past the upstream max_lines limit", function()
    vim.api.nvim_win_set_cursor(0, { 3, 18 })
    assert.matches("Obsidian follow_link", require("obsidian.actions").smart_action())

    local locations
    require("obsidian.lsp.handlers")["textDocument/definition"]({}, function(err, result)
      assert.is_nil(err)
      locations = result
    end, {})
    vim.wait(3000, function()
      return locations ~= nil
    end, 10)

    assert.are.equal(1, #locations)
    assert.are.equal(vim.fs.joinpath(root, "nota.md"), vim.uri_to_fname(locations[1].uri))
    assert.are.equal(4, locations[1].range.start.line)
  end)

  it("diagnoses a missing heading but falls back to the existing note", function()
    local locations
    require("obsidian.lsp.handlers._definition").follow_link(
      "[[nota#missing]]",
      function(_, result)
        locations = result
      end,
      { bufnr = 0 }
    )
    vim.wait(3000, function()
      return locations ~= nil
    end, 10)

    assert.are.equal(1, #locations)
    assert.are.equal(vim.fs.joinpath(root, "nota.md"), vim.uri_to_fname(locations[1].uri))
    assert.are.equal(0, locations[1].range.start.line)
    assert.are.equal(vim.log.levels.ERROR, notifications[#notifications].level)
    assert.matches("missing", notifications[#notifications].msg)
  end)

  it("opens text attachments directly in nvim", function()
    write("asset.custom", { "attachment" })
    write("source.md", { "![[asset.custom]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 5 })

    require("obsidian.lsp.handlers")["textDocument/definition"]({}, function() end, {})
    vim.wait(1000, function()
      return vim.api.nvim_buf_get_name(0) == vim.fs.joinpath(root, "asset.custom")
    end, 10)

    assert.are.equal(vim.fs.joinpath(root, "asset.custom"), vim.api.nvim_buf_get_name(0))
  end)

  it("opens binary attachments through the system", function()
    write_binary "image.png"
    write("source.md", { "![[image.png]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 5 })

    local opened
    local original_open = vim.ui.open
    vim.ui.open = function(path)
      opened = vim.fs.normalize(tostring(path))
    end
    require("obsidian.lsp.handlers")["textDocument/definition"]({}, function() end, {})
    vim.wait(1000, function()
      return opened ~= nil
    end, 10)
    vim.ui.open = original_open

    assert.are.equal(vim.fs.joinpath(root, "image.png"), opened)
  end)

  it("opens attachments from the smart action without an empty note picker", function()
    write_binary "action.png"
    write("source.md", { "![[action.png]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 6 })

    assert.matches("Obsidian follow_link", require("obsidian.actions").smart_action())
    local opened, picked
    local original_open, original_pick = vim.ui.open, Obsidian.picker.pick
    vim.ui.open = function(path)
      opened = vim.fs.normalize(tostring(path))
    end
    Obsidian.picker.pick = function()
      picked = true
    end
    require("obsidian.actions").follow_link()
    vim.wait(1000, function()
      return opened ~= nil
    end, 10)
    vim.ui.open, Obsidian.picker.pick = original_open, original_pick

    assert.are.equal(root .. "/action.png", opened)
    assert.is_nil(picked)
  end)

  it("uses the same resolver for gx", function()
    write_binary "gx.png"
    write("source.md", { "![[gx.png]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 5 })

    local opened
    local original_open = vim.ui.open
    vim.ui.open = function(path)
      opened = vim.fs.normalize(tostring(path))
    end
    assert.is_true(require("lzy.obsidian.attachments").open_under_cursor(0))
    vim.wait(1000, function()
      return opened ~= nil
    end, 10)
    vim.ui.open = original_open

    assert.are.equal(root .. "/gx.png", opened)
  end)

  it("follows the real link of a badge, not the image that labels it", function()
    -- `[![alt](img)](url)`: obsidian.nvim solo ve la imagen, así que `gx` y la
    -- acción inteligente abrían el SVG del badge en vez del enlace.
    local badge = "[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)]"
      .. "(https://www.paypal.com/donate/?hosted_button_id=W9K3ZTUM2QNAC)"
    write("source.md", { badge })
    vim.cmd.edit(root .. "/source.md")

    local original_open = vim.ui.open
    local function opened_at(col, follow)
      vim.api.nvim_win_set_cursor(0, { 1, col })
      local opened
      vim.ui.open = function(target)
        opened = target
      end
      if follow then
        require("obsidian.actions").follow_link()
      else
        assert.is_true(require("lzy.obsidian.attachments").open_under_cursor(0))
      end
      vim.wait(1000, function()
        return opened ~= nil
      end, 10)
      return opened
    end

    local paypal = "https://www.paypal.com/donate/?hosted_button_id=W9K3ZTUM2QNAC"
    local shield = "https://img.shields.io/badge/Donate-PayPal-blue.svg"

    -- Sobre el texto que se ve (`Donate`) manda el enlace, con gx y con <CR>.
    assert.are.equal(paypal, opened_at(4, false))
    assert.are.equal(paypal, opened_at(4, true))
    -- Y sobre el `](url)` del final, también.
    assert.are.equal(paypal, opened_at(#badge - 5, false))
    -- La imagen sigue siendo alcanzable donde se la pide a propósito: encima de
    -- su propio destino.
    assert.are.equal(shield, opened_at(30, false))

    vim.ui.open = original_open
  end)

  it("keeps gx for angle-bracket URLs inside a vault", function()
    write("source.md", { "<https://example.com/path>" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    local opened
    local original_open = vim.ui.open
    vim.ui.open = function(target)
      opened = target
    end
    assert.is_true(require("lzy.obsidian.attachments").open_under_cursor(0))
    vim.ui.open = original_open

    assert.are.equal("https://example.com/path", opened)
  end)

  it("resolves local, unique, explicit and duplicate vault attachments like Obsidian", function()
    write("one/a.png", { "one" })
    write("two/a.png", { "two" })
    write("elsewhere/unique.pdf", { "pdf" })
    write("one/note.md", { "![[a.png]]" })
    local attachments = require "lzy.obsidian.attachments"

    local local_result = attachments.resolve("a.png", {
      source_path = root .. "/one/note.md",
      root = root,
    })
    assert.are.equal("resolved", local_result.status)
    assert.are.equal(root .. "/one/a.png", local_result.path)

    local duplicate = attachments.resolve("a.png", {
      source_path = root .. "/source.md",
      root = root,
    })
    assert.are.equal("resolved", duplicate.status)
    assert.are.equal(root .. "/one/a.png", duplicate.path)
    assert.are.same({ root .. "/one/a.png", root .. "/two/a.png" }, duplicate.candidates)

    local explicit = attachments.resolve("two/a.png", {
      source_path = root .. "/one/note.md",
      root = root,
    })
    assert.are.equal("resolved", explicit.status)
    assert.are.equal(root .. "/two/a.png", explicit.path)

    local unique = attachments.resolve("unique.pdf", {
      source_path = root .. "/source.md",
      root = root,
    })
    assert.are.equal("resolved", unique.status)
    assert.are.equal(root .. "/elsewhere/unique.pdf", unique.path)
  end)

  it("never uses attachments.folder to resolve an existing link", function()
    write("real/location.png", { "image" })
    local original = Obsidian.opts.attachments.folder
    Obsidian.opts.attachments.folder = "wrong-folder"

    local result = require("lzy.obsidian.attachments").resolve("location.png", {
      source_path = root .. "/source.md",
      root = root,
    })
    Obsidian.opts.attachments.folder = original

    assert.are.equal("resolved", result.status)
    assert.are.equal(root .. "/real/location.png", result.path)
  end)

  it("reproduces Obsidian's source-folder, suffix, length and case rules", function()
    write("short/a.png", { "short" })
    write("notes/deep/a.png", { "near source" })
    write("elsewhere/very/deep/a.png", { "far" })
    local attachments = require "lzy.obsidian.attachments"
    local opts = { source_path = root .. "/notes/source.md", root = root }

    -- Los descendientes de la carpeta origen ganan incluso si otro path es
    -- globalmente más corto.
    assert.are.equal(root .. "/notes/deep/a.png", attachments.resolve("A.PNG", opts).path)
    -- Un sufijo identifica la misma ruta que getLinkpathDest().
    assert.are.equal(
      root .. "/elsewhere/very/deep/a.png",
      attachments.resolve("very/deep/a.png", opts).path
    )

    local root_opts = { source_path = root .. "/source.md", root = root }
    assert.are.equal(root .. "/short/a.png", attachments.resolve("a.png", root_opts).path)
  end)

  it("allows an explicit attachment outside the vault", function()
    local external = root .. "-external.bin"
    vim.fn.writefile({ "external" }, external)
    local target = "../" .. vim.fs.basename(external)

    local result = require("lzy.obsidian.attachments").resolve(target, {
      source_path = root .. "/source.md",
      root = root,
    })

    assert.are.equal("resolved", result.status)
    assert.is_true(result.external)
    assert.are.equal(external, result.path)
    assert.is_false(require("lzy.obsidian.attachments").is_target("image.png", {
      source_path = root .. "-different/source.md",
      root = root,
    }))
    vim.fn.delete(external)
  end)

  it("supports extensionless plugin files without stealing a note", function()
    write("plugin-data", { "plugin" })
    write("same", { "attachment" })
    write("same.md", { "# Note" })
    local attachments = require "lzy.obsidian.attachments"
    local opts = { source_path = root .. "/source.md", root = root }

    assert.is_true(attachments.is_target("plugin-data", opts))
    assert.is_false(attachments.is_target("same", opts))
  end)

  it("does not cross into a nested vault during basename lookup", function()
    write("nested/.nyabsidian", { "return {}" })
    write("nested/a.png", { "nested" })

    local result = require("lzy.obsidian.attachments").resolve("a.png", {
      source_path = root .. "/source.md",
      root = root,
    })

    assert.are.equal("missing", result.status)
  end)

  it("opens the same best duplicate match as the Obsidian app", function()
    write_binary "one/a.png"
    write_binary "two/a.png"
    write("source.md", { "![[a.png]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    assert.matches("Obsidian follow_link", require("obsidian.actions").smart_action())

    local selected, opened
    local original_select, original_open = vim.ui.select, vim.ui.open
    vim.ui.select = function(entries, _, callback)
      selected = entries
      callback(entries[2])
    end
    vim.ui.open = function(path)
      opened = vim.fs.normalize(tostring(path))
    end
    require("obsidian.lsp.handlers")["textDocument/definition"]({}, function() end, {})
    vim.wait(1000, function()
      return opened ~= nil
    end, 10)
    vim.ui.select, vim.ui.open = original_select, original_open

    assert.is_nil(selected)
    assert.are.equal(root .. "/one/a.png", opened)
  end)

  it("keeps Obsidian's duplicate winner between prepareRename and rename", function()
    write("one/a.png", { "one" })
    write("two/a.png", { "two" })
    write("source.md", { "![[a.png]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 5 })

    local selections = 0
    local original_select = vim.ui.select
    vim.ui.select = function(entries, _, callback)
      selections = selections + 1
      callback(entries[1])
    end

    local prepared
    require("obsidian.lsp.handlers")["textDocument/prepareRename"]({}, function(err, value)
      assert.is_nil(err)
      prepared = value
    end, {})
    vim.wait(1000, function()
      return prepared ~= nil
    end, 10)

    local renamed = false
    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "chosen" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
        renamed = true
      end,
      {}
    )
    vim.wait(1000, function()
      return renamed
    end, 10)
    vim.cmd "silent! wall"
    vim.ui.select = original_select

    assert.are.equal(0, selections)
    assert.are.equal("one/a.png", prepared.placeholder)
    assert.are.equal("![[chosen.png]]", vim.fn.readfile(root .. "/source.md")[1])
    assert.is_not_nil((vim.uv or vim.loop).fs_stat(root .. "/chosen.png"))
    assert.is_nil((vim.uv or vim.loop).fs_stat(root .. "/one/chosen.png"))
    assert.is_not_nil((vim.uv or vim.loop).fs_stat(root .. "/two/a.png"))
  end)

  it("treats a bare attachment rename as a destination at the vault root", function()
    write("attachments/nyaruko-taquilla.gif", { "gif" })
    write("source.md", { "![[nyaruko-taquilla.gif]]" })
    vim.cmd.edit(root .. "/source.md")

    local destination = require("lzy.obsidian.attachments").destination(
      root .. "/attachments/nyaruko-taquilla.gif",
      "nyaruko-taquilla_otro.gif",
      { bufnr = 0 }
    )

    assert.are.equal(root .. "/nyaruko-taquilla_otro.gif", destination)
  end)

  it("prepares attachment rename with its editable vault location", function()
    write("assets/photo.png", { "image" })
    write("source.md", { "![[assets/photo.png|300]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    local result
    require("obsidian.lsp.handlers")["textDocument/prepareRename"]({}, function(err, value)
      assert.is_nil(err)
      result = value
    end, {})
    vim.wait(1000, function()
      return result ~= nil
    end, 10)

    assert.are.equal("assets/photo.png", result.placeholder)
    assert.are.same({ 3, 19 }, { result.range.start.character, result.range["end"].character })
  end)

  it("prepares rename for the exact link component under the cursor", function()
    local handler = require("obsidian.lsp.handlers")["textDocument/prepareRename"]
    local function placeholder(col)
      vim.api.nvim_win_set_cursor(0, { 1, col })
      local result
      handler({}, function(err, value)
        assert.is_nil(err)
        result = value
      end, {})
      vim.wait(3000, function()
        return result ~= nil
      end, 10)
      return result.placeholder, result.range
    end

    local note, note_range = placeholder(3)
    local header, header_range = placeholder(8)
    local subheader, subheader_range = placeholder(15)
    assert.are.equal("nota", note)
    assert.are.same({ 2, 6 }, { note_range.start.character, note_range["end"].character })
    assert.are.equal("Header", header)
    assert.are.same({ 7, 13 }, { header_range.start.character, header_range["end"].character })
    assert.are.equal("Subheader", subheader)
    assert.are.same(
      { 14, 23 },
      { subheader_range.start.character, subheader_range["end"].character }
    )
  end)

  it("prepares Markdown labels and external URLs as independent rename targets", function()
    write("source.md", { "[gh](https://github.com)" })
    vim.cmd.edit(root .. "/source.md")
    local handler = require("obsidian.lsp.handlers")["textDocument/prepareRename"]
    local function prepared_at(col)
      vim.api.nvim_win_set_cursor(0, { 1, col })
      local result
      handler({}, function(err, value)
        assert.is_nil(err)
        result = value
      end, {})
      return result
    end

    local label = prepared_at(2)
    assert.are.equal("gh", label.placeholder)
    assert.are.same({ 1, 3 }, { label.range.start.character, label.range["end"].character })

    local url = prepared_at(10)
    assert.are.equal("https://github.com", url.placeholder)
    assert.are.same({ 5, 23 }, { url.range.start.character, url.range["end"].character })
  end)

  it("renames an external Markdown URL locally instead of waiting for a note", function()
    write("source.md", { '[gh](https://github.com "GitHub")' })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    local called = false
    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "https://githuba.com" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
        called = true
      end,
      {}
    )

    assert.is_true(called)
    assert.are.equal('[gh](https://githuba.com "GitHub")', vim.api.nvim_get_current_line())
  end)

  it("renames a Markdown label without changing its destination", function()
    write("source.md", { "[gh](https://github.com)" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 2 })

    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "GitHub" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      end,
      {}
    )

    assert.are.equal("[GitHub](https://github.com)", vim.api.nvim_get_current_line())
  end)

  it("renames the destination of an angle-bracket autolink", function()
    write("source.md", { "<https://github.com>" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "https://githuba.com" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      end,
      {}
    )

    assert.are.equal("<https://githuba.com>", vim.api.nvim_get_current_line())
  end)

  it("prepares and renames reference-definition identifiers and URLs independently", function()
    write("source.md", {
      '[gh]: <https://github.com> "GitHub"',
      "[GitHub][gh]",
      "[gh][]",
      "[gh]",
    })
    vim.cmd.edit(root .. "/source.md")
    local handler = require("obsidian.lsp.handlers")["textDocument/prepareRename"]
    local function prepared_at(col)
      vim.api.nvim_win_set_cursor(0, { 1, col })
      local result
      handler({}, function(err, value)
        assert.is_nil(err)
        result = value
      end, {})
      return result
    end

    local label = prepared_at(2)
    assert.are.equal("gh", label.placeholder)
    assert.are.same({ 1, 3 }, { label.range.start.character, label.range["end"].character })

    local url = prepared_at(12)
    assert.are.equal("https://github.com", url.placeholder)
    assert.are.same({ 7, 25 }, { url.range.start.character, url.range["end"].character })

    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "https://githuba.com" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      end,
      {}
    )
    assert.are.equal('[gh]: <https://githuba.com> "GitHub"', vim.api.nvim_get_current_line())

    vim.api.nvim_win_set_cursor(0, { 1, 2 })
    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "GitHub" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      end,
      {}
    )
    assert.are.same({
      '[GitHub]: <https://githuba.com> "GitHub"',
      "[GitHub][GitHub]",
      "[GitHub][]",
      "[GitHub]",
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("does not duplicate .md when renaming a reference-definition note target", function()
    write("other_a.md", { "# Other A" })
    write("source.md", { '[algoa]: other_a.md "Descripción opcional"' })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 12 })

    local renamed = false
    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "other_aaa.md" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
        renamed = true
      end,
      {}
    )
    assert(vim.wait(1000, function()
      return renamed
    end, 10), "note rename did not finish")
    vim.cmd "silent! wall"

    assert.are.equal(
      '[algoa]: other_aaa.md "Descripción opcional"',
      vim.fn.readfile(root .. "/source.md")[1]
    )
    assert.is_not_nil((vim.uv or vim.loop).fs_stat(root .. "/other_aaa.md"))
    assert.is_nil((vim.uv or vim.loop).fs_stat(root .. "/other_aaa.md.md"))
  end)

  it("prepares and renames each reference description without changing its delimiters", function()
    write("other_a.md", { "# Other A" })
    write("source.md", {
      '[double]: other_a.md "Double description"',
      "[single]: other_a.md 'Single description'",
      "[paren]: other_a.md (Paren description)",
    })
    vim.cmd.edit(root .. "/source.md")

    local cases = {
      { row = 1, search = "Double description", replacement = "Renamed double" },
      { row = 2, search = "Single description", replacement = "Renamed single" },
      { row = 3, search = "Paren description", replacement = "Renamed paren" },
    }
    local prepare = require("obsidian.lsp.handlers")["textDocument/prepareRename"]
    local rename = require("obsidian.lsp.handlers")["textDocument/rename"]
    for _, case in ipairs(cases) do
      local line = vim.api.nvim_buf_get_lines(0, case.row - 1, case.row, false)[1]
      local start_col = assert(line:find(case.search, 1, true)) - 1
      vim.api.nvim_win_set_cursor(0, { case.row, start_col + 2 })

      local prepared
      prepare({}, function(err, value)
        assert.is_nil(err)
        prepared = value
      end, {})
      assert.are.equal(case.search, prepared.placeholder)
      assert.are.same(
        { start_col, start_col + #case.search },
        { prepared.range.start.character, prepared.range["end"].character }
      )

      rename({ newName = case.replacement }, function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      end, {})
    end

    assert.are.same({
      '[double]: other_a.md "Renamed double"',
      "[single]: other_a.md 'Renamed single'",
      "[paren]: other_a.md (Renamed paren)",
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("completes local definition targets and existing reference identifiers", function()
    write("other_a.md", { "# Other A" })
    write("folder/other_b.md", { "# Other B" })
    write("source.md", {
      '[algoa]: oth "Description"',
      "[Text][alg",
      '[angle]: <oth#Header> "Description"',
    })
    vim.cmd.edit(root .. "/source.md")

    local handler = require("obsidian.lsp.handlers")["textDocument/completion"]
    local function complete(row, character)
      local result
      handler({
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = row, character = character },
      }, function(err, value)
        assert.is_nil(err)
        result = value
      end, {})
      assert(vim.wait(3000, function()
        return result ~= nil
      end, 10), "completion did not finish")
      return result.items
    end

    local definition_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    local target_start = assert(definition_line:find("oth", 1, true)) - 1
    local target_items = complete(0, target_start + 3)
    local target_item = vim.iter(target_items):find(function(item)
      return item.textEdit and item.textEdit.newText == "other_a.md"
    end)
    assert.is_not_nil(target_item)
    assert.are.same(
      { target_start, target_start + 3 },
      {
        target_item.textEdit.range.start.character,
        target_item.textEdit.range["end"].character,
      }
    )
    vim.lsp.util.apply_text_edits(
      { target_item.textEdit },
      vim.api.nvim_get_current_buf(),
      "utf-8"
    )
    assert.are.equal(
      '[algoa]: other_a.md "Description"',
      vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    )

    local usage_line = vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]
    local reference_items = complete(1, #usage_line)
    local reference_item = vim.iter(reference_items):find(function(item)
      return item.textEdit and item.textEdit.newText == "algoa"
    end)
    assert.is_not_nil(reference_item)
    assert.are.same(
      { #usage_line - 3, #usage_line },
      {
        reference_item.textEdit.range.start.character,
        reference_item.textEdit.range["end"].character,
      }
    )

    local angle_line = vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
    local angle_start = assert(angle_line:find("oth", 1, true)) - 1
    local angle_items = complete(2, angle_start + 3)
    local angle_item = vim.iter(angle_items):find(function(item)
      return item.textEdit and item.textEdit.newText == "other_a.md"
    end)
    assert.is_not_nil(angle_item)
    vim.lsp.util.apply_text_edits(
      { angle_item.textEdit },
      vim.api.nvim_get_current_buf(),
      "utf-8"
    )
    assert.are.equal(
      '[angle]: <other_a.md#Header> "Description"',
      vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
    )
  end)

  it("hovers every local note link form and leaves attachments alone", function()
    write("other_a.md", { "---", "aliases: [Other]", "---", "# Other A", "", "Brief body." })
    write_binary "image.png"
    write("source.md", {
      "[[other_a]]",
      "[Other](other_a.md)",
      '[algoa]: other_a.md "Description"',
      "[Text][algoa]",
      "![[image.png]]",
    })
    vim.cmd.edit(root .. "/source.md")

    local handler = require("obsidian.lsp.handlers")["textDocument/hover"]
    local function hover(row, character)
      local done, result = false
      handler({
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = row, character = character },
      }, function(err, value)
        assert.is_nil(err)
        result, done = value, true
      end, {})
      assert(vim.wait(3000, function()
        return done
      end, 10), "hover did not finish")
      return result
    end

    for _, position in ipairs {
      { 0, 3 },
      { 1, 3 },
      { 2, 24 },
      { 3, 4 },
    } do
      local result = hover(unpack(position))
      assert.are.equal("markdown", result.contents.kind)
      assert.matches("^# Other A", result.contents.value)
      assert.matches("Brief body%.", result.contents.value)
      assert.not_matches("%*%*Ruta:%*%*", result.contents.value)
      assert.not_matches("%*%*Definición:%*%*", result.contents.value)
    end
    assert.is_nil(hover(4, 5))
  end)

  it("renders a minimal note card for all frontmatter-only link forms", function()
    write("empty.md", { "---", "id: empty", "---" })
    write("source.md", {
      '[definition]: empty.md "Description"',
      "[[empty]]",
      "[empty](empty)",
    })
    vim.cmd.edit(root .. "/source.md")

    local function hover(row, character)
      local done, result = false
      require("obsidian.lsp.handlers")["textDocument/hover"]({
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = row, character = character },
      }, function(err, value)
        assert.is_nil(err)
        result, done = value, true
      end, {})
      assert(vim.wait(3000, function()
        return done
      end, 10), "hover did not finish")
      return result
    end

    for _, position in ipairs { { 0, 18 }, { 1, 3 }, { 2, 3 } } do
      local result = hover(unpack(position))
      assert.are.equal("markdown", result.contents.kind)
      assert.are.equal(
        "> **Nota vacía**\n>\n> `empty` no tiene contenido fuera del frontmatter.",
        result.contents.value
      )
    end
  end)

  it("goes from reference usages to their declaration, not through it to the note", function()
    write("other_a.md", { "# Other A" })
    write("source.md", {
      '[definition]: other_a.md "Description"',
      "[Visible text][definition]",
      "[definition][]",
      "[definition]",
    })
    vim.cmd.edit(root .. "/source.md")

    local handler = require("obsidian.lsp.handlers")["textDocument/definition"]
    local function definition_at(row, character)
      vim.api.nvim_win_set_cursor(0, { row + 1, character })
      local done, result = false
      handler({
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = row, character = character },
      }, function(err, value)
        assert.is_nil(err)
        result, done = value, true
      end, {})
      assert(vim.wait(3000, function()
        return done
      end, 10), "definition did not finish")
      return result
    end

    for _, position in ipairs { { 1, 4 }, { 2, 4 }, { 3, 4 } } do
      local locations = definition_at(unpack(position))
      assert.are.equal(1, #locations)
      assert.are.equal(root .. "/source.md", vim.uri_to_fname(locations[1].uri))
      assert.are.equal(0, locations[1].range.start.line)
      assert.are.same(
        { 1, 11 },
        {
          locations[1].range.start.character,
          locations[1].range["end"].character,
        }
      )
    end

    local note_locations = definition_at(0, 18)
    assert.are.equal(1, #note_locations)
    assert.are.equal(root .. "/other_a.md", vim.uri_to_fname(note_locations[1].uri))
  end)

  it("does not resolve an explicit .md target to a legacy .md.md note", function()
    write("wrong.md.md", { "---", "id: wrong.md", "---", "# Wrong legacy note" })
    write("source.md", { "[wrong]: wrong.md", "[wrong]" })
    vim.cmd.edit(root .. "/source.md")

    local done, result = false
    require("obsidian.lsp.handlers")["textDocument/hover"]({
      textDocument = { uri = vim.uri_from_bufnr(0) },
      position = { line = 1, character = 2 },
    }, function(err, value)
      assert.is_nil(err)
      result, done = value, true
    end, {})
    assert(vim.wait(3000, function()
      return done
    end, 10), "hover did not finish")
    assert.is_nil(result)
  end)

  it("advertises note hover through obsidian-ls", function()
    local result
    require("obsidian.lsp.handlers").initialize({}, function(err, value)
      assert.is_nil(err)
      result = value
    end, { notification = function() end })
    assert.is_true(result.capabilities.hoverProvider)
  end)

  it("fills a Markdown label from the page title", function()
    write("source.md", { "[gh](https://github.com)" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    require("lzy.obsidian.link_actions").fetch_web_title({
      notify = function() end,
      request = function(url, callback)
        assert.are.equal("https://github.com", url)
        callback "<html><head><title>GitHub &amp; friends [home]</title></head></html>"
      end,
    })

    assert.are.equal(
      "[GitHub & friends \\[home\\]](https://github.com)",
      vim.api.nvim_get_current_line()
    )
  end)

  it("turns an angle-bracket URL into a labeled link from the page title", function()
    write("source.md", { "See <https://github.com>" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    require("lzy.obsidian.link_actions").fetch_web_title({
      notify = function() end,
      request = function(_, callback)
        callback "<TITLE> GitHub \n Home </TITLE>"
      end,
    })

    assert.are.equal("See [GitHub Home](https://github.com)", vim.api.nvim_get_current_line())
  end)

  it("fills a reference-definition identifier from the page title", function()
    write("source.md", { '[gh]: https://github.com "GitHub"', "[site][gh]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 12 })

    require("lzy.obsidian.link_actions").fetch_web_title({
      notify = function() end,
      request = function(url, callback)
        assert.are.equal("https://github.com", url)
        callback "<title>GitHub home</title>"
      end,
    })

    assert.are.same({
      '[GitHub home]: https://github.com "GitHub"',
      "[site][GitHub home]",
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("resolves a full reference link and opens its definition URL with gx", function()
    write("source.md", { "[gh]: https://github.com", "[GitHub][gh]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 2, 4 })

    local opened
    local original_open = vim.ui.open
    vim.ui.open = function(target)
      opened = target
    end
    assert.is_true(require("lzy.obsidian.attachments").open_under_cursor(0))
    vim.ui.open = original_open

    assert.are.equal("https://github.com", opened)
  end)

  it("fills a full-reference display label without renaming its identifier", function()
    write("source.md", { "[gh]: https://github.com", "[site][gh]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 2, 3 })

    require("lzy.obsidian.link_actions").fetch_web_title({
      notify = function() end,
      request = function(_, callback)
        callback "<title>GitHub</title>"
      end,
    })

    assert.are.same(
      { "[gh]: https://github.com", "[GitHub][gh]" },
      vim.api.nvim_buf_get_lines(0, 0, -1, false)
    )
  end)

  it("rejects names that cannot preserve a literal heading and a valid anchor", function()
    local headings = require "lzy.obsidian.headings"
    assert.is_nil(headings.validate_name "My Father A")
    assert.matches("empezar ni terminar", headings.validate_name " My Father A")
    assert.matches("empezar ni terminar", headings.validate_name "My Father A ")
    assert.matches("contener '#'", headings.validate_name "Father#Child")
    assert.matches("carácter válido", headings.validate_name "***")
    assert.are.equal("my-father-a", headings.anchor_segment "My Father A")
  end)

  it("writes anchors with the heading's own text, encoding only where Markdown needs it", function()
    local headings = require "lzy.obsidian.headings"
    -- Un `[[wiki]]` admite espacios y mayúsculas: es lo que escribe la app de
    -- Obsidian y lo que ya usa el vault.
    assert.are.equal("My Father A", headings.anchor_text("My Father A", "wiki"))
    -- El destino de un enlace Markdown no: un espacio corta el destino y
    -- dejaría medio enlace parseado.
    assert.are.equal("My%20Father%20A", headings.anchor_text("My Father A", "markdown"))
    -- `]]`, `|` y `#` no son representables dentro de `[[...]]`; solo ahí se
    -- cae al anchor canónico, que sí lo es.
    assert.are.equal("array-int", headings.anchor_text("Array [int]", "wiki"))
    assert.are.equal("aliasado", headings.anchor_text("Alias|ado", "wiki"))
  end)

  it("keeps resolving the slug anchors written before, so nothing needs migrating", function()
    write("Ankama.md", { "# Installation on Linux", "", "cuerpo" })
    vim.cmd.edit(root .. "/Ankama.md")
    local headings = require "lzy.obsidian.headings"
    local note = require("obsidian.api").current_note(0, {
      collect_sections = true,
      collect_anchor_links = true,
      max_lines = math.huge,
    })
    -- `M.resolve` estandariza los dos lados al comparar, así que la forma en
    -- que un anchor esté escrito no decide si resuelve. Por eso pasar a
    -- verbatim no invalida ni un solo enlace de los ya escritos.
    for _, written in ipairs { "Installation on Linux", "installation-on-linux" } do
      assert.are.equal(1, #headings.resolve(note, written), written .. " dejó de resolver")
    end
  end)

  it("names a new note after its title instead of a slug of it", function()
    local new_note = require "lzy.obsidian.new_note"
    assert.are.equal("Mi Nota Chula", new_note.verbatim_id "Mi Nota Chula")
    -- Lo que rompería un `[[enlace]]` o fabricaría carpetas sí se va.
    assert.are.equal("Nota rara", new_note.verbatim_id "Nota #[rara]|")
    assert.are.equal("Con Espacios", new_note.verbatim_id "  Con   Espacios  ")
    -- Un título que no deja nada utilizable cae al id generado.
    assert.are.equal(15, #new_note.verbatim_id "###")
    -- Con directorio, desambigua contra lo que ya existe en vez de pisarlo.
    write("Ocupada.md", { "ya existo" })
    assert.are.equal("Ocupada 2", new_note.verbatim_id("Ocupada", Obsidian.dir))
  end)

  local function rename_at(col, new_name)
    vim.api.nvim_win_set_cursor(0, { 1, col })
    local called = false
    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = new_name },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
        called = true
      end,
      {}
    )
    vim.wait(3000, function()
      return called
    end, 10)
    vim.cmd "silent! wall"
  end

  it("renames tag trees consistently with the tag picker", function()
    write("tag-source.md", {
      "Tags #project and #project/child; keep #other",
      "```",
      "Hidden #project",
      "```",
    })
    write("tag-frontmatter.md", {
      "---",
      "tags:",
      "  - project",
      "  - project/deep",
      "---",
      "Body #project/deep/leaf",
    })
    vim.cmd.edit(vim.fs.joinpath(root, "tag-source.md"))
    rename_at(7, "work")

    assert.are.same({
      "Tags #work and #work/child; keep #other",
      "```",
      "Hidden #project",
      "```",
    }, vim.fn.readfile(root .. "/tag-source.md"))
    assert.are.same({
      "---",
      "tags:",
      "  - work",
      "  - work/deep",
      "---",
      "Body #work/deep/leaf",
    }, vim.fn.readfile(root .. "/tag-frontmatter.md"))
  end)

  it("keeps Enter normal on headings unless Markdown folding is active", function()
    write("source.md", { "## Heading", "Body" })
    vim.cmd.edit(vim.fs.joinpath(root, "source.md"))
    vim.api.nvim_win_set_cursor(0, { 1, 3 })
    local old_foldmethod = vim.wo.foldmethod
    local old_markdown_folding = vim.g.markdown_folding

    vim.g.markdown_folding = nil
    vim.wo.foldmethod = "manual"
    assert.are.equal("<CR>", require("obsidian.actions").smart_action())
    vim.wo.foldmethod = "expr"
    assert.are.equal("za", require("obsidian.actions").smart_action())

    vim.wo.foldmethod = old_foldmethod
    vim.g.markdown_folding = old_markdown_folding
  end)

  it("renames a parent heading without touching standalone child anchors", function()
    rename_at(8, "Renamed")

    assert.are.same(
      { "# Renamed", "", "## Subheader", "", "### Child" },
      vim.fn.readfile(root .. "/nota.md")
    )
    assert.are.same({
      "[[nota#Renamed#subheader]]",
      "[[nota#subheader]]",
      "[[nota#Renamed#subheader#child]]",
      "[[nota#child]]",
      "[label](nota.md#Renamed#subheader)",
      "[[nota#missing]]",
    }, vim.fn.readfile(root .. "/source.md"))
  end)

  it("renames a subheading through nested and standalone anchors", function()
    rename_at(15, "My Father A")

    assert.are.same(
      { "# Header", "", "## My Father A", "", "### Child" },
      vim.fn.readfile(root .. "/nota.md")
    )
    assert.are.same({
      -- Wiki admite el texto tal cual; el destino de un enlace Markdown no
      -- (un espacio lo cortaría), así que ahí y solo ahí se percent-encodea.
      "[[nota#header#My Father A]]",
      "[[nota#My Father A]]",
      "[[nota#header#My Father A#child]]",
      "[[nota#child]]",
      "[label](nota.md#header#My%20Father%20A)",
      "[[nota#missing]]",
    }, vim.fn.readfile(root .. "/source.md"))
  end)

  it("renames a heading directly from its declaration", function()
    vim.cmd.edit(root .. "/nota.md")
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
    local called = false
    require("obsidian.lsp.handlers")["textDocument/rename"](
      { newName = "From declaration" },
      function(err, edit)
        assert.is_nil(err)
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
        called = true
      end,
      {}
    )
    vim.wait(3000, function()
      return called
    end, 10)
    vim.cmd "silent! wall"

    assert.are.same(
      { "# Header", "", "## From declaration", "", "### Child" },
      vim.fn.readfile(root .. "/nota.md")
    )
    assert.are.equal("[[nota#header#From declaration]]", vim.fn.readfile(root .. "/source.md")[1])
  end)

  it("resolves and renames the shortest unambiguous ancestor suffix", function()
    write("nota.md", {
      "# NOTENAME",
      "## FatherA",
      "### Child",
      "## FatherB",
      "### Child",
    })
    write("source.md", {
      "[[nota#fathera#child]]",
      "[[nota#notename#fathera#child]]",
      "[[nota#fatherb#child]]",
      "[[nota#child]]",
    })
    vim.cmd.edit(root .. "/source.md")

    local function definition_at(row, col)
      vim.api.nvim_win_set_cursor(0, { row, col })
      local locations
      require("obsidian.lsp.handlers")["textDocument/definition"]({}, function(err, result)
        assert.is_nil(err)
        locations = result
      end, {})
      vim.wait(3000, function()
        return locations ~= nil
      end, 10)
      return locations
    end

    local partial = definition_at(1, 16)
    assert.are.equal(1, #partial)
    assert.are.equal(2, partial[1].range.start.line)

    vim.api.nvim_win_set_cursor(0, { 1, 9 })
    local prepare
    require("obsidian.lsp.handlers")["textDocument/prepareRename"]({}, function(err, result)
      assert.is_nil(err)
      prepare = result
    end, {})
    vim.wait(3000, function()
      return prepare ~= nil
    end, 10)
    assert.are.equal("FatherA", prepare.placeholder)

    local ambiguous = definition_at(4, 9)
    assert.are.equal(2, #ambiguous)
    assert.are.same({ 2, 4 }, {
      ambiguous[1].range.start.line,
      ambiguous[2].range.start.line,
    })

    rename_at(16, "Child A")
    assert.are.same({
      "# NOTENAME",
      "## FatherA",
      "### Child A",
      "## FatherB",
      "### Child",
    }, vim.fn.readfile(root .. "/nota.md"))
    assert.are.same({
      "[[nota#fathera#Child A]]",
      "[[nota#notename#fathera#Child A]]",
      "[[nota#fatherb#child]]",
      "[[nota#child]]",
    }, vim.fn.readfile(root .. "/source.md"))
  end)

  it("moves an attachment while preserving each reference class", function()
    write("one/a.png", { "one" })
    write("two/a.png", { "two" })
    write("one/local.md", { "![[a.png|300]]", "![[a.png#page=3|Page]]" })
    write("two/local.md", { "![[a.png]]" })
    write("source.md", { "![[one/a.png]]" })
    write("markdown.md", {
      '![alt](one/a.png "caption")',
      "[page](one/a.png#page=3)",
      '![angle](<one/a.png> "caption")',
      '[download]: <one/a.png> "caption"',
    })
    write("board.canvas", { '{"nodes":[{"type":"file","file":"one/a.png"}]}' })
    vim.cmd.edit(root .. "/source.md")

    rename_at(8, "archive/deep/My Image")

    assert.is_nil((vim.uv or vim.loop).fs_stat(root .. "/one/a.png"))
    assert.is_not_nil((vim.uv or vim.loop).fs_stat(root .. "/archive/deep/My Image.png"))
    assert.are.equal("![[My Image.png|300]]", vim.fn.readfile(root .. "/one/local.md")[1])
    assert.are.equal("![[My Image.png#page=3|Page]]", vim.fn.readfile(root .. "/one/local.md")[2])
    assert.are.equal("![[a.png]]", vim.fn.readfile(root .. "/two/local.md")[1])
    assert.are.equal("![[archive/deep/My Image.png]]", vim.fn.readfile(root .. "/source.md")[1])
    assert.are.equal(
      '![alt](archive/deep/My%20Image.png "caption")',
      vim.fn.readfile(root .. "/markdown.md")[1]
    )
    assert.are.equal(
      "[page](archive/deep/My%20Image.png#page=3)",
      vim.fn.readfile(root .. "/markdown.md")[2]
    )
    assert.are.equal(
      '![angle](<archive/deep/My%20Image.png> "caption")',
      vim.fn.readfile(root .. "/markdown.md")[3]
    )
    assert.are.equal(
      '[download]: <archive/deep/My%20Image.png> "caption"',
      vim.fn.readfile(root .. "/markdown.md")[4]
    )
    assert.are.equal(
      '{"nodes":[{"type":"file","file":"archive/deep/My Image.png"}]}',
      vim.fn.readfile(root .. "/board.canvas")[1]
    )
  end)

  it("uses a vault path after rename when the new basename is duplicated", function()
    write("one/a.png", { "one" })
    write("existing/collision.png", { "existing" })
    write("source.md", { "![[one/a.png]]" })
    vim.cmd.edit(root .. "/source.md")

    rename_at(8, "moved/collision.png")

    assert.are.equal("![[moved/collision.png]]", vim.fn.readfile(root .. "/source.md")[1])
    assert.is_not_nil((vim.uv or vim.loop).fs_stat(root .. "/moved/collision.png"))
  end)

  it("rejects unsafe names and existing destinations without moving anything", function()
    write("assets/a.png", { "a" })
    write("assets/taken.png", { "taken" })
    local attachments = require "lzy.obsidian.attachments"
    local opts = { source_path = root .. "/source.md", root = root }

    local _, reserved = attachments.destination(root .. "/assets/a.png", "bad#name", opts)
    local _, separator = attachments.destination(root .. "/assets/a.png", "bad\\name", opts)
    local _, collision = attachments.destination(root .. "/assets/a.png", "assets/taken.png", opts)

    assert.matches("no puede contener", reserved)
    assert.matches("separador", separator)
    assert.matches("ya existe", collision)
    assert.is_not_nil((vim.uv or vim.loop).fs_stat(root .. "/assets/a.png"))
  end)

  it("preserves absolute, URI, note-relative, vault-relative and basename targets", function()
    write("assets/a.png", { "a" })
    local attachments = require "lzy.obsidian.attachments"
    local source = root .. "/notes/source.md"
    local old_path = root .. "/assets/a.png"
    local new_path = root .. "/archive/b.png"
    local common = { source_path = source, root = root, old_path = old_path }

    local function formatted(old_target)
      return attachments.format_target(
        new_path,
        vim.tbl_extend("force", {}, common, { old_target = old_target })
      )
    end

    assert.are.equal(new_path, formatted(old_path))
    assert.are.equal(vim.uri_from_fname(new_path), formatted(vim.uri_from_fname(old_path)))
    assert.are.equal("../archive/b.png", formatted "../assets/a.png")
    assert.are.equal("archive/b.png", formatted "assets/a.png")
    assert.are.equal("b.png", formatted "a.png")
  end)

  it("preserves relative external targets and can explicitly make them absolute", function()
    local attachments = require "lzy.obsidian.attachments"
    local source = root .. "/notes/source.md"
    local old_path = root .. "-external/a.bin"
    local new_path = root .. "-external/b.bin"
    local old_relative = "../../" .. vim.fs.basename(root) .. "-external/a.bin"
    local new_relative = "../../" .. vim.fs.basename(root) .. "-external/b.bin"
    local common = {
      source_path = source,
      root = root,
      old_path = old_path,
      old_target = old_relative,
    }

    assert.are.equal(new_relative, attachments.format_target(new_path, common))
    assert.are.equal(
      new_path,
      attachments.format_target(
        new_path,
        vim.tbl_extend("force", {}, common, {
          policy = { vault = "preserve", external = "absolute" },
        })
      )
    )
  end)

  it("renames an external attachment without relativizing absolute or file URI links", function()
    local attachments = require "lzy.obsidian.attachments"
    local external_dir = root .. "-external"
    local old_path = external_dir .. "/a.bin"
    local new_path = external_dir .. "/b.bin"
    local old_relative = "../" .. vim.fs.basename(external_dir) .. "/a.bin"
    local new_relative = "../" .. vim.fs.basename(external_dir) .. "/b.bin"
    vim.fn.mkdir(external_dir, "p")
    vim.fn.writefile({ "external" }, old_path)
    write("source.md", {
      "![[" .. old_path .. "]]",
      "![[" .. old_relative .. "]]",
      "[uri](" .. vim.uri_from_fname(old_path) .. ")",
    })
    vim.cmd.edit(root .. "/source.md")

    local edit, err = attachments.rename(old_path, new_path, {
      source_path = root .. "/source.md",
      root = root,
    })
    assert.is_nil(err)
    vim.lsp.util.apply_workspace_edit(edit, "utf-8")
    vim.cmd "silent! wall"

    assert.are.same({
      "![[" .. new_path .. "]]",
      "![[" .. new_relative .. "]]",
      "[uri](" .. vim.uri_from_fname(new_path) .. ")",
    }, vim.fn.readfile(root .. "/source.md"))
    assert.is_nil(uv.fs_stat(old_path))
    assert.is_not_nil(uv.fs_stat(new_path))
    vim.fn.delete(external_dir, "rf")
  end)

  it("classifies text by content and leaves every non-text format to the system", function()
    write("recording.mp4", { "plain text despite the extension" })
    write_binary "archive.tar"
    local attachments = require "lzy.obsidian.attachments"

    assert.is_true(attachments.is_text(root .. "/recording.mp4"))
    assert.is_false(attachments.is_text(root .. "/archive.tar"))
  end)

  it("supports the optional Nyabsidian simplify policy", function()
    write("assets/a.png", { "a" })
    write("notes/source.md", { "![[../assets/a.png]]" })
    local attachments = require "lzy.obsidian.attachments"
    local source = root .. "/notes/source.md"
    local asset = root .. "/assets/a.png"

    assert(attachments.configure(root, {
      attachment_paths = { vault = "simplify", external = "preserve" },
    }))

    assert.are.equal(
      "../assets/a.png",
      attachments.format_target(asset, {
        source_path = source,
        root = root,
        old_path = asset,
        old_target = "assets/a.png",
        format = "relative",
      })
    )
    assert.are.equal(
      "assets/a.png",
      attachments.format_target(asset, {
        source_path = source,
        root = root,
        old_path = asset,
        old_target = "../assets/a.png",
        format = "absolute",
      })
    )
    assert.are.equal(
      "resolved",
      attachments.resolve("../assets/a.png", {
        source_path = source,
        root = root,
        format = "relative",
      }).status
    )
  end)

  it("validates Nyabsidian's own attachment policies and falls back to preserve", function()
    local attachments = require "lzy.obsidian.attachments"
    local ok, err = attachments.configure(root, {
      attachment_paths = { external = "relative" },
    })

    assert.is_false(ok)
    assert.matches("'preserve' o 'absolute'", err)
    assert.are.same({ vault = "preserve", external = "preserve" }, attachments.path_policy(root))
  end)

  it("accepts obsidian.Path roots during live workspace refresh", function()
    local attachments = require "lzy.obsidian.attachments"
    local path_root = require("obsidian.path").new(root)

    assert(attachments.configure(path_root, {
      attachment_paths = { vault = "simplify" },
    }))
    assert.are.same(
      { vault = "simplify", external = "preserve" },
      attachments.path_policy(path_root)
    )
  end)

  it("converts only the attachment target to a chosen path format", function()
    write("assets/a.png", { "image" })
    write("notes/source.md", { "![[assets/a.png#page=3|Preview]]" })
    vim.cmd.edit(root .. "/notes/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    local seen
    require("lzy.obsidian.link_actions").convert_link({
      notify = function() end,
      select = function(items, _, callback)
        seen = vim.tbl_map(function(item)
          return item.id
        end, items)
        callback(vim.iter(items):find(function(item)
          return item.id == "relative"
        end))
      end,
    })

    assert.are.same({ "shortest", "vault", "relative", "absolute", "file_uri" }, seen)
    assert.are.equal("![[../assets/a.png#page=3|Preview]]", vim.api.nvim_get_current_line())
  end)

  it("uses a safe vault path when a note basename is ambiguous", function()
    write("one/a.md", { "# One" })
    write("two/a.md", { "# Two" })
    write("source.md", { "[[" .. root .. "/one/a.md#One|A]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local seen
    require("lzy.obsidian.link_actions").convert_link({
      notify = function() end,
      select = function(items, _, callback)
        seen = vim.tbl_map(function(item)
          return item.id
        end, items)
        callback(vim.iter(items):find(function(item)
          return item.id == "shortest"
        end))
      end,
    })
    vim.wait(1000, function()
      return vim.api.nvim_get_current_line() == "[[one/a#One|A]]"
    end, 10)

    assert.are.same({ "shortest", "vault", "relative" }, seen)
    assert.are.equal("[[one/a#One|A]]", vim.api.nvim_get_current_line())
  end)

  it("warns about markdown destinations that resolve here but break on GitHub", function()
    local diagnostics = require "lzy.obsidian.diagnostics"
    write("docs/Software wrapper.md", { "# SW" })
    write("docs/nota.md", { "# Nota" })
    write("docs/vecina.md", { "# Vecina" })
    write("carpeta/algo.md", { "# Algo" })
    -- La fuente vive en docs/, así que `vecina.md` sí está a su lado.
    write("docs/source.md", {
      "[SW](/docs/Software wrapper.md)", -- el espacio corta el destino
      "[SW](/docs/Software%20wrapper.md)", -- correcto
      "[Nota](/docs/nota)", -- sólo existe con .md -> 404 en GitHub
      "[Algo](algo.md)", -- nombre suelto que NO está al lado
      "[Vecina](vecina.md)", -- nombre suelto que sí está al lado: válido
      "[Carpeta](../carpeta)", -- un directorio no necesita extensión
      '[Ok](/docs/nota.md "Un título")', -- el espacio del título es legal
      "[Ok](</docs/Software wrapper.md>)", -- los ángulos son válidos
      "Texto con `[x](roto ahí.md)` dentro de código", -- no es un enlace
      "```",
      "[x](tampoco esto.md)", -- dentro de un fence
      "```",
    })
    vim.cmd.edit(root .. "/docs/source.md")

    local found = {}
    for _, diag in ipairs(diagnostics.portability_warnings(0, root)) do
      found[diag.lnum + 1] = diag.severity
    end

    assert.are.equal(vim.diagnostic.severity.ERROR, found[1], "el espacio crudo rompe el destino")
    assert.is_nil(found[2], "el destino ya escapado no debe avisar")
    assert.are.equal(vim.diagnostic.severity.WARN, found[3], "sin .md GitHub da 404")
    assert.are.equal(vim.diagnostic.severity.HINT, found[4], "nombre suelto que no está al lado")
    assert.is_nil(found[5], "un nombre suelto que sí está al lado es portable")
    assert.is_nil(found[6], "un directorio no necesita extensión")
    assert.is_nil(found[7], "un título entrecomillado no es un destino roto")
    assert.is_nil(found[8], "los ángulos son CommonMark válido")
    assert.is_nil(found[9], "dentro de código no hay enlaces, hay texto sobre enlaces")
    assert.is_nil(found[11], "y dentro de un fence tampoco")
  end)

  it("reads escaped, slugged and differently-cased targets, accents included", function()
    -- El vault no escribe ninguna de estas formas, pero llegan igual: pegadas
    -- de otra herramienta, de un export o de marksman. Se aceptan al LEER.
    write("Espacios y mayús.md", { "# Espacios y mayús" })
    require("lzy.obsidian.notes").invalidate_index()

    local function resolves(target)
      local got
      require("lzy.obsidian.notes").resolve_async(target, function(found)
        got = found
      end)
      vim.wait(3000, function()
        return got ~= nil
      end, 10)
      return #got > 0 and vim.fs.basename(tostring(got[1].path)) or nil
    end

    assert.are.equal("Espacios y mayús.md", resolves "Espacios y mayús")
    assert.are.equal("Espacios y mayús.md", resolves "Espacios%20y%20mayús")
    assert.are.equal("Espacios y mayús.md", resolves "espacios-y-mayús")
    -- `:lower()` de Lua es byte a byte y dejaba la `Ú` intacta, así que la
    -- resolución "insensible a mayúsculas" sólo lo era en ASCII.
    assert.are.equal("Espacios y mayús.md", resolves "ESPACIOS Y MAYÚS")
    -- Y lo que no existe sigue sin existir.
    assert.is_nil(resolves "no-existe-nada-de-esto")
  end)

  it("grows the coordinate one folder at a time instead of jumping to the full path", function()
    write("x/deep/nested/a.md", { "# A" })
    write("y/other/nested/a.md", { "# B" })
    write("solitaria.md", { "# Sola" })
    local coordinate = require "lzy.obsidian.coordinate"
    local opts = { root = root, fresh = true }

    -- Sin homónimos, el nombre pelado.
    assert.are.equal("solitaria", coordinate.minimal(root .. "/solitaria.md", opts))

    -- Con homónimos, el sufijo MÍNIMO que ya los separa. `a` colisiona y
    -- `nested/a` también (las dos terminan igual), así que hace falta bajar a
    -- `deep/nested/a` -- pero no hasta la ruta completa `x/deep/nested/a`.
    assert.are.equal(
      "deep/nested/a",
      coordinate.minimal(root .. "/x/deep/nested/a.md", opts)
    )
    assert.are.equal(
      "other/nested/a",
      coordinate.minimal(root .. "/y/other/nested/a.md", opts)
    )
  end)

  describe("relink", function()
    it("canonicalises every link and leaves the ones it cannot resolve alone", function()
      write("docs/Software wrapper.md", { "# SW" })
      write("docs/notaunica.md", { "# Nota" })
      write("source.md", {
        "[[docs/notaunica]]", -- se puede acortar: no hay homónimos
        "[SW](docs/Software%20wrapper.md)", -- markdown -> ruta desde la raíz
        "[[docs/notaunica|con alias]]", -- el alias se conserva
        "[[fantasma]]", -- no resuelve: intacto
        "[Web](https://ejemplo.com/a)", -- externo: intacto
      })
      -- Recargar: otros tests dejan un buffer con este mismo nombre cargado.
      vim.cmd("edit! " .. vim.fn.fnameescape(root .. "/source.md"))

      local plan = assert(require("lzy.obsidian.relink").plan { root = root })
      vim.lsp.util.apply_workspace_edit(
        require("lzy.obsidian.relink").workspace_edit(plan),
        "utf-8"
      )

      assert.are.same({
        "[[notaunica]]",
        "[SW](/docs/Software%20wrapper.md)",
        "[[notaunica|con alias]]",
        "[[fantasma]]",
        "[Web](https://ejemplo.com/a)",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("accepts both escapes for a space and rewrites neither", function()
      write("docs/Guia con espacio.md", { "# G" })
      write("source.md", {
        "[A](/docs/Guia%20con%20espacio.md)", -- escapado
        "[B](</docs/Guia con espacio.md>)", -- entre ángulos: también válido
        "[C](docs/Guia%20con%20espacio.md)", -- válido pero no canónico
      })
      vim.cmd("edit! " .. vim.fn.fnameescape(root .. "/source.md"))

      local relink = require "lzy.obsidian.relink"
      local plan = assert(relink.plan { root = root })
      vim.lsp.util.apply_workspace_edit(relink.workspace_edit(plan), "utf-8")

      assert.are.same({
        "[A](/docs/Guia%20con%20espacio.md)",
        -- Los ángulos ya son portables: meterles %20 dentro sería redundante y
        -- pelearse con una forma correcta elegida a propósito.
        "[B](</docs/Guia con espacio.md>)",
        "[C](/docs/Guia%20con%20espacio.md)",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("fixes the case of a markdown destination but never of a bare wikilink", function()
      write("swap.md", { "# swap" })
      write("source.md", {
        "[[Swap]]", -- el destino ES el texto visible: no se toca
        "[Swap](/Swap.md)", -- aquí la caja decide si GitHub lo encuentra
      })
      vim.cmd("edit! " .. vim.fn.fnameescape(root .. "/source.md"))

      local relink = require "lzy.obsidian.relink"
      local plan = assert(relink.plan { root = root })
      vim.lsp.util.apply_workspace_edit(relink.workspace_edit(plan), "utf-8")

      assert.are.same({
        "[[Swap]]",
        "[Swap](/swap.md)",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("expands the links a new colliding note would have hijacked", function()
      write("carpeta/Duplicada.md", { "# La de siempre" })
      write("source.md", { "Mira [[Duplicada]] y [[Duplicada|con alias]]." })
      vim.cmd("edit! " .. vim.fn.fnameescape(root .. "/source.md"))
      require("lzy.obsidian.notes").invalidate_index()

      -- Aparece una homónima: los enlaces de arriba dejan de ser inequívocos.
      write("otra/Duplicada.md", { "# La nueva" })
      local rewritten = require("lzy.obsidian.relink").on_note_added(
        root .. "/otra/Duplicada.md",
        { root = root, notify = function() end }
      )

      assert.are.equal(2, rewritten)
      assert.are.equal(
        "Mira [[carpeta/Duplicada]] y [[carpeta/Duplicada|con alias]].",
        vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      )
    end)

    it("does nothing when the new note collides with nobody", function()
      write("carpeta/Sola.md", { "# Sola" })
      write("source.md", { "Mira [[Sola]]." })
      vim.cmd("edit! " .. vim.fn.fnameescape(root .. "/source.md"))
      require("lzy.obsidian.notes").invalidate_index()

      assert.are.equal(
        0,
        require("lzy.obsidian.relink").on_note_added(
          root .. "/carpeta/Sola.md",
          { root = root, notify = function() end }
        )
      )
      assert.are.equal(
        "Mira [[Sola]].",
        vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      )
    end)
  end)

  it("resolves an ambiguous name to the closest note first, as attachments already did", function()
    write("cerca/a.md", { "# Cerca" })
    write("lejos/muy/hondo/a.md", { "# Lejos" })
    write("cerca/source.md", { "texto" })
    vim.cmd.edit(root .. "/cerca/source.md")

    local notes = require "lzy.obsidian.notes"
    notes.invalidate_index()
    local got
    notes.resolve_async("a", function(found)
      got = found
    end)
    vim.wait(3000, function()
      return got ~= nil
    end, 10)

    assert.is_true(#got >= 2, "las dos notas homónimas deberían resolver")
    -- Antes las notas no ordenaban nada y el ganador dependía del orden de
    -- indexación del vault, mientras que un adjunto homónimo sí desempataba
    -- por cercanía: misma ambigüedad, dos respuestas distintas.
    assert.are.equal(
      vim.fs.joinpath(root, "cerca/a.md"),
      vim.fs.normalize(tostring(got[1].path))
    )
  end)

  it("treats an alias collision as a collision, even though it is not in the path", function()
    -- El rival no se llama `Unica`: la reclama por alias. Su ruta no contiene
    -- ese nombre por ningún lado, así que comparar sufijos de ruta no lo ve --
    -- y el nombre pelado saldría como si fuese inequívoco cuando no lo es.
    write("x/Unica.md", { "# Unica" })
    write("y/Distinta.md", { "---", "aliases:", "  - Unica", "---", "", "# Distinta" })
    local coordinate = require "lzy.obsidian.coordinate"
    local opts = { root = root, fresh = true }

    assert.are.equal("x/Unica", coordinate.minimal(root .. "/x/Unica.md", opts))
  end)

  it("falls back to the leading slash when an ambiguous note sits at the vault root", function()
    -- En la raíz no hay carpeta que añadir. La barra la vuelve una coordenada
    -- posicional, que es lo único que la separa de quien la reclama por alias.
    write("Raiz.md", { "# Raiz" })
    write("z/Otra.md", { "---", "aliases:", "  - Raiz", "---", "", "# Otra" })
    local coordinate = require "lzy.obsidian.coordinate"

    assert.are.equal(
      "/Raiz",
      coordinate.minimal(root .. "/Raiz.md", { root = root, fresh = true })
    )
  end)

  it("only counts a rival as sharing a suffix on a folder boundary", function()
    write("otra/Nota.md", { "# Una" })
    write("miotra/Nota.md", { "# Otra" })
    local coordinate = require "lzy.obsidian.coordinate"
    local opts = { root = root, fresh = true }

    -- `miotra/Nota` termina en la cadena "otra/Nota", pero no en el segmento:
    -- si se comparasen como texto, ninguno de los dos sería nunca separable.
    assert.are.equal("otra/Nota", coordinate.minimal(root .. "/otra/Nota.md", opts))
    assert.are.equal("miotra/Nota", coordinate.minimal(root .. "/miotra/Nota.md", opts))
  end)

  it("writes a markdown destination as a root path, encoded, never a bare name", function()
    write("docs/Software wrapper.md", { "# SW" })
    local coordinate = require "lzy.obsidian.coordinate"

    -- Un basename pelado resolvería aquí (buscamos por el vault) y daría 404
    -- en GitHub, que sólo mira la ruta literal.
    assert.are.equal(
      "/docs/Software%20wrapper.md",
      coordinate.markdown(root .. "/docs/Software wrapper.md", { root = root })
    )
    -- Y la misma nota dentro de un wikilink va pelada y con el espacio literal.
    assert.are.equal(
      "Software wrapper",
      coordinate.minimal(root .. "/docs/Software wrapper.md", { root = root, fresh = true })
    )
  end)

  it("uses an empty shortest target for a heading in the current note", function()
    write("source.md", { "# Local", "[[source#local]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 2, 5 })

    require("lzy.obsidian.link_actions").convert_link({
      notify = function() end,
      select = function(items, _, callback)
        local choice = vim.iter(items):find(function(item)
          return item.id == "shortest"
        end)
        assert.is_not_nil(choice)
        assert.are.equal("", choice.target)
        callback(choice)
      end,
    })

    vim.wait(1000, function()
      return vim.api.nvim_get_current_line() == "[[#local]]"
    end, 10)

    assert.are.equal("[[#local]]", vim.api.nvim_get_current_line())
  end)

  it("offers only absolute and note-relative formats for an external note", function()
    local external_dir = root .. "-external"
    local external = external_dir .. "/outside.md"
    vim.fn.mkdir(external_dir, "p")
    vim.fn.writefile({ "# Outside" }, external)
    write("notes/source.md", { "[[" .. external .. "]]" })
    vim.cmd.edit(root .. "/notes/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local seen
    require("lzy.obsidian.link_actions").convert_link({
      notify = function() end,
      select = function(items, _, callback)
        seen = vim.tbl_map(function(item)
          return item.id
        end, items)
        callback(items[1])
      end,
    })

    assert.are.same({ "relative", "absolute" }, seen)
    assert.are.equal(
      "[[../../" .. vim.fs.basename(external_dir) .. "/outside.md]]",
      vim.api.nvim_get_current_line()
    )
  end)

  it("preserves Markdown encoding, fragments and titles while converting", function()
    write("assets/My Image.png", { "image" })
    write("notes/source.md", { '![alt](assets/My%20Image.png#page=3 "caption")' })
    vim.cmd.edit(root .. "/notes/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 15 })

    require("lzy.obsidian.link_actions").convert_link({
      notify = function() end,
      select = function(items, _, callback)
        callback(vim.iter(items):find(function(item)
          return item.id == "relative"
        end))
      end,
    })

    assert.are.equal(
      '![alt](../assets/My%20Image.png#page=3 "caption")',
      vim.api.nvim_get_current_line()
    )
  end)

  it("preserves reference-definition syntax while converting its destination", function()
    write("assets/My Image.png", { "image" })
    write("notes/source.md", { '[asset]: <assets/My%20Image.png#page=3> "caption"' })
    vim.cmd.edit(root .. "/notes/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 20 })

    require("lzy.obsidian.link_actions").convert_link({
      notify = function() end,
      select = function(items, _, callback)
        callback(vim.iter(items):find(function(item)
          return item.id == "relative"
        end))
      end,
    })

    assert.are.equal(
      '[asset]: <../assets/My%20Image.png#page=3> "caption"',
      vim.api.nvim_get_current_line()
    )
  end)

  it("copies the absolute identity resolved for a linked attachment", function()
    write("assets/data.bin", { "data" })
    write("source.md", { "[[assets/data.bin]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local copied
    require("lzy.obsidian.link_actions").copy_path({
      copy = function(path)
        copied = path
      end,
      notify = function() end,
    })

    assert.are.equal(root .. "/assets/data.bin", copied)
  end)

  it("yanks a copied path internally as characterwise text without a newline", function()
    write("assets/data.bin", { "data" })
    write("source.md", { "[[assets/data.bin]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })
    vim.o.clipboard = ""

    require("lzy.obsidian.link_actions").copy_path({
      notify = function() end,
    })

    assert.are.equal(root .. "/assets/data.bin", vim.fn.getreg '"')
    assert.are.equal(root .. "/assets/data.bin", vim.fn.getreg "0")
    assert.are.equal("v", vim.fn.getregtype '"')
    assert.are.equal("v", vim.fn.getregtype "0")
  end)

  it("copies a linked note's absolute path without including its heading", function()
    write("docs/target.md", { "# Heading" })
    write("source.md", { "[[docs/target#heading]]" })
    vim.cmd.edit(root .. "/source.md")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local copied
    require("lzy.obsidian.link_actions").copy_path({
      copy = function(path)
        copied = path
      end,
      notify = function() end,
    })

    assert.are.equal(root .. "/docs/target.md", copied)
  end)

  it("always sends zero or one backlink to the picker", function()
    local backlinks = require "lzy.obsidian.backlinks"
    local picked = {}
    local function pick(items, opts)
      picked[#picked + 1] = { items = items, title = opts.prompt_title }
    end

    backlinks.open({
      references = function(callback)
        callback(nil, {})
      end,
      pick = pick,
    })
    backlinks.open({
      references = function(callback)
        callback(nil, {
          {
            uri = vim.uri_from_fname(root .. "/source.md"),
            range = {
              start = { line = 0, character = 0 },
              ["end"] = { line = 0, character = 4 },
            },
          },
        })
      end,
      pick = pick,
    })

    assert.are.equal(2, #picked)
    assert.are.equal(0, #picked[1].items)
    assert.are.equal(1, #picked[2].items)
    assert.are.equal("Backlinks", picked[1].title)
    assert.are.equal(root .. "/source.md", picked[2].items[1].filename)
  end)

  describe("creating a note from a missing link", function()
    local function follow(link)
      local locations
      require("obsidian.lsp.handlers._definition").follow_link(link, function(_, result)
        locations = result
      end, { bufnr = 0 })
      vim.wait(3000, function()
        return locations ~= nil
      end, 20)
      return locations
    end

    it("creates the exact NAME.md the link shows, without rewriting the link", function()
      write("source.md", { "[[NuevaNota]]" })
      vim.cmd.edit(root .. "/source.md")

      local prompts = {}
      require("lzy.obsidian.new_note").confirm = function(prompt, done)
        prompts[#prompts + 1] = prompt
        done "yes"
      end

      local locations = follow "[[NuevaNota]]"

      assert.are.equal(1, #prompts)
      assert.matches("NuevaNota", prompts[1])
      assert.are.equal(1, #locations)
      assert.are.equal(root .. "/NuevaNota.md", vim.uri_to_fname(locations[1].uri))
      assert.is_not_nil(uv.fs_stat(root .. "/NuevaNota.md"))
      -- El enlace bajo el cursor sigue igual: sin id, sin alias añadido.
      assert.are.same({ "[[NuevaNota]]" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("creates the note under the subfolder the link names", function()
      write("source.md", { "[[sub/Anidada]]" })
      vim.cmd.edit(root .. "/source.md")
      require("lzy.obsidian.new_note").confirm = function(_, done)
        done "yes"
      end

      local locations = follow "[[sub/Anidada]]"

      assert.are.equal(1, #locations)
      assert.are.equal(root .. "/sub/Anidada.md", vim.uri_to_fname(locations[1].uri))
    end)

    it("creates nothing when the user declines", function()
      write("source.md", { "[[Cancelada]]" })
      vim.cmd.edit(root .. "/source.md")
      require("lzy.obsidian.new_note").confirm = function(_, done)
        done "no"
      end

      local locations = follow "[[Cancelada]]"

      assert.is_nil(locations)
      assert.is_nil(uv.fs_stat(root .. "/Cancelada.md"))
    end)

    it("does not prompt when the note already exists", function()
      vim.cmd.edit(root .. "/source.md")
      local confirm_called = false
      require("lzy.obsidian.new_note").confirm = function(_, done)
        confirm_called = true
        done "yes"
      end

      local locations = follow "[[nota]]"

      assert.is_false(confirm_called)
      assert.are.equal(1, #locations)
      assert.are.equal(root .. "/nota.md", vim.uri_to_fname(locations[1].uri))
    end)
  end)

  describe("missing-note diagnostics", function()
    it("flags a link to a note that does not exist, and leaves an existing one alone", function()
      write("source.md", { "[[nota]]", "[[Missing]]" })
      vim.cmd.edit(root .. "/source.md")
      local bufnr = vim.api.nvim_get_current_buf()

      require("lzy.obsidian.diagnostics").refresh(bufnr)
      vim.wait(3000, function()
        return #vim.diagnostic.get(bufnr) > 0
      end, 20)

      local diags = vim.diagnostic.get(bufnr)
      assert.are.equal(1, #diags)
      assert.are.equal(1, diags[1].lnum)
      assert.matches("Missing", diags[1].message)
    end)

    it("clears once the missing note is created", function()
      write("source.md", { "[[Missing]]" })
      vim.cmd.edit(root .. "/source.md")
      local bufnr = vim.api.nvim_get_current_buf()

      require("lzy.obsidian.diagnostics").refresh(bufnr)
      vim.wait(3000, function()
        return #vim.diagnostic.get(bufnr) > 0
      end, 20)
      assert.are.equal(1, #vim.diagnostic.get(bufnr))

      write("Missing.md", { "# Missing" })
      require("lzy.obsidian.diagnostics").refresh(bufnr)
      vim.wait(3000, function()
        return #vim.diagnostic.get(bufnr) == 0
      end, 20)
      assert.are.equal(0, #vim.diagnostic.get(bufnr))
    end)
  end)

  it("sees both destinations of a linked image, the inner one first", function()
    -- `[![alt](img)](url)`, el patrón de los badges. obsidian.nvim solo
    -- devuelve la imagen, así que el destino de fuera quedaba invisible para
    -- follow, convert y las reescrituras de rename.
    local line = "[![Logo](./img/logo.png)](/docs/nota.md)"
    local refs = require("lzy.obsidian.attachments").parse_refs(line, 0)
    assert.are.equal(2, #refs)

    -- Primero la imagen: es el adjunto, y donde los dos se solapan es lo que
    -- se está viendo.
    assert.are.equal("./img/logo.png", refs[1].target)
    assert.is_true(refs[1].embed)
    assert.are.equal(
      "./img/logo.png",
      line:sub(refs[1].target_range.start_col + 1, refs[1].target_range.end_col)
    )

    assert.are.equal("/docs/nota.md", refs[2].target)
    assert.is_false(refs[2].embed)
    assert.are.equal(line, refs[2].raw)
    assert.are.same({ start_row = 0, start_col = 0, end_row = 0, end_col = #line }, refs[2].range)
    assert.are.equal(
      "/docs/nota.md",
      line:sub(refs[2].target_range.start_col + 1, refs[2].target_range.end_col)
    )

    -- Una imagen suelta sigue siendo una sola cosa.
    assert.are.equal(1, #require("lzy.obsidian.attachments").parse_refs("![Logo](./img/logo.png)", 0))
    -- Y un enlace normal con texto tampoco se duplica.
    assert.are.equal(1, #require("lzy.obsidian.attachments").parse_refs("[Texto](/docs/nota.md)", 0))
  end)

  it("never turns a half-typed path into a wiki-link alias", function()
    -- builtin.wiki_link de obsidian.nvim añade `|etiqueta` en cuanto la
    -- etiqueta difiere del nombre de la nota, y la etiqueta sale de lo
    -- tecleado: escribir `[[/docs` sobre una nota con id Zettel producía
    -- `[[1786867178-OZDA|/docs]]`, un alias que es media ruta.
    local drop = require("lzy.obsidian.completion").drop_pathish_alias
    assert.are.equal("[[1786867178-OZDA]]", drop "[[1786867178-OZDA|/docs]]")
    assert.are.equal("[[nota]]", drop "[[nota|docs/api]]")
    assert.are.equal("[[nota]]", drop "[[nota|./vecina]]")
    -- Un alias que de verdad es un nombre se conserva intacto.
    assert.are.equal("[[nota|Alias Legible]]", drop "[[nota|Alias Legible]]")
    assert.are.equal("[[nota#anchor]]", drop "[[nota#anchor]]")
  end)

  it("never offers to create a note named like a half-typed path", function()
    -- El item "(create)" de obsidian.nvim propone crear una nota llamada como
    -- lo tecleado. `[[/docs` no pide una nota `/docs`, pide bajar por `docs`:
    -- de ahí salía el `[[<id>|/do]] (create)` que no significaba nada.
    local sanitize = require("lzy.obsidian.completion").sanitize
    local function create_item(term)
      return {
        label = ("[[%s]] (create)"):format(term),
        sortText = term,
        filterText = term,
        command = { command = "obsidian.write_note", title = "Obsidian write note" },
        textEdit = { newText = ("[[1786867178-OZDA|%s]]"):format(term) },
      }
    end

    local list = sanitize {
      items = {
        create_item("/docs"),
        create_item("./vecina"),
        create_item("docs/api"),
        create_item("Nota Nueva"),
        { label = "/docs/api.md", textEdit = { newText = "/docs/api.md" } },
      },
    }
    assert.are.same({ "[[Nota Nueva]] (create)", "/docs/api.md" }, vim.tbl_map(function(item)
      return item.label
    end, list.items))
  end)

  describe("browsing a path inside a link", function()
    -- Escribir una ruta es escribir una ruta: las tres sintaxis de destino se
    -- comportan igual. `[Algo](/` era la que no hacía nada.
    local SYNTAXES = { "[[", "[Algo](", "[id]: " }

    ---@return lsp.CompletionList
    local function complete(line)
      write("wiki.md", { line })
      vim.cmd.edit(vim.fs.joinpath(root, "wiki.md"))
      local result
      require("lzy.obsidian.completion").custom_completion({
        textDocument = { uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()) },
        position = { line = 0, character = #line },
      }, function(value)
        result = value
      end)
      assert(vim.wait(2000, function()
        return result ~= nil
      end, 10), "completion did not finish")
      return result
    end

    local function item(result, target)
      return vim.iter(result.items):find(function(entry)
        return entry.textEdit.newText == target
      end)
    end

    it("opens both roots on the bare slash, without waiting for a letter", function()
      write("docs/archlinux.md", { "# Arch" })

      for _, syntax in ipairs(SYNTAXES) do
        local result = complete(syntax .. "/")
        local docs = item(result, "/docs/")
        assert.is_not_nil(docs, "no folder from the vault root in " .. syntax)
        assert.are.equal("Carpeta del vault", docs.detail)
        assert.are.same({ line = 0, character = #syntax }, docs.textEdit.range.start)
        -- La barra es ambigua a propósito: también la raíz del sistema.
        assert.is_not_nil(
          vim.iter(result.items):find(function(entry)
            return entry.detail == "Carpeta del sistema"
          end),
          "no folder from the system root in " .. syntax
        )
        -- Un nivel cada vez: lo de dentro de docs llega al bajar, no antes.
        assert.is_nil(item(result, "/docs/archlinux.md"))
      end
    end)

    it("lists the notes of a folder once you are inside it", function()
      -- Aceptar `/docs/` y quedarse sin nada era el agujero: obsidian.nvim
      -- busca notas por nombre y no entiende un destino que empieza por `/`.
      write("docs/archlinux.md", { "# Arch" })
      write("docs/windows11.md", { "# Windows" })
      write("docs/caos/nota.md", { "# Caos" })

      for _, syntax in ipairs(SYNTAXES) do
        -- Cada sintaxis inserta SU forma canónica: en `[[` el destino va sin
        -- extensión, en las Markdown el `.md` es obligatorio (sin él GitHub da
        -- 404). Ver docs/todo-markdown.md §1.5 y §1.6.
        local function target(name)
          return syntax == "[[" and (name:gsub("%.md$", "")) or name
        end

        local inside = complete(syntax .. "/docs/")
        local arch = item(inside, target "/docs/archlinux.md")
        assert.is_not_nil(arch, "the folder's notes are missing in " .. syntax)
        assert.are.equal("Nota del vault", arch.detail)
        assert.are.equal(vim.lsp.protocol.CompletionItemKind.File, arch.kind)
        assert.is_not_nil(item(inside, target "/docs/windows11.md"))
        -- Las subcarpetas siguen ofreciéndose, y antes que las notas.
        local caos = item(inside, "/docs/caos/")
        assert.is_not_nil(caos)
        assert.is_true(caos.sortText < arch.sortText)

        -- Y filtrando por lo tecleado.
        local filtered = complete(syntax .. "/docs/arch")
        assert.is_not_nil(item(filtered, target "/docs/archlinux.md"))
        assert.is_nil(item(filtered, target "/docs/windows11.md"))
      end
    end)

    it("searches notes by name where obsidian-ls does not complete at all", function()
      -- En `[[` la búsqueda por nombre ya la pone el proveedor original; en un
      -- enlace Markdown o en una definición no la pone nadie.
      write("docs/archlinux.md", { "# Arch" })

      for _, syntax in ipairs { "[Algo](", "[id]: " } do
        local result = complete(syntax .. "archl")
        local arch = item(result, "docs/archlinux.md")
        assert.is_not_nil(arch, "the note was not found by name in " .. syntax)
        assert.are.equal("Nota del vault", arch.detail)
        assert.are.same({ line = 0, character = #syntax }, arch.textEdit.range.start)
      end
    end)

    it("replaces only the path of a Markdown link, never its fragment", function()
      write("docs/archlinux.md", { "# Arch" })

      local line = "[Algo](/docs/arch#instalación)"
      write("wiki.md", { line })
      vim.cmd.edit(vim.fs.joinpath(root, "wiki.md"))
      local result
      require("lzy.obsidian.completion").custom_completion({
        textDocument = { uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()) },
        position = { line = 0, character = #"[Algo](/docs/arch" },
      }, function(value)
        result = value
      end)
      assert(vim.wait(2000, function()
        return result ~= nil
      end, 10), "completion did not finish")

      local arch = item(result, "/docs/archlinux.md")
      assert.is_not_nil(arch)
      assert.are.same({ line = 0, character = 7 }, arch.textEdit.range.start)
      assert.are.same({ line = 0, character = #"[Algo](/docs/arch" }, arch.textEdit.range["end"])
    end)

    it("resolves the note it just inserted", function()
      write("docs/archlinux.md", { "# Arch" })
      local resolved
      require("lzy.obsidian.notes").resolve_async("/docs/archlinux.md", function(notes)
        resolved = notes
      end)
      vim.wait(2000, function()
        return resolved ~= nil
      end, 20)
      assert.are.equal(1, #resolved)
      assert.are.equal(
        vim.fs.joinpath(root, "docs/archlinux.md"),
        vim.fs.normalize(tostring(resolved[1].path))
      )
    end)

    it("declares the slash as a trigger character, which obsidian-ls does not", function()
      local capabilities
      require("obsidian.lsp.handlers")["initialize"]({}, function(_, result)
        capabilities = result.capabilities
      end, { notification = function() end })
      assert.is_true(
        vim.tbl_contains(capabilities.completionProvider.triggerCharacters, "/"),
        "the client will not ask for completion when you type /"
      )
    end)
  end)

  it("finds the target being typed in any link syntax, not only in [[", function()
    local context = require("lzy.obsidian.completion").target_context
    ---@param line string
    ---@param character integer
    local function found(line, character)
      local ctx = assert(context(line, character), "no target in " .. line)
      return {
        kind = ctx.kind,
        search = ctx.search,
        start_col = ctx.start_col,
        end_col = ctx.end_col,
      }
    end

    assert.are.same(
      { kind = "wiki", search = "/do", start_col = 8, end_col = 11 },
      found("texto [[/do", 11)
    )
    assert.are.equal("", context("[[", 2).search)
    -- A partir del `|` o del `#` manda el proveedor original.
    assert.is_nil(context("[[nota|Ali", 10))
    assert.is_nil(context("[[nota#anc", 10))
    assert.is_nil(context("[[nota]] ya cerrado", 19))
    assert.is_nil(context("sin corchetes", 13))

    -- El mismo destino con los delimitadores de un enlace o embed Markdown.
    assert.are.same(
      { kind = "inline", search = "/do", start_col = 13, end_col = 16 },
      found("texto [Algo](/do", 16)
    )
    assert.are.same(
      { kind = "inline", search = "/im", start_col = 8, end_col = 11 },
      found("![Logo](/im", 11)
    )
    -- Un fragment ya escrito no entra en el reemplazo, y desde él manda el
    -- proveedor original.
    assert.are.equal(10, found("[Algo](/do#head)", 10).end_col)
    assert.is_nil(context("[Algo](/do#head)", 12))
    -- La etiqueta no es un destino, y un enlace ya cerrado tampoco.
    assert.is_nil(context("[Al", 3))
    assert.is_nil(context("[Algo](/do) ya cerrado", 22))

    -- Y con los de una definición.
    assert.are.same(
      { kind = "definition", search = "/do", start_col = 6, end_col = 9 },
      found("[id]: /do", 9)
    )
  end)

  describe("smart copy", function()
    local function copy_at(row, col)
      vim.api.nvim_win_set_cursor(0, { row, col })
      local got
      require("lzy.obsidian.smart_copy").smart_copy {
        copy = function(text)
          got = text
        end,
        notify = function() end,
      }
      return got
    end

    it("copies the target or label of a wiki link, without brackets/pipe", function()
      write("source.md", { "Some [[nota|Display Label]] and plain text." })
      vim.cmd.edit(root .. "/source.md")
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local target_col = line:find("nota", 1, true) - 1 + 1
      local label_col = line:find("Display Label", 1, true) - 1 + 1
      assert.are.equal("nota", copy_at(1, target_col))
      assert.are.equal("Display Label", copy_at(1, label_col))
    end)

    -- Igual que en el test de negrita/cursiva: este arnés no dispara el
    -- highlight que en uso real ya deja el árbol (y sus inyecciones)
    -- parseado, así que se fuerza.
    local function start_treesitter()
      vim.bo[0].filetype = "markdown"
      vim.treesitter.start(0, "markdown")
      vim.treesitter.get_parser(0, "markdown"):parse(true)
    end

    it("copies the content of an inline code span, backticks aside", function()
      write("source.md", {
        "Corre `git status` y ``con ` dentro`` y `` [[nota]] `` al final.",
      })
      vim.cmd.edit(root .. "/source.md")
      start_treesitter()
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local function mid(pattern)
        local s, e = line:find(pattern, 1, true)
        return math.floor((s + e) / 2)
      end
      assert.are.equal("git status", copy_at(1, mid "git status"))
      assert.are.equal("con ` dentro", copy_at(1, mid "con ` dentro"))
      -- Dentro de código no hay enlace que seguir, solo texto literal.
      assert.are.equal("[[nota]]", copy_at(1, mid "[[nota]]"))
    end)

    it("lets the last blank line of a fence decide the trailing newline", function()
      write("source.md", {
        "```lua",
        "local x = 1",
        "",
        "```",
        "",
        "- item",
        "  ```sh",
        "  echo hola",
        "",
        "  ```",
      })
      vim.cmd.edit(root .. "/source.md")
      start_treesitter()
      -- La línea en blanco que dejó el usuario es contenido; el salto que
      -- precede al cierre, no.
      assert.are.equal("local x = 1\n", copy_at(2, 3))
      assert.are.equal("echo hola\n", copy_at(8, 4))
    end)

    it("copies the body of a code block without fences or trailing newline", function()
      write("source.md", {
        "Antes",
        "",
        "```lua",
        "local x = 1",
        "    return x",
        "```",
        "",
        "- item",
        "  ```sh",
        "  echo hola",
        "  echo adios",
        "  ```",
      })
      vim.cmd.edit(root .. "/source.md")
      start_treesitter()
      -- Desde el cuerpo, desde la línea del fence y desde el cierre.
      assert.are.equal("local x = 1\n    return x", copy_at(4, 3))
      assert.are.equal("local x = 1\n    return x", copy_at(3, 1))
      assert.are.equal("local x = 1\n    return x", copy_at(6, 1))
      -- En una lista, la sangría del fence no es del código.
      assert.are.equal("echo hola\necho adios", copy_at(10, 4))
    end)

    it("copies bold/italic/bold-italic content without the markers", function()
      write("source.md", {
        "Bold ***hola*** and **soloBold** and *soloItalic* and __underBold__ and _underItalic_.",
      })
      vim.cmd.edit(root .. "/source.md")
      vim.bo[0].filetype = "markdown"
      vim.treesitter.start(0, "markdown")
      -- El harness de este arnés de tests no dispara el highlight que en
      -- uso real ya deja el árbol (y sus inyecciones markdown_inline)
      -- parseado; lo forzamos para no depender de eso.
      vim.treesitter.get_parser(0, "markdown"):parse(true)
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local function mid(pattern)
        local s, e = line:find(pattern, 1, true)
        return math.floor((s + e) / 2)
      end
      assert.are.equal("hola", copy_at(1, mid "hola"))
      assert.are.equal("soloBold", copy_at(1, mid "soloBold"))
      assert.are.equal("soloItalic", copy_at(1, mid "soloItalic"))
      assert.are.equal("underBold", copy_at(1, mid "underBold"))
      assert.are.equal("underItalic", copy_at(1, mid "underItalic"))
    end)

    it("copies strikethrough content without the tildes, single or double", function()
      write("source.md", {
        "Tachado ~solo~ y ~~doble~~ tilde.",
      })
      vim.cmd.edit(root .. "/source.md")
      vim.bo[0].filetype = "markdown"
      vim.treesitter.start(0, "markdown")
      vim.treesitter.get_parser(0, "markdown"):parse(true)
      local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local function mid(pattern)
        local s, e = line:find(pattern, 1, true)
        return math.floor((s + e) / 2)
      end
      assert.are.equal("solo", copy_at(1, mid "solo"))
      assert.are.equal("doble", copy_at(1, mid "doble"))
    end)

    it("copies a pasteable [[Note#anchor]] link when the cursor is on a heading", function()
      write("Windows 11.md", { "# My Header", "", "body" })
      vim.cmd.edit(root .. "/Windows 11.md")
      assert.are.equal("[[Windows 11#My Header]]", copy_at(1, 3))
    end)

    it("falls back to a link to the current note on plain text with nothing else to copy", function()
      write("source.md", { "Just plain text, nothing special here." })
      vim.cmd.edit(root .. "/source.md")
      assert.are.equal("[[source]]", copy_at(1, 5))
    end)

    it("copies nothing when there isn't even a note to link back to (unnamed buffer)", function()
      vim.cmd "enew"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Just plain text, nothing special here." })
      assert.is_nil(copy_at(1, 5))
    end)
  end)
end)
