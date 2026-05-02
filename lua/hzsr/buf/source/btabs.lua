-- hzsr.buf.source.btabs

local M = {}

---@return integer[]
function M.bufferline()
  local elements = require("bufferline").get_elements().elements

  return vim
    .iter(elements)
    :map(function(e)
      return e.id
    end)
    :totable()
end

---@return integer[]
function M.adapter()
  local ok, bufferline = pcall(require, "bufferline")
  if ok and bufferline then
    return M.bufferline()
  end

  return {}
end

return M
