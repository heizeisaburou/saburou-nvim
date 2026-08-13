local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Sabunv Windows terminal shell", function()
  local previous = {}
  local executables

  local function load_terminal()
    package.loaded["sabunv.terminal"] = nil
    return require "sabunv.terminal"
  end

  before_each(function()
    previous.hzsr = _G.hzsr
    previous.exepath = vim.fn.exepath
    previous.comspec = vim.env.COMSPEC
    previous.notify = vim.notify
    previous.shell = vim.o.shell

    _G.hzsr = { sys = { iswin = true } }
    vim.env.COMSPEC = "C:\\Windows\\System32\\cmd.exe"
    executables = {}
    vim.fn.exepath = function(name)
      return executables[name] or ""
    end
    vim.notify = function() end
  end)

  after_each(function()
    _G.hzsr = previous.hzsr
    vim.fn.exepath = previous.exepath
    vim.env.COMSPEC = previous.comspec
    vim.notify = previous.notify
    vim.o.shell = previous.shell
    package.loaded["sabunv.terminal"] = nil
  end)

  it("prefers pwsh in auto mode", function()
    executables.pwsh = "C:\\Program Files\\PowerShell\\7\\pwsh.exe"
    executables.powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    local terminal = load_terminal()

    terminal.setup({ windows_shell = "auto" })

    assert.are.same({
      preference = "auto",
      selected = "pwsh",
      command = { "C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoLogo" },
      fallback = false,
    }, terminal.info())
  end)

  it("falls from pwsh to Windows PowerShell in auto mode", function()
    executables.powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    local terminal = load_terminal()

    terminal.setup({ windows_shell = "auto" })

    assert.are.same({
      preference = "auto",
      selected = "powershell",
      command = { "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "-NoLogo" },
      fallback = false,
    }, terminal.info())
  end)

  it("falls from both PowerShell editions to cmd in auto mode", function()
    local terminal = load_terminal()

    terminal.setup({ windows_shell = "auto" })

    assert.are.same({
      preference = "auto",
      selected = "cmd",
      command = { "C:\\Windows\\System32\\cmd.exe" },
      fallback = false,
    }, terminal.info())
  end)

  it("supports every explicit Windows shell preference", function()
    executables.pwsh = "C:\\PowerShell\\pwsh.exe"
    executables.powershell = "C:\\WindowsPowerShell\\powershell.exe"
    local terminal = load_terminal()

    terminal.setup({ windows_shell = "pwsh" })
    assert.are.same({ "C:\\PowerShell\\pwsh.exe", "-NoLogo" }, terminal.info().command)

    terminal.setup({ windows_shell = "powershell" })
    assert.are.same({ "C:\\WindowsPowerShell\\powershell.exe", "-NoLogo" }, terminal.info().command)

    terminal.setup({ windows_shell = "cmd" })
    assert.are.same({ "C:\\Windows\\System32\\cmd.exe" }, terminal.info().command)
  end)

  it("keeps startup usable when an explicit PowerShell executable is missing", function()
    local terminal = load_terminal()

    terminal.setup({ windows_shell = "powershell" })

    assert.are.same({
      preference = "powershell",
      selected = "cmd",
      command = { "C:\\Windows\\System32\\cmd.exe" },
      fallback = true,
    }, terminal.info())
  end)

  it("rejects unknown preferences", function()
    local terminal = load_terminal()

    assert.has_error(function()
      terminal.setup({ windows_shell = "fish" })
    end, "terminal.windows_shell debe ser 'auto', 'pwsh', 'powershell' o 'cmd'")
  end)

  it("leaves the Neovim execution shell untouched outside Windows", function()
    _G.hzsr.sys.iswin = false
    vim.o.shell = "/bin/custom-shell"
    local terminal = load_terminal()

    terminal.setup({ windows_shell = "powershell" })

    assert.are.equal("/bin/custom-shell", vim.o.shell)
    assert.are.same({
      preference = "powershell",
      selected = "system",
      command = "/bin/custom-shell",
      fallback = false,
    }, terminal.info())
  end)
end)
