-- hzsr.edt.reveal.simple.Reveal

-- `simple.Reveal` usa un best effort:
--   - ventana actual si ya muestra el buffer;
--   - si no, ventana visible más grande que muestre el buffer, buscando en
--     todas las tabs;
--   - si empatan, ventana visible con menor winid;
--   - si no hay ninguna ventana visible y mode ~= NONE, crea una tab temporal.
--
-- Limitación:
--   - No implementa una UI propia de prompts; delega en los adaptadores de input.
--   - En caso de existir MRU de ventanas, preferirlo sobre largest_win. :TODO: implementar MRU de ventanas

---@class hzsr.edt.reveal.simple.Reveal.opts : hzsr.edt.reveal.Reveal.opts

---@class hzsr.edt.reveal.simple.Reveal.opts.internal
---@field mode hzsr.edt.reveal.mode
---@field hl? string
---@field async boolean

---@class hzsr.edt.reveal.simple.Reveal : hzsr.edt.reveal.Reveal
---@field _bufnr integer
---@field _winid integer?
---@field _original_winid integer?
---@field _created_winid integer?
---@field _created_tabpage integer?
---@field _marker hzsr.edt.reveal.simple.Marker?
---@field _mode hzsr.edt.reveal.mode
---@field _hl? string
---@field _async boolean
local Reveal = {}

Reveal.__index = Reveal

