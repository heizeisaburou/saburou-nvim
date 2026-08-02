-- hzsr.win.zoom

local M = {}

---@class hzsr.win.zoom.state
---@field wins integer[]
---@field restore_cmd string

---@type table<integer, hzsr.win.zoom.state>
local states = {}

---@param tabpage integer
---@return integer[]
local function tiled_windows(tabpage)
  return vim
    .iter(vim.api.nvim_tabpage_list_wins(tabpage))
    :filter(function(winid)
      return vim.api.nvim_win_get_config(winid).relative == ""
    end)
    :totable()
end

---@param left integer[]
---@param right integer[]
---@return boolean
local function same_windows(left, right)
  if #left ~= #right then
    return false
  end

  local wanted = {}
  for _, winid in ipairs(left) do
    wanted[winid] = true
  end

  return vim.iter(right):all(function(winid)
    return wanted[winid] == true
  end)
end

---@param tabpage integer
---@param state hzsr.win.zoom.state
---@return boolean restored
local function restore(tabpage, state)
  states[tabpage] = nil

  if not same_windows(state.wins, tiled_windows(tabpage)) then
    local ok, err = pcall(vim.cmd, "wincmd =")
    if not ok then
      vim.notify("Window zoom: " .. tostring(err), vim.log.levels.ERROR)
      return false
    end

    vim.notify("Window zoom: el layout cambió; se han equilibrado los splits", vim.log.levels.INFO)
    return true
  end

  local ok, err = pcall(vim.cmd, state.restore_cmd)
  if not ok then
    vim.notify("Window zoom: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

---Maximiza la ventana actual dentro de su tab o restaura las dimensiones
---anteriores. No cierra splits ni altera ventanas flotantes.
---@param winid? integer
---@return boolean changed
function M.toggle(winid)
  for tabpage in pairs(states) do
    if not vim.api.nvim_tabpage_is_valid(tabpage) then
      states[tabpage] = nil
    end
  end

  local target = hzsr.win.resolve(winid)
  local config = vim.api.nvim_win_get_config(target)

  if config.relative ~= "" then
    vim.notify("Window zoom: no se pueden maximizar ventanas flotantes", vim.log.levels.INFO)
    return false
  end

  local tabpage = vim.api.nvim_win_get_tabpage(target)
  local state = states[tabpage]

  if state then
    return restore(tabpage, state)
  end

  local wins = tiled_windows(tabpage)
  if #wins < 2 then
    vim.notify("Window zoom: no hay otros splits que ocultar", vim.log.levels.INFO)
    return false
  end

  vim.api.nvim_set_current_win(target)
  states[tabpage] = {
    wins = wins,
    restore_cmd = vim.fn.winrestcmd(),
  }

  local ok, err = pcall(function()
    vim.cmd "wincmd |"
    vim.cmd "wincmd _"
  end)

  if not ok then
    pcall(vim.cmd, states[tabpage].restore_cmd)
    states[tabpage] = nil
    vim.notify("Window zoom: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

return M
