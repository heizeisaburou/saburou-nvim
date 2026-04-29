-- hzsr.tbl.lst

local M = {}

M.assert = {}

---@param name string
---@param t table
function M.assert.of_str(name, t)
  local it = vim.iter(t)
  if not it:all(function(v)
    return type(v) == "string"
  end) then
    error(("%s must be a list of strings"):format(name))
  end

  if not vim.islist(t) then
    error(("%s must be a list, not a map"):format(name))
  end
end

---@param name string
---@param t table
function M.assert.unique(name, t)
  local u = vim.list.unique(vim.deepcopy(t))
  if not vim.deep_equal(t, u) then
    error(("%s no debe tener duplicados"):format(name))
  end
end

return M
