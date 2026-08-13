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

  it("returns no fabricated hover for a frontmatter-only note", function()
    write("empty.md", { "---", "id: empty", "---" })
    write("source.md", { "[empty](empty.md)" })
    vim.cmd.edit(root .. "/source.md")

    local done, result = false
    require("obsidian.lsp.handlers")["textDocument/hover"]({
      textDocument = { uri = vim.uri_from_bufnr(0) },
      position = { line = 0, character = 3 },
    }, function(err, value)
      assert.is_nil(err)
      result, done = value, true
    end, {})
    assert(vim.wait(3000, function()
      return done
    end, 10), "hover did not finish")
    assert.is_nil(result)
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

  it("renames a parent heading without touching standalone child anchors", function()
    rename_at(8, "Renamed")

    assert.are.same(
      { "# Renamed", "", "## Subheader", "", "### Child" },
      vim.fn.readfile(root .. "/nota.md")
    )
    assert.are.same({
      "[[nota#renamed#subheader]]",
      "[[nota#subheader]]",
      "[[nota#renamed#subheader#child]]",
      "[[nota#child]]",
      "[label](nota.md#renamed#subheader)",
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
      "[[nota#header#my-father-a]]",
      "[[nota#my-father-a]]",
      "[[nota#header#my-father-a#child]]",
      "[[nota#child]]",
      "[label](nota.md#header#my-father-a)",
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
    assert.are.equal("[[nota#header#from-declaration]]", vim.fn.readfile(root .. "/source.md")[1])
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
      "[[nota#fathera#child-a]]",
      "[[nota#notename#fathera#child-a]]",
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
end)
