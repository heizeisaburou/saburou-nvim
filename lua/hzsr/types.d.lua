local M = {}

function M.top() end

---@alias hzsr.OverwriteDecision
---| "cancel"
---| "continue"
---| "force"

-- -----------------------------------------------------------------------------
-- buf
-- -----------------------------------------------------------------------------

function M.buf() end

vim.lsp.buf.hover()

---@alias hzsr.buf.filter_str
---| "valid"
---| "normal"
---| "modified"
---| "visible"

---@alias hzsr.buf.filter_fn fun(buf: integer): boolean

---@alias hzsr.buf.filter hzsr.buf.filter_str|hzsr.buf.filter_fn

---@alias hzsr.buf.filters
---| hzsr.buf.filter_str
---| hzsr.buf.filter_fn
---| hzsr.buf.filter_str[]
---| hzsr.buf.filter_fn[]
---| (hzsr.buf.filter_str|hzsr.buf.filter_fn)[]

-- -----------------------------------------------------------------------------

---@class hzsr.buf.close.opts_x
---@field focus? boolean
---@field force? boolean
---@field replace_window? boolean
---@field async? boolean

---@class hzsr.buf.close_multi.opts_x
---@field focus? boolean
---@field force? boolean
---@field replace_windows? boolean
---@field async? boolean

-- -----------------------------------------------------------------------------
-- nvim
-- -----------------------------------------------------------------------------

function M.nvim() end

---@class hzsr.nvim.luarc.opts
---@field nvim_appname? string
---@field library? string[]
---@field globals? string[]

---@class hzsr.nvim.luarc
---@field diagnostics { globals: string[] }
---@field workspace { library: string[] }

-- -----------------------------------------------------------------------------
-- inp
-- -----------------------------------------------------------------------------

function M.inp() end

---@alias hzsr.inp.ask.completion
---| " "
---| "file"
---| "dir"
---| "buffer"
---| "command"
---| "custom"
---| "customlist"

-- -----------------------------------------------------------------------------
-- edt
-- -----------------------------------------------------------------------------

function M.edt() end

---@class hzsr.edt.DeleteLineOpts
---@field copy? boolean
---@field copy_indent? boolean
---@field insert? boolean
---@field keep_indent? boolean
---@field winid? integer
---@field row? integer

---@class hzsr.edt.DeleteWordOpts
---@field copy? boolean
---@field insert? boolean
---@field winid? integer
---@field row? integer
---@field col? integer

---@class hzsr.edt.DeleteToLineEndOpts
---@field copy? boolean
---@field insert? boolean

-- -----------------------------------------------------------------------------
-- ui
-- -----------------------------------------------------------------------------

function M.ui() end

return M
