-- sabunv.edt

local M = {}

M.io = require "sabunv.edt.io"
M.edit = require "sabunv.edt.edit"

-- -----------------------------------------------------------------------------
-- Exec / notify

local function notify_result(result)
  vim.notify(vim.inspect(result), vim.log.levels.INFO)
end

local function notify_error(err)
  if hzsr.err.Error.instanceof(err) then
    vim.notify(err:format(), vim.log.levels.ERROR)
  else
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end

---@param fn fun(): any
---@param opts? { report?: boolean }
local function run_editor_action(fn, opts)
  opts = opts or {}

  coroutine.wrap(function()
    local ok, result_or_err = pcall(fn)

    if not ok then
      notify_error(result_or_err)
      return
    end

    if opts.report then
      notify_result(result_or_err)
    end
  end)()
end

-- -----------------------------------------------------------------------------
-- Navigation wrappers

function M.go_previous_buffer()
  return hzsr.edt.go_previous_buffer()
end

-- -----------------------------------------------------------------------------
-- Keybind groups

M.mappings = {}

-- -----------------------------------------------------------------------------
-- Keybinds

function M.mappings.setup()
  local map = vim.keymap.set

  M.io.mappings.setup()

  map("n", "<A-Tab>", function()
    run_editor_action(M.go_previous_buffer)
  end, { desc = "hzsr go previous buffer" })
end

return M
