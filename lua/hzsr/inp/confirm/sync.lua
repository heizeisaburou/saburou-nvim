-- hzsr.inp.confirm.sync

local M = {}

local function simple_vim_confirm(prompt, default)
  local default_button = default and 1 or 2
  local result = vim.fn.confirm(prompt, "&Sí\n&No", default_button)

  if result == 0 then
    return nil
  end

  return result == 1
end

---@param prompt string
---@param default? boolean
---@return boolean|nil confirmación si se respondió, nil si se abortó
function M.confirm(prompt, default)
  prompt = prompt or ""
  default = default or false

  local ok, res = pcall(simple_vim_confirm, prompt, default)

  if not ok then
    if hzsr.nvim.error.is_keyboard_interrupt(res) then
      return nil
    end
    error(res)
  end

  return res
end

return M
