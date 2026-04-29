-- hzsr.inp.pick.choose.sync

local M = {}

---@param prompt string
---@param items string[]
---@param default? integer
---@return integer|nil idx
function M.choose(prompt, items, default)
  local validate = hzsr.inp.pick.choose.detail.validate
  prompt, items, default = validate(prompt, items, default)

  local buttons = table.concat(
    vim.tbl_map(function(item)
      return "&" .. item
    end, items),
    "\n"
  )

  local ok, res = pcall(vim.fn.confirm, prompt, buttons, default)

  if not ok then
    if hzsr.nvim.error.is_keyboard_interrupt(res) then
      return nil
    end
    error(res)
  end

  return res
end

return M
