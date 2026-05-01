-- hzsr.edt.io.close.detail

local M = {}

local IO = require "hzsr.edt.io.detail"

-- -----------------------------------------------------------------------------

---@param bufnr integer?
---@param opts hzsr.edt.io.close.opts?
---@return integer
---@return hzsr.edt.io.close.opts.internal
function M.parse_close_args(bufnr, opts)
  vim.validate("bufnr", bufnr, "number", true)
  vim.validate("opts", opts, "table", true)

  local target = hzsr.buf.resolve(bufnr)

  opts = opts or {}

  vim.validate("opts.modified_policy", opts.modified_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.modified_policy)
  end, "hzsr.edt.io.modified_policy?")

  vim.validate("opts.conflict_policy", opts.conflict_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.conflict_policy)
  end, "hzsr.edt.io.conflict_policy?")

  vim.validate("opts.explicit_cancel", opts.explicit_cancel, "boolean", true)

  vim.validate("opts.path_policy", opts.path_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.path_policy)
  end, "hzsr.edt.io.path_policy?")

  vim.validate("opts.reveal_mode", opts.reveal_mode, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.mode)
  end, "hzsr.edt.reveal.mode?")

  vim.validate("opts.reveal_strategy", opts.reveal_strategy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.strategy)
  end, "hzsr.edt.reveal.strategy?")

  vim.validate("opts.reveal_hl", opts.reveal_hl, "string", true)

  vim.validate("opts.window_policy", opts.window_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.window_policy)
  end, "hzsr.edt.io.window_policy?")

  vim.validate("opts.exit_last", opts.exit_last, "boolean", true)
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.close.opts.internal
  local iopts = vim.tbl_extend("force", {
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = false,
    path_policy = hzsr.edt.io.path_policy.AUTO,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffDelete",
    window_policy = hzsr.edt.io.window_policy.REPLACE,
    exit_last = false,
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.io.close")

  return target, iopts
end

-- -----------------------------------------------------------------------------

-- Retorna el path del buffer resuelto. Si no tiene path, retorna `nil`.
--- @param bufnr integer
--- @return string?
function M.get_buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)

  if name == "" then
    return nil
  end

  return hzsr.sys.path.resolve(name)
end

-- -----------------------------------------------------------------------------

---@param reveal hzsr.edt.reveal.Reveal
---@param bufnr integer
---@param opts hzsr.edt.io.close.modified_opts
---@param allow_all boolean?
---@return hzsr.edt.io.close.modified_decision decision
function M.confirm_modified_close(reveal, bufnr, opts, allow_all)
  local label = hzsr.buf.gen_label(bufnr)
  local prompt = ("¿Guardar cambios antes de cerrar '%s'?"):format(label)

  if not allow_all then
    local answer = reveal:confirm(prompt, {
      default = "yes",
      explicit_cancel = opts.explicit_cancel,
    })

    if answer == "yes" then
      return "save"
    end

    if answer == "no" then
      return "discard"
    end

    return "cancel"
  end

  local items = opts.explicit_cancel and { "Sí", "Sí a todos", "No", "No a todos", "Cancelar" }
    or { "Sí", "Sí a todos", "No", "No a todos" }

  local default = opts.explicit_cancel and 5 or 3
  local choice = reveal:choose(prompt, items, default)

  if choice == 1 then
    return "save"
  end

  if choice == 2 then
    return "save_all"
  end

  if choice == 3 then
    return "discard"
  end

  if choice == 4 then
    return "discard_all"
  end

  return "cancel"
end

-- Determina la acción que hay que llevar a cabo con un buffer que va a ser cerrado.
--
-- 1. Si el buffer no tiene modificaciones entonces retorna `discard`.
-- 2. Sino, entonces se basa en modified_policy
--  - `SAVE`: retorna `save`
--  - `DISCARD`: retorna `discard`
--  - `REJECT`: retorna `reject`
--
-- 3. Sino es `CONFIRM`, por lo tanto, se mostrará el buffer al usuario dependiendo de
-- las opciones, y se pedirá confirmación.
--
--- @param bufnr integer
--- @param opts hzsr.edt.io.close.modified_opts
--- @param allow_all boolean?
--- @return hzsr.edt.io.close.modified_decision decision
function M.resolve_modified_decision(bufnr, opts, allow_all)
  if not vim.bo[bufnr].modified then
    return "discard"
  end

  if opts.modified_policy == hzsr.edt.io.modified_policy.SAVE then
    return "save"
  end

  if opts.modified_policy == hzsr.edt.io.modified_policy.DISCARD then
    return "discard"
  end

  if opts.modified_policy == hzsr.edt.io.modified_policy.REQUIRE then
    return "reject"
  end

  ---@type hzsr.edt.reveal.Reveal
  local reveal = IO.new_reveal(bufnr, opts)

  return IO.with_reveal(reveal, function()
    return M.confirm_modified_close(reveal, bufnr, opts, allow_all)
  end)
end

-- -----------------------------------------------------------------------------

-- Invoca a save con las mismas opciones que acepta close.
--- @param bufnr integer
--- @param opts hzsr.edt.io.close.opts.internal
--- @return hzsr.edt.io.save.out?
function M.save_before_close(bufnr, opts)
  local Save = require "hzsr.edt.io.save"

  return Save.save(bufnr, {
    path_policy = opts.path_policy,
    conflict_policy = opts.conflict_policy,
    explicit_cancel = opts.explicit_cancel,
    reveal_mode = opts.reveal_mode,
    reveal_strategy = opts.reveal_strategy,
    reveal_hl = opts.reveal_hl,
    async = opts.async,
  })
end

-- Retorna nil si el guardado fue exitoso, sino, invoca a make_out para generar una
-- salida de error.
--- @param bufnr integer
--- @param save_out hzsr.edt.io.save.out?
--- @return hzsr.edt.io.close.out?
function M.make_close_out_from_save_failure(bufnr, save_out)
  -- nil check
  assert(save_out, "save_out no debería ser nil")

  if save_out.status == hzsr.edt.io.status.SUCCESS then
    return nil
  end

  return IO.make_out(save_out.status, bufnr, save_out.path, "cierre interrumpido por guardado no exitoso", {
    save_status = save_out.status,
    write_status = save_out.write_status,
    existing_buf = save_out.existing_buf,
  })
end

-- -----------------------------------------------------------------------------

-- Cierra una ventana respetando que Neovim no permite cerrar la última.
-- Si la ventana es inválida o ya es la única, retorna `ok = true` sin hacer nada.
--- @param winid integer
--- @return boolean ok
--- @return string? err
function M.close_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return true, nil
  end

  if #vim.api.nvim_list_wins() <= 1 then
    return true, nil
  end

  local ok, err = pcall(vim.api.nvim_win_close, winid, true)

  if not ok then
    return false, tostring(err)
  end

  return true, nil
end

-- Cierra todas las ventanas que contienen el buffer indicado; si alguna es la última
-- ventana restante, la deja viva porque Neovim no permite cerrarla y permite que el
-- cierre continúe con `bwipeout`.
--- @param bufnr integer Buffer cuyas ventanas contenedoras se van a cerrar.
--- @return boolean ok `true` si las ventanas se cerraron correctamente o si no había nada que cerrar.
--- @return string? err Mensaje de error si alguna ventana no pudo cerrarse.
function M.close_containing_windows(bufnr)
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    local ok, err = M.close_window(winid)

    if not ok then
      return false, err
    end
  end

  return true, nil
end

-- Reemplaza el buffer indicado en todas las ventanas que lo contienen por un buffer
-- de reemplazo válido; si no hay reemplazo válido, no hace nada.
--- @param bufnr integer
--- @return boolean ok
--- @return string? err
function M.replace_containing_windows(bufnr)
  local replacement = hzsr.buf.get_replacement(bufnr)

  if not replacement or not hzsr.buf.is_valid(replacement) then
    return true, nil
  end

  hzsr.buf.replace_containing_windows(bufnr, replacement)

  return true, nil
end

-- Aplica la política de ventanas antes de cerrar un buffer normal, dejando las
-- ventanas intactas, cerrándolas o reemplazando el buffer mostrado según
-- `opts.window_policy`.
--
--- @param bufnr integer
--- @param was_normal boolean
--- @param opts hzsr.edt.io.close.opts.internal
--- @return boolean ok
--- @return string? err
function M.handle_normal_windows(bufnr, was_normal, opts)
  if not was_normal then
    return true, nil
  end

  if opts.window_policy == hzsr.edt.io.window_policy.DEFAULT then
    return true, nil
  end

  if opts.window_policy == hzsr.edt.io.window_policy.CLOSE then
    return M.close_containing_windows(bufnr)
  end

  return M.replace_containing_windows(bufnr)
end

-- -----------------------------------------------------------------------------

-- Elimina definitivamente un buffer con `bwipeout`, gestionando antes sus ventanas
-- contenedoras según la política configurada y usando `bwipeout!` cuando `force`
-- es verdadero.
--- @param bufnr integer
--- @param force boolean
--- @param was_normal boolean
--- @param opts hzsr.edt.io.close.opts.internal
--- @return boolean ok
--- @return string? err
function M.delete_buffer(bufnr, force, was_normal, opts)
  local ok, err = pcall(function()
    local ok_windows, windows_err = M.handle_normal_windows(bufnr, was_normal, opts)

    if not ok_windows then
      error(windows_err)
    end

    if hzsr.buf.is_valid(bufnr) then
      vim.cmd(("bwipeout%s %d"):format(force and "!" or "", bufnr))
    end
  end)

  if not ok then
    return false, tostring(err)
  end

  return true, nil
end

-- -----------------------------------------------------------------------------

---@param current integer
---@return boolean
function M.would_leave_no_meaningful_normal(current)
  for _, bufnr in ipairs(hzsr.buf.get_all "normal") do
    if bufnr ~= current and hzsr.buf.is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)

      if name ~= "" then
        vim.notify(('Cannot quit: normal buffer "%s" is still open'):format(name), vim.log.levels.ERROR)
        return false
      end

      if vim.bo[bufnr].modified then
        vim.notify(("Cannot quit: buffer %d has unsaved changes"):format(bufnr), vim.log.levels.ERROR)
        return false
      end

      local line_count = vim.api.nvim_buf_line_count(bufnr)
      if line_count > 1 then
        vim.notify(("Cannot quit: unnamed buffer %d still has content"):format(bufnr), vim.log.levels.ERROR)
        return false
      end

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
      if (lines[1] or "") ~= "" then
        vim.notify(("Cannot quit: unnamed buffer %d still has content"):format(bufnr), vim.log.levels.ERROR)
        return false
      end
    end
  end

  return true
end

-- -----------------------------------------------------------------------------

---@param buffers integer[]
---@param index integer
---@return boolean
function M.has_later_modified_buffer(buffers, index)
  for i = index + 1, #buffers do
    local bufnr = buffers[i]

    if hzsr.buf.is_valid(bufnr) and vim.bo[bufnr].modified then
      return true
    end
  end

  return false
end

-- -----------------------------------------------------------------------------

return M
