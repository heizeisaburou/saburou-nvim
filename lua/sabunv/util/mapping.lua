-- sabunv.util.mapping

local M = {}

---@class sabunv.util.mapping.opts
---@field noremap? boolean
---@field silent? boolean
---@field prefix? string

---@alias sabunv.util.mapping.gen fun(desc?: string, opts?: sabunv.util.mapping.opts): table

---@param desc? string
---@param opts? sabunv.util.mapping.opts
---@return table
local function base(desc, opts)
  opts = opts or {}

  local out = {
    noremap = opts.noremap,
    silent = opts.silent,
  }

  if desc and desc ~= "" then
    if opts.prefix and opts.prefix ~= "" then
      out.desc = opts.prefix .. " " .. desc
    else
      out.desc = desc
    end
  end

  return out
end

---@param defaults? sabunv.util.mapping.opts
---@param opts? sabunv.util.mapping.opts
---@return sabunv.util.mapping.opts
local function merge_opts(defaults, opts)
  return vim.tbl_extend("force", defaults or {}, opts or {})
end

---@param desc? string
---@param opts? sabunv.util.mapping.opts
---@return table
function M.gen(desc, opts)
  return base(desc, opts)
end

---@param bufnr integer
---@param desc? string
---@param opts? sabunv.util.mapping.opts
---@return table
function M.bgen(bufnr, desc, opts)
  local out = base(desc, opts)
  out.buffer = bufnr
  return out
end

---@param defaults? sabunv.util.mapping.opts
---@return sabunv.util.mapping.gen
function M.with(defaults)
  return function(desc, opts)
    return M.gen(desc, merge_opts(defaults, opts))
  end
end

---@param bufnr integer
---@param defaults? sabunv.util.mapping.opts
---@return sabunv.util.mapping.gen
function M.bwith(bufnr, defaults)
  return function(desc, opts)
    return M.bgen(bufnr, desc, merge_opts(defaults, opts))
  end
end

M.lsp = {}

---@type sabunv.util.mapping.opts
M.lsp.defaults = {
  prefix = "LSP",
}

---@param bufnr integer
---@return sabunv.util.mapping.gen
function M.lsp.bwith(bufnr)
  return M.bwith(bufnr, M.lsp.defaults)
end

return M