---@param bufnr integer?
---@param opts hzsr.edt.reveal.simple.Reveal.opts?
---@return integer
---@return hzsr.edt.reveal.simple.Reveal.opts.internal
local function parse_args(bufnr, opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  vim.validate("opts.mode", opts.mode, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.mode)
  end, "hzsr.edt.reveal.mode?")

  vim.validate("opts.hl", opts.hl, "string", true)

  vim.validate("opts.async", opts.async, "boolean", true)

  local iopts = vim.tbl_extend("force", {
    mode = hzsr.edt.reveal.mode.RESTORE,
    async = opts.async,
    hl = opts.hl,
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.reveal.simple.Reveal")

  return hzsr.buf.resolve(bufnr), iopts
end

---@param bufnr? integer
---@param opts? hzsr.edt.reveal.simple.Reveal.opts
---@return hzsr.edt.reveal.simple.Reveal
function Reveal.new(bufnr, opts)
  local b, o = parse_args(bufnr, opts)

  ---@type hzsr.edt.reveal.simple.Reveal
  local self = setmetatable({
    _bufnr = b,
    _winid = nil,
    _original_winid = nil,
    _created_winid = nil,
    _created_tabpage = nil,
    _marker = nil,
    _mode = o.mode,
    _hl = o.hl,
    _async = o.async,
  }, Reveal)

  return self
end

---@return hzsr.edt.reveal.mode
function Reveal:get_mode()
  return self._mode
end

---@return integer
function Reveal:get_buf()
  return self._bufnr
end

---@return integer?
function Reveal:get_win()
  return self._winid
end

---@return boolean ok
function Reveal:activate()
  if self:get_mode() == hzsr.edt.reveal.mode.NONE then
    return true
  end

  if not self:is_valid() then
    return false
  end

  self:_clear_dead_state()

  if self:is_active() then
    return self:_focus()
  end

  local winid = self:_select_win()

  if not winid then
    return false
  end

  self._original_winid = vim.api.nvim_get_current_win()
  self._winid = winid

  if not self:_focus() then
    self._winid = nil
    return false
  end

  local Marker = hzsr.edt.reveal.simple.Marker
  self._marker = Marker.new(winid, {
    hl = self._hl,
  })
  self._marker:activate()

  return self:is_active()
end

---@return boolean ok
function Reveal:deactivate()
  local ok = true

  if self._marker then
    ok = self._marker:deactivate() and ok
    self._marker = nil
  end

  if self:get_mode() == hzsr.edt.reveal.mode.RESTORE then
    if self._created_winid and hzsr.win.is_valid(self._created_winid) then
      local close_ok = pcall(function()
        vim.api.nvim_set_current_win(self._created_winid)
        vim.cmd "tabclose!"
      end)

      ok = close_ok and ok
    end

    if self._original_winid and hzsr.win.is_valid(self._original_winid) then
      local restore_ok = pcall(vim.api.nvim_set_current_win, self._original_winid)
      ok = restore_ok and ok
    end
  end

  self._winid = nil
  self._original_winid = nil
  self._created_winid = nil
  self._created_tabpage = nil

  return ok
end

---@return boolean active
function Reveal:is_active()
  self:_clear_dead_state()

  return self._marker ~= nil and self._marker:is_active()
end

---@return boolean valid
function Reveal:is_valid()
  local bufnr = self:get_buf()

  return bufnr ~= nil and hzsr.buf.is_valid(bufnr)
end

---@param prompt string
---@param default? string
---@param completion? string
---@return string?
function Reveal:ask(prompt, default, completion)
  vim.validate("prompt", prompt, "string")
  vim.validate("default", default, "string", true)
  vim.validate("completion", completion, "string", true)

  if not self:_prepare_prompt() then
    return nil
  end

  vim.cmd "redraw"

  return hzsr.inp.ask.adapter(prompt, default, completion, self._async)
end

---@param prompt string
---@param items string[]
---@param default? integer
---@return integer?
function Reveal:choose(prompt, items, default)
  vim.validate("prompt", prompt, "string")
  vim.validate("items", items, "table")
  vim.validate("default", default, "number", true)

  if not self:_prepare_prompt() then
    return nil
  end

  vim.cmd "redraw"

  return hzsr.inp.pick.choose.adapter(prompt, items, default, self._async)
end

---@param prompt string
---@param opts? hzsr.edt.reveal.Reveal.confirm_opts
---@return hzsr.inp.pick.confirm.result
function Reveal:confirm(prompt, opts)
  vim.validate("prompt", prompt, "string")
  vim.validate("opts", opts, "table", true)

  if not self:_prepare_prompt() then
    return "cancel"
  end

  vim.cmd "redraw"

  opts = opts or {}

  return hzsr.inp.pick.confirm(prompt, {
    default = opts.default,
    explicit_cancel = opts.explicit_cancel,
    async = self._async,
  })
end

---@private
---@return boolean ok
function Reveal:_prepare_prompt()
  if self:get_mode() == hzsr.edt.reveal.mode.NONE then
    return self:is_valid()
  end

  self:_clear_dead_state()

  if not self:is_active() then
    return self:activate()
  end

  return self:_focus()
end

---@private
function Reveal:_clear_dead_state()
  if self._marker and not self._marker:is_valid() then
    self._marker = nil
  end

  if self._winid and not hzsr.win.is_valid(self._winid) then
    self._winid = nil
  end
end

---@private
---@return integer?
function Reveal:_select_win()
  local current_winid = vim.api.nvim_get_current_win()
  local bufnr = self:get_buf()

  if hzsr.win.is_valid(current_winid) and vim.api.nvim_win_get_buf(current_winid) == bufnr then
    return current_winid
  end

  return self:_find_largest_win() or self:_create_win()
end

---@private
---@return integer[]
function Reveal:_list_wins()
  local wins = {}

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      wins[#wins + 1] = winid
    end
  end

  return wins
end

---@private
---@return integer?
function Reveal:_find_largest_win()
  local bufnr = self:get_buf()
  local best_winid = nil
  local best_area = -1

  for _, winid in ipairs(self:_list_wins()) do
    if hzsr.win.is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      local width = vim.api.nvim_win_get_width(winid)
      local height = vim.api.nvim_win_get_height(winid)
      local area = width * height

      if area > best_area or (area == best_area and (best_winid == nil or winid < best_winid)) then
        best_winid = winid
        best_area = area
      end
    end
  end

  return best_winid
end

---@private
---@return integer?
function Reveal:_find_lowest_winid()
  local bufnr = self:get_buf()
  local best_winid = nil

  for _, winid in ipairs(self:_list_wins()) do
    if hzsr.win.is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      if best_winid == nil or winid < best_winid then
        best_winid = winid
      end
    end
  end

  return best_winid
end

---@private
---@return integer?
function Reveal:_create_win()
  local bufnr = self:get_buf()

  if not bufnr or not hzsr.buf.is_valid(bufnr) then
    return nil
  end

  local ok, winid = pcall(function()
    vim.cmd "tabnew"

    local created_winid = vim.api.nvim_get_current_win()
    local scratch_bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_win_set_buf(created_winid, bufnr)

    if
      vim.api.nvim_buf_is_valid(scratch_bufnr)
      and vim.api.nvim_buf_get_name(scratch_bufnr) == ""
      and not vim.bo[scratch_bufnr].modified
    then
      pcall(vim.api.nvim_buf_delete, scratch_bufnr, {
        force = true,
        unload = false,
      })
    end

    self._created_winid = created_winid
    self._created_tabpage = vim.api.nvim_get_current_tabpage()

    return created_winid
  end)

  if not ok then
    return nil
  end

  return winid
end

---@private
---@return boolean ok
function Reveal:_focus()
  local winid = self:get_win()

  if not winid or not hzsr.win.is_valid(winid) then
    return false
  end

  return pcall(vim.api.nvim_set_current_win, winid)
end

return Reveal
