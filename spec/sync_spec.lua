-- Este spec sustituye funciones de `vim.fn` a propósito: son los mocks.
---@diagnostic disable: duplicate-set-field

local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Sabunv sync", function()
  local previous = {}
  local sync
  local command
  local has_rsync
  local directories

  local function load_sync()
    package.loaded["hzsr.sync"] = nil
    return require "hzsr.sync"
  end

  --- El argumento de `--exclude` que sigue a cada bandera.
  local function excludes()
    local result = {}
    for index, argument in ipairs(command or {}) do
      if argument == "--exclude" then
        result[#result + 1] = command[index + 1]
      end
    end
    return result
  end

  before_each(function()
    previous.system = vim.fn.system
    previous.executable = vim.fn.executable
    previous.isdirectory = vim.fn.isdirectory
    previous.notify = vim.notify

    command = nil
    has_rsync = true
    directories = { ["/src"] = true }

    vim.fn.executable = function(name)
      return (name == "rsync" and has_rsync) and 1 or 0
    end
    vim.fn.isdirectory = function(path)
      return directories[path] and 1 or 0
    end
    vim.fn.system = function(cmd)
      command = cmd
      -- `vim.v.shell_error` es de solo lectura: solo lo mueve un `system` de
      -- verdad, así que se lanza uno que sale bien para dejarlo en 0.
      previous.system { "true" }
      return ""
    end
    vim.notify = function() end

    sync = load_sync()
  end)

  after_each(function()
    vim.fn.system = previous.system
    vim.fn.executable = previous.executable
    vim.fn.isdirectory = previous.isdirectory
    vim.notify = previous.notify
    package.loaded["hzsr.sync"] = nil
  end)

  it("no copia lo que cada instalación genera para sí misma", function()
    assert.is_true(sync.deploy("/src", "/dst"))
    -- El `.git` no está en la lista a propósito: esto reemplaza la carpeta
    -- entera, historia incluida, para que el destino quede siendo el origen.
    assert.is_false(vim.tbl_contains(excludes(), ".git"))
    -- `.luarc.json` es el que importa: lleva rutas absolutas al directorio de
    -- plugins del NVIM_APPNAME que lo generó, así que copiarlo deja al destino
    -- mirando la biblioteca del origen.
    assert.are.same({ ".luarc.json", "lazy-lock.json", "nvim.log" }, excludes())
  end)

  it("borra en destino lo que sobra, pero no lo excluido", function()
    assert.is_true(sync.deploy("/src", "/dst"))
    assert.is_true(vim.tbl_contains(command, "--delete"))
    -- rsync protege de `--delete` lo que está excluido, que es justo por lo que
    -- el `.luarc.json` del destino sobrevive a la copia.
    assert.are.equal("/src/", command[#command - 1])
    assert.are.equal("/dst/", command[#command])
  end)

  it("no inventa un origen que no existe", function()
    assert.is_false(sync.deploy("/no-existe", "/dst"))
    assert.is_nil(command)
  end)

  it("cae a cp donde no hay rsync", function()
    has_rsync = false
    assert.is_true(sync.deploy("/src", "/dst"))
    assert.are.same({ "cp", "-a", "/src/.", "/dst/" }, command)
  end)
end)
