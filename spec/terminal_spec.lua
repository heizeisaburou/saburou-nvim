-- Este spec sustituye funciones de `vim.fn` a propósito: son los mocks.
---@diagnostic disable: duplicate-set-field

local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Sabunv terminal shell", function()
  local previous = {}
  local executables
  local ancestors
  local proc_available

  local function load_terminal()
    package.loaded["sabunv.terminal"] = nil
    return require "sabunv.terminal"
  end

  --- Antepasados que verá `auto`, del más cercano al más lejano.
  ---@param list table[]
  local function tree(list)
    ancestors = list
  end

  before_each(function()
    previous.hzsr = _G.hzsr
    previous.exepath = vim.fn.exepath
    previous.executable = vim.fn.executable
    previous.comspec = vim.env.COMSPEC
    previous.shell_env = vim.env.SHELL
    previous.notify = vim.notify
    previous.shell = vim.o.shell
    previous.proc = package.loaded["hzsr.sys.proc"]

    _G.hzsr = { sys = { iswin = true } }
    vim.env.COMSPEC = "C:\\Windows\\System32\\cmd.exe"
    vim.env.SHELL = "/usr/bin/zsh"
    executables = {}
    ancestors = {}
    proc_available = true

    vim.fn.exepath = function(name)
      return executables[name] or ""
    end
    vim.fn.executable = function(name)
      return executables[name] and 1 or 0
    end
    vim.notify = function() end

    -- El árbol de procesos es lo único que no se puede fabricar de verdad en un
    -- test, así que se sustituye entero.
    package.loaded["hzsr.sys.proc"] = {
      available = function()
        return proc_available
      end,
      ancestors = function()
        return ancestors
      end,
    }
  end)

  after_each(function()
    _G.hzsr = previous.hzsr
    vim.fn.exepath = previous.exepath
    vim.fn.executable = previous.executable
    vim.env.COMSPEC = previous.comspec
    vim.env.SHELL = previous.shell_env
    vim.notify = previous.notify
    vim.o.shell = previous.shell
    package.loaded["hzsr.sys.proc"] = previous.proc
    package.loaded["sabunv.terminal"] = nil
  end)

  -- ---------------------------------------------------------------------------
  -- auto: heredar la shell en la que estás
  -- ---------------------------------------------------------------------------

  describe("auto", function()
    before_each(function()
      _G.hzsr.sys.iswin = false
      vim.o.shell = "/usr/bin/zsh"
      executables["/usr/bin/zsh"] = "/usr/bin/zsh"
    end)

    it("hereda la shell del proceso padre, no la de $SHELL", function()
      -- El caso que motivó todo esto: pwsh abierto desde zsh. $SHELL sigue
      -- diciendo zsh porque ninguna shell la reescribe al arrancar.
      tree {
        { pid = 10, name = "pwsh", path = "/usr/lib/powershell-7/pwsh" },
        { pid = 9, name = "zsh", path = "/usr/bin/zsh" },
      }
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.same({
        preference = "auto",
        source = "inherited",
        selected = "pwsh",
        command = { "/usr/lib/powershell-7/pwsh", "-NoLogo" },
        fallback = false,
      }, terminal.info())
    end)

    it("atraviesa a los antepasados que no son shells", function()
      -- `git commit` deja a git de padre y la shell un nivel más arriba.
      tree {
        { pid = 10, name = "git", path = "/usr/bin/git" },
        { pid = 9, name = "fish", path = "/usr/bin/fish" },
      }
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.equal("fish", terminal.info().selected)
      assert.are.same({ "/usr/bin/fish" }, terminal.info().command)
    end)

    it("no hereda sh cuando no es tu shell de login", function()
      -- Lanzado desde el `sh -c` de un .desktop o de un Makefile: /bin/sh no es
      -- la terminal que quieres, así que se sigue subiendo.
      tree {
        { pid = 10, name = "sh", path = "/usr/bin/sh" },
        { pid = 9, name = "zsh", path = "/usr/bin/zsh" },
      }
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.equal("zsh", terminal.info().selected)
    end)

    it("sí hereda sh cuando es tu shell de login", function()
      vim.env.SHELL = "/bin/sh"
      tree { { pid = 10, name = "sh", path = "/bin/sh" } }
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.equal("sh", terminal.info().selected)
      assert.are.same({ "/bin/sh" }, terminal.info().command)
    end)

    it("resuelve por nombre cuando no puede leer la ruta del antepasado", function()
      -- Con `sudo` en medio, /proc/<pid>/exe no es legible; queda el nombre.
      executables.bash = "/usr/bin/bash"
      tree { { pid = 10, name = "bash", path = nil } }
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.same({ "/usr/bin/bash" }, terminal.info().command)
    end)

    it("cae a la del sistema cuando ningún antepasado es una shell", function()
      -- Neovim abierto desde un lanzador gráfico.
      tree { { pid = 10, name = "systemd", path = "/usr/lib/systemd/systemd" } }
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      local info = terminal.info()
      assert.are.equal("system", info.source)
      assert.are.same({ "/usr/bin/zsh" }, info.command)
      -- No poder heredar no es un fallo: no hay nada que heredar.
      assert.is_false(info.fallback)
    end)

    it("cae a la del sistema donde el árbol no es consultable", function()
      proc_available = false
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.equal("system", terminal.info().source)
    end)

    it("es el valor por defecto", function()
      tree { { pid = 10, name = "bash", path = "/usr/bin/bash" } }
      local terminal = load_terminal()

      terminal.setup()

      assert.are.equal("auto", terminal.info().preference)
      assert.are.equal("bash", terminal.info().selected)
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- system: lo que elegiría la plataforma
  -- ---------------------------------------------------------------------------

  describe("system", function()
    it("usa vim.o.shell fuera de Windows, como lista", function()
      _G.hzsr.sys.iswin = false
      vim.o.shell = "/bin/custom-shell"
      executables["/bin/custom-shell"] = "/bin/custom-shell"
      local terminal = load_terminal()

      terminal.setup { shell = "system" }

      assert.are.same({
        preference = "system",
        source = "system",
        selected = "custom-shell",
        -- Una lista, no una cadena: con una cadena jobstart la ejecutaría a
        -- través de 'shell' y saldría una shell dentro de otra.
        command = { "/bin/custom-shell" },
        fallback = false,
      }, terminal.info())
    end)

    it("conserva los argumentos de vim.o.shell", function()
      _G.hzsr.sys.iswin = false
      vim.o.shell = "/bin/bash --login"
      local terminal = load_terminal()

      terminal.setup { shell = "system" }

      assert.are.same({ "/bin/bash", "--login" }, terminal.info().command)
    end)

    it("prefiere pwsh en Windows", function()
      executables.pwsh = "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
      executables.powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
      local terminal = load_terminal()

      terminal.setup { shell = "system" }

      assert.are.same({
        preference = "system",
        source = "system",
        selected = "pwsh",
        command = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" },
        fallback = false,
      }, terminal.info())
    end)

    it("baja de pwsh a Windows PowerShell", function()
      executables.powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
      local terminal = load_terminal()

      terminal.setup { shell = "system" }

      assert.are.equal("powershell", terminal.info().selected)
    end)

    it("baja de las dos ediciones de PowerShell a cmd", function()
      local terminal = load_terminal()

      terminal.setup { shell = "system" }

      assert.are.same({
        preference = "system",
        source = "system",
        selected = "cmd",
        command = { "C:\\Windows\\System32\\cmd.exe" },
        fallback = false,
      }, terminal.info())
    end)

    it("es lo que usa auto en Windows, donde no hay árbol que leer", function()
      executables.pwsh = "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
      proc_available = false
      local terminal = load_terminal()

      terminal.setup { shell = "auto" }

      assert.are.equal("system", terminal.info().source)
      assert.are.equal("pwsh", terminal.info().selected)
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- explícita
  -- ---------------------------------------------------------------------------

  describe("explícita", function()
    it("acepta el nombre de cualquier shell", function()
      _G.hzsr.sys.iswin = false
      executables.fish = "/usr/bin/fish"
      local terminal = load_terminal()

      terminal.setup { shell = "fish" }

      assert.are.same({
        preference = "fish",
        source = "explicit",
        selected = "fish",
        command = { "/usr/bin/fish" },
        fallback = false,
      }, terminal.info())
    end)

    it("respeta un comando completo tal cual", function()
      _G.hzsr.sys.iswin = false
      local terminal = load_terminal()

      terminal.setup { shell = { "nu", "--login" } }

      assert.are.same({
        preference = { "nu", "--login" },
        source = "explicit",
        selected = "nu",
        command = { "nu", "--login" },
        fallback = false,
      }, terminal.info())
    end)

    it("avisa y sigue cuando la shell pedida no está instalada", function()
      -- Quedarse sin terminal es peor que abrir otra shell.
      local terminal = load_terminal()

      terminal.setup { shell = "powershell" }

      assert.are.same({
        preference = "powershell",
        source = "system",
        selected = "cmd",
        command = { "C:\\Windows\\System32\\cmd.exe" },
        fallback = true,
      }, terminal.info())
    end)

    it("rechaza una preferencia que no es ni nombre ni comando", function()
      local terminal = load_terminal()

      assert.has_error(function()
        ---@diagnostic disable-next-line: assign-type-mismatch
        terminal.setup { shell = 42 }
      end, "terminal.shell debe ser 'auto', 'system', el nombre de una shell o un comando completo")
    end)
  end)

  it("nunca toca la shell de ejecución de Neovim", function()
    -- `:!`, `:make` y los plugins siguen usando la que configuró Neovim.
    _G.hzsr.sys.iswin = false
    vim.o.shell = "/bin/custom-shell"
    tree { { pid = 10, name = "pwsh", path = "/usr/bin/pwsh" } }
    local terminal = load_terminal()

    terminal.setup { shell = "auto" }

    assert.are.equal("/bin/custom-shell", vim.o.shell)
    assert.are.equal("pwsh", terminal.info().selected)
  end)
end)
