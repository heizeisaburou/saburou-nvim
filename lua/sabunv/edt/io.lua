-- sabunv.edt.io

local M = {}

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
-- Save wrappers

function M.save_current()
  return hzsr.edt.io.save.save(nil, {
    path = nil,
    path_policy = hzsr.edt.io.path_policy.AUTO,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffAdd
    async = nil,
  })
end

function M.save_all()
  return hzsr.edt.io.save.save_all {
    confirm = true,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffAdd
    async = nil,
  }
end

-- -----------------------------------------------------------------------------
-- Close wrappers: replace windows

---@param bufnr integer?
function M.close_buffer_replace(bufnr)
  return hzsr.edt.io.close.close(bufnr, {
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffDelete
    window_policy = hzsr.edt.io.window_policy.REPLACE,
    exit_last = false,
    async = nil,
  })
end

function M.close_current_replace()
  return M.close_buffer_replace(nil)
end

function M.close_all_replace()
  return hzsr.edt.io.close.close_all {
    confirm = true,
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffDelete
    window_policy = hzsr.edt.io.window_policy.REPLACE,
    exit_last = false,
    async = nil,
  }
end

-- -----------------------------------------------------------------------------
-- Close wrappers: close windows

function M.close_current_window()
  return hzsr.edt.io.close.close(nil, {
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffDelete
    window_policy = hzsr.edt.io.window_policy.CLOSE,
    exit_last = false,
    async = nil,
  })
end

function M.close_all_windows()
  return hzsr.edt.io.close.close_all {
    confirm = true,
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffDelete
    window_policy = hzsr.edt.io.window_policy.CLOSE,
    exit_last = false,
    async = nil,
  }
end

-- -----------------------------------------------------------------------------
-- Close all and leave wrapper

function M.close_all_windows_and_quit()
  local report = hzsr.edt.io.close.close_all {
    confirm = true,

    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,

    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = nil, -- DiffDelete

    window_policy = hzsr.edt.io.window_policy.CLOSE,
    exit_last = true,
    async = nil,
  }

  return report
end

-- -----------------------------------------------------------------------------
-- Keybind groups

M.mappings = {}
M.mappings.debug = {}

-- -----------------------------------------------------------------------------
-- Keybinds

function M.mappings.setup()
  local map = vim.keymap.set

  map("n", "<C-s>", function()
    run_editor_action(M.save_current)
  end, { desc = "hzsr save current buffer" })

  map("n", "<C-A-s>", function()
    run_editor_action(M.save_all)
  end, { desc = "hzsr save all modified buffers" })

  map("n", "<A-x>", function()
    run_editor_action(M.close_current_replace)
  end, { desc = "hzsr close current buffer replacing windows" })

  map("n", "<A-c>", function()
    run_editor_action(M.close_current_window)
  end, { desc = "hzsr close current buffer closing windows" })

  map("n", "<C-A-x>", function()
    run_editor_action(M.close_all_replace)
  end, { desc = "hzsr close all buffers replacing windows" })

  -- map("n", "<A-q>", function()
  --   run_editor_action(M.close_all_windows)
  -- end, { desc = "hzsr close all buffers closing windows" })

  map("n", "<C-A-q>", function()
    run_editor_action(M.close_all_windows_and_quit)
  end, { desc = "hzsr close all buffers closing windows, then force quit" })
end

-- -----------------------------------------------------------------------------
-- Debug/report variants, opcionales

function M.mappings.debug.setup()
  local map = vim.keymap.set

  map("n", "<leader>hs", function()
    run_editor_action(M.save_current, { report = true })
  end, { desc = "hzsr save current buffer and report" })

  map("n", "<leader>ha", function()
    run_editor_action(M.save_all, { report = true })
  end, { desc = "hzsr save all modified buffers and report" })

  map("n", "<leader>hx", function()
    run_editor_action(M.close_current_replace, { report = true })
  end, { desc = "hzsr close current buffer and report" })

  map("n", "<leader>hX", function()
    run_editor_action(M.close_all_replace, { report = true })
  end, { desc = "hzsr close all buffers and report" })
end

return M
