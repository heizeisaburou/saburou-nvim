-- sabunv.terminal

local M = {}

-- -----------------------------------------------------------------------------
-- Terminal state
-- -----------------------------------------------------------------------------

local terminals = {
  horizontal = {
    buf = nil,
    win = nil,
    job = nil,
    name = "sbnv_horizontal_terminal",
  },

  vertical = {
    buf = nil,
    win = nil,
    job = nil,
    name = "sbnv_vertical_terminal",
  },

  float = {
    buf = nil,
    win = nil,
    job = nil,
    name = "sbnv_floating_terminal",
  },
}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function create_terminal_buffer(term)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(buf, term.name)
  vim.b[buf].sbnv_terminal = true

  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })

  return buf
end

local function ensure_terminal_buffer(term)
  if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    return
  end

  term.buf = create_terminal_buffer(term)
end

local function start_terminal_job(term)
  if term.job then
    return
  end

  vim.api.nvim_buf_call(term.buf, function()
    term.job = vim.fn.termopen(vim.o.shell, {
      on_exit = function()
        term.job = nil
      end,
    })
  end)
end

local function hide_terminal_window(term)
  vim.api.nvim_win_hide(term.win)
  term.win = nil
end

local function is_window_open(term)
  return term.win and vim.api.nvim_win_is_valid(term.win)
end

local function enter_terminal()
  vim.cmd "startinsert"
end

-- -----------------------------------------------------------------------------
-- Split terminals
-- -----------------------------------------------------------------------------

local function open_horizontal_window(term)
  vim.cmd "split"
  term.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term.win, term.buf)
end

local function open_vertical_window(term)
  vim.cmd "vsplit"
  term.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term.win, term.buf)
end

local function toggle_split(term, open_window)
  if is_window_open(term) then
    hide_terminal_window(term)
    return
  end

  ensure_terminal_buffer(term)
  open_window(term)
  start_terminal_job(term)
  enter_terminal()
end

function M.open_horizontal_split()
  toggle_split(terminals.horizontal, open_horizontal_window)
end

function M.open_vertical_split()
  toggle_split(terminals.vertical, open_vertical_window)
end

-- -----------------------------------------------------------------------------
-- Floating terminal
-- -----------------------------------------------------------------------------

local function open_float_window(term)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  term.win = vim.api.nvim_open_win(term.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = "  Terminal ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
    { win = term.win }
  )
end

function M.toggle_float()
  local term = terminals.float

  if is_window_open(term) then
    hide_terminal_window(term)
    return
  end

  ensure_terminal_buffer(term)
  open_float_window(term)
  start_terminal_job(term)
  enter_terminal()
end

return M
