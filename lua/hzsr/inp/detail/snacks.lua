-- hzsr.inp.detail.snacks

local M = {}

-- -----------------------------------------------------------------------------
-- Callback / coroutine safety
--
-- Snacks UI callbacks pueden llegar por varios caminos:
--
--   - el usuario confirma un valor;
--   - el usuario cancela con una tecla que Snacks maneja;
--   - la ventana/buffer flotante desaparece;
--   - el usuario abandona la UI sin confirmar.
--
-- La coroutine que espera la respuesta debe reanudarse exactamente una vez.
-- Reanudarla dos veces rompe el flujo; no reanudarla deja bloqueados reveal,
-- save, close y cualquier operación que dependa del input.
--
-- Estos helpers centralizan ese comportamiento defensivo.

---@generic T
---@param fn fun(value: T?)
---@return fun(value: T?)
function M.once(fn)
  local done = false

  return function(value)
    if done then
      return
    end

    done = true
    fn(value)
  end
end

---@param co thread
---@return fun(value: any)
function M.resume_once(co)
  local resumed = false

  return function(value)
    if resumed then
      return
    end

    resumed = true

    vim.schedule(function()
      if coroutine.status(co) ~= "dead" then
        coroutine.resume(co, value)
      end
    end)
  end
end

-- -----------------------------------------------------------------------------
-- UI discovery
--
-- Snacks no siempre entrega directamente la ventana/buffer de sus UIs.
-- Por eso tomamos una foto de las ventanas antes de abrir la UI y luego buscamos
-- la ventana nueva en el siguiente tick.

---@alias hzsr.inp.detail.snacks.ui_ref { win: integer, buf: integer }

---@return table<integer, true>
function M.snapshot_wins()
  local wins = {}

  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    wins[winid] = true
  end

  return wins
end

---@param before table<integer, true>
---@return hzsr.inp.detail.snacks.ui_ref?
function M.find_new_ui(before)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if not before[winid] and vim.api.nvim_win_is_valid(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)

      if vim.api.nvim_buf_is_valid(bufnr) then
        return {
          win = winid,
          buf = bufnr,
        }
      end
    end
  end

  return nil
end

-- -----------------------------------------------------------------------------
-- Guards
--
-- Cerrar/borrar la UI de Snacks debe comportarse como cancelación.
--
-- Importante:
-- Snacks también cierra su UI al confirmar una respuesta. Por eso las
-- cancelaciones producidas por guards se difieren ligeramente: así damos tiempo
-- al callback real de Snacks a entregar primero el valor válido.
--
-- Si el callback real llega primero, `finish(value)` gana y limpia el grupo.
-- Si no llega nada, el guard asume cancelación/abandono y hace `finish(nil)`.

---@param group integer?
function M.clear_group(group)
  if group then
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end
end

---@param ref hzsr.inp.detail.snacks.ui_ref
local function close_ui(ref)
  if vim.api.nvim_win_is_valid(ref.win) then
    pcall(vim.api.nvim_win_close, ref.win, true)
  end
end

---@param ref hzsr.inp.detail.snacks.ui_ref
---@param finish fun(value: nil)
---@param delay_ms integer
local function cancel_later(ref, finish, delay_ms)
  vim.defer_fn(function()
    close_ui(ref)
    finish(nil)
  end, delay_ms)
end

---@param source string
---@param ref hzsr.inp.detail.snacks.ui_ref
---@param finish fun(value: nil)
---@param opts? { cancel_on_leave?: boolean, cancel_on_normal_mode?: boolean, cancel_delay_ms?: integer, normal_mode_cancel_delay_ms?: integer }
---@return integer group
function M.install_ui_guards(source, ref, finish, opts)
  opts = opts or {}

  local cancel_delay_ms = opts.cancel_delay_ms or 80 

  local group = vim.api.nvim_create_augroup(
    ("hzsr_inp_snacks_%s_guard_%d"):format(source, ref.buf),
    { clear = true }
  )

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete", "WinClosed" }, {
    group = group,
    callback = function(args)
      if args.event == "WinClosed" then
        local closed = tonumber(args.match)

        if closed ~= ref.win then
          return
        end
      elseif tonumber(args.buf) ~= ref.buf then
        return
      end

      cancel_later(ref, finish, cancel_delay_ms)
    end,
  })

  if opts.cancel_on_leave then
    vim.api.nvim_create_autocmd("WinLeave", {
      group = group,
      callback = function(args)
        if tonumber(args.buf) ~= ref.buf then
          return
        end

        cancel_later(ref, finish, cancel_delay_ms)
      end,
    })
  end

  if opts.cancel_on_normal_mode then
    vim.api.nvim_create_autocmd("ModeChanged", {
      group = group,
      callback = function()
        if not vim.api.nvim_win_is_valid(ref.win) then
          return
        end

        if vim.api.nvim_get_mode().mode ~= "n" then
          return
        end

        cancel_later(ref, finish, opts.normal_mode_cancel_delay_ms or cancel_delay_ms)
      end,
    })
  end

  return group
end

return M
