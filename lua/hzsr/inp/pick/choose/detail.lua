-- hzsr.inp.pick.choose.detail

local M = {}

---@param prompt string
---@param items string[]
---@param default? integer
---@return string prompt, string[] items, integer default
function M.validate(prompt, items, default)
  vim.validate("prompt", prompt, "string")
  vim.validate("items", items, "table")
  vim.validate("default", default, "number", true)

  items = vim.deepcopy(items)
  default = default or #items

  hzsr.tbl.lst.assert.of_str("items", items)
  hzsr.tbl.assert.not_empty("items", items)
  hzsr.tbl.lst.assert.unique("items", items)

  hzsr.num.assert.range("default", default, 1, #items)

  return prompt, items, default
end

return M
