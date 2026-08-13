local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)

describe("TSInstallAll Windows TLS preflight", function()
  local originals
  local notifications
  local system_commands
  local install_calls
  local parser_url = "https://github.com/tree-sitter-grammars/tree-sitter-lua"
  local revision = "10fe0054734eec83049514ea2e718b2a56acd0c9"
  local archive_url = parser_url .. "/archive/" .. revision .. ".tar.gz"

  local function has_argument(command, expected)
    for _, argument in ipairs(command) do
      if argument == expected then
        return true
      end
    end
    return false
  end

  local function prepare(probe_results, selection)
    originals = {
      executable = vim.fn.executable,
      has = vim.fn.has,
      notify = vim.notify,
      select = vim.ui.select,
      system = vim.system,
      treesitter = package.loaded["nvim-treesitter"],
      config = package.loaded["nvim-treesitter.config"],
      parsers = package.loaded["nvim-treesitter.parsers"],
    }
    notifications = {}
    system_commands = {}
    install_calls = 0

    vim.fn.executable = function(command)
      return (command == "tree-sitter" or command == "curl") and 1 or 0
    end
    vim.fn.has = function(feature)
      return (feature == "win32" or feature == "win64") and 1 or 0
    end
    vim.notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end
    vim.ui.select = function(_, _, callback)
      callback(selection)
    end

    local probe_index = 0
    vim.system = function(command, _, callback)
      system_commands[#system_commands + 1] = vim.deepcopy(command)
      if command[1] == "tree-sitter" then
        return {
          wait = function()
            return { code = 0, stdout = "tree-sitter 0.26.9", stderr = "" }
          end,
        }
      end

      if callback then
        local result = { code = 0, stdout = "", stderr = "" }
        if has_argument(command, "--head") then
          probe_index = probe_index + 1
          result = probe_results[probe_index]
        end
        vim.schedule(function()
          callback(result)
        end)
      end
      return {}
    end

    package.loaded["nvim-treesitter.config"] = {
      norm_languages = function()
        return { "lua" }
      end,
    }
    package.loaded["nvim-treesitter.parsers"] = {
      lua = { install_info = { url = parser_url, revision = revision } },
    }
    package.loaded["nvim-treesitter"] = {
      install = function()
        install_calls = install_calls + 1
        vim.system({ "curl", archive_url }, {}, function() end)
        vim.system({ "curl", "https://example.com/unrelated" }, {}, function() end)
        return {
          await = function(_, callback)
            vim.schedule(function()
              callback(nil, true)
            end)
          end,
        }
      end,
    }

    package.loaded["lzy.treesitter"] = nil
    local treesitter = require "lzy.treesitter"
    treesitter.languages = { "lua" }
    return treesitter
  end

  after_each(function()
    vim.wait(1000, function()
      return vim.system ~= nil
    end, 10)
    vim.fn.executable = originals.executable
    vim.fn.has = originals.has
    vim.notify = originals.notify
    vim.ui.select = originals.select
    vim.system = originals.system
    package.loaded["nvim-treesitter"] = originals.treesitter
    package.loaded["nvim-treesitter.config"] = originals.config
    package.loaded["nvim-treesitter.parsers"] = originals.parsers
    package.loaded["lzy.treesitter"] = nil
  end)

  it("retries only pinned parser downloads after explicit consent", function()
    local treesitter = prepare({
      { code = 35, stdout = "", stderr = "schannel: CRYPT_E_NO_REVOCATION_CHECK" },
    }, "Reintentar solo esta vez")
    local base_system = vim.system

    treesitter.install_all()
    assert(vim.wait(1000, function()
      return install_calls == 1 and vim.system == base_system
    end, 10))

    local parser_download = system_commands[2]
    local unrelated_download = system_commands[3]
    assert.is_true(has_argument(parser_download, "--ssl-revoke-best-effort"))
    assert.is_false(has_argument(unrelated_download, "--ssl-revoke-best-effort"))
    assert.matches("solo durante esta ejecución", notifications[#notifications].message)
  end)

  it("cancels without installing or changing curl", function()
    local treesitter = prepare({
      { code = 35, stdout = "", stderr = "schannel: CRYPT_E_NO_REVOCATION_CHECK" },
    }, "Cancelar")
    local base_system = vim.system

    treesitter.install_all()
    assert(vim.wait(1000, function()
      return #notifications > 0
    end, 10))

    assert.are.equal(0, install_calls)
    assert.are.equal(base_system, vim.system)
    assert.matches("cancelada", notifications[#notifications].message)
  end)

  it("does not offer the exception for unrelated curl failures", function()
    local select_called = false
    local treesitter = prepare({
      { code = 60, stdout = "", stderr = "SSL certificate problem" },
    }, nil)
    vim.ui.select = function()
      select_called = true
    end

    treesitter.install_all()
    assert(vim.wait(1000, function()
      return #notifications > 0
    end, 10))

    assert.is_false(select_called)
    assert.are.equal(0, install_calls)
    assert.matches("no pudo comprobar", notifications[#notifications].message)
  end)

  it("stops before downloading when tree-sitter-cli is missing", function()
    local treesitter = prepare({}, nil)
    vim.fn.executable = function(command)
      return command == "curl" and 1 or 0
    end

    treesitter.install_all()

    assert.are.equal(0, #system_commands)
    assert.are.equal(0, install_calls)
    assert.matches("No se encuentra tree%-sitter%-cli", notifications[#notifications].message)
  end)
end)
