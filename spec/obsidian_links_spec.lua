local plugin = "/home/saburou/.local/share/hzsr12/lazy/obsidian.nvim"
local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
vim.opt.runtimepath:prepend(plugin)

describe("Nyabsidian hierarchical links", function()
  local root = vim.fn.tempname()
  local notifications = {}
  local initialized = false

  local function write(path, lines)
    vim.fn.writefile(lines, vim.fs.joinpath(root, path))
  end

  local function reset_fixture()
    vim.cmd("silent! %bwipeout!")
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
      require("lzy.obsidian.links").setup({
        notify = function(msg, level)
          notifications[#notifications + 1] = { msg = msg, level = level }
        end,
      })
      require("obsidian").setup({
        legacy_commands = false,
        workspaces = { { path = root } },
        picker = { name = false },
        footer = { enabled = false },
        frontmatter = { enabled = false },
        ui = { enable = false },
        log_level = vim.log.levels.ERROR,
        search = { max_lines = 2 }, -- Nyabsidian debe leer la nota completa.
      })
      initialized = true
    end
    reset_fixture()
  end)

  after_each(function()
    vim.cmd("silent! %bwipeout!")
    vim.fn.delete(root, "rf")
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
    require("obsidian.lsp.handlers._definition").follow_link("[[nota#missing]]", function(_, result)
      locations = result
    end, { bufnr = 0 })
    vim.wait(3000, function()
      return locations ~= nil
    end, 10)

    assert.are.equal(1, #locations)
    assert.are.equal(vim.fs.joinpath(root, "nota.md"), vim.uri_to_fname(locations[1].uri))
    assert.are.equal(0, locations[1].range.start.line)
    assert.are.equal(vim.log.levels.ERROR, notifications[#notifications].level)
    assert.matches("missing", notifications[#notifications].msg)
  end)

  it("keeps attachment definition on the Obsidian file resolver", function()
    write("asset.custom", { "attachment" })
    write("source.md", { "![[asset.custom]]" })
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

    assert.are.equal(vim.fs.joinpath(root, "asset.custom"), opened)
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
    assert.are.same({ 14, 23 }, { subheader_range.start.character, subheader_range["end"].character })
  end)

  it("rejects names that cannot preserve a literal heading and a valid anchor", function()
    local headings = require("lzy.obsidian.headings")
    assert.is_nil(headings.validate_name("My Father A"))
    assert.matches("empezar ni terminar", headings.validate_name(" My Father A"))
    assert.matches("empezar ni terminar", headings.validate_name("My Father A "))
    assert.matches("contener '#'", headings.validate_name("Father#Child"))
    assert.matches("carácter válido", headings.validate_name("***"))
    assert.are.equal("my-father-a", headings.anchor_segment("My Father A"))
  end)

  local function rename_at(col, new_name)
    vim.api.nvim_win_set_cursor(0, { 1, col })
    local called = false
    require("obsidian.lsp.handlers")["textDocument/rename"]({ newName = new_name }, function(err, edit)
      assert.is_nil(err)
      vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      called = true
    end, {})
    vim.wait(3000, function()
      return called
    end, 10)
    vim.cmd("silent! wall")
  end

  it("renames a parent heading without touching standalone child anchors", function()
    rename_at(8, "Renamed")

    assert.are.same({ "# Renamed", "", "## Subheader", "", "### Child" }, vim.fn.readfile(root .. "/nota.md"))
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

    assert.are.same({ "# Header", "", "## My Father A", "", "### Child" }, vim.fn.readfile(root .. "/nota.md"))
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
    require("obsidian.lsp.handlers")["textDocument/rename"]({ newName = "From declaration" }, function(err, edit)
      assert.is_nil(err)
      vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      called = true
    end, {})
    vim.wait(3000, function()
      return called
    end, 10)
    vim.cmd("silent! wall")

    assert.are.same({ "# Header", "", "## From declaration", "", "### Child" }, vim.fn.readfile(root .. "/nota.md"))
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
end)
