-- hzsr.edt.io.detail

local M = {}

-- -----------------------------------------------------------------------------

---Crea un reveal usando las opts editoriales comunes.
---
---@param bufnr integer
---@param opts hzsr.edt.io.reveal_opts
---@return hzsr.edt.reveal.Reveal
function M.new_reveal(bufnr, opts)
  return hzsr.edt.reveal.new(bufnr, {
    mode = opts.reveal_mode,
    strategy = opts.reveal_strategy,
    hl = opts.reveal_hl,
    async = opts.async,
  })
end

-- -----------------------------------------------------------------------------

---@generic T
---@param reveal hzsr.edt.reveal.Reveal
---@param fn fun(): T
---@return T
function M.with_reveal(reveal, fn)
  local ok, result = pcall(fn)

  local ok_deactivate, deactivate_err = pcall(function()
    return reveal:deactivate()
  end)

  if not ok_deactivate then
    vim.notify(tostring(deactivate_err), vim.log.levels.ERROR)
  end

  if not ok then
    error(result)
  end

  return result
end

-- -----------------------------------------------------------------------------

---Construye un resultado común de operación editorial sobre buffer.
---
---@param status hzsr.edt.io.status
---@param bufnr integer
---@param path? string
---@param msg? string
---@param extra? table
---@return table
function M.make_out(status, bufnr, path, msg, extra)
  local out = {
    status = status,
    bufnr = bufnr,
    path = path,
    msg = msg,
  }

  if extra then
    for k, v in pairs(extra) do
      out[k] = v
    end
  end

  return out
end

-- -----------------------------------------------------------------------------

---Resuelve buffers para operaciones batch.
---
---Reglas:
---  - Si `bufnrs == nil`, usa `hzsr.buf.get_all(fallback_filter, fallback_union)`.
---    Esto conserva el orden global de `hzsr.buf`: tabs, MRU y base nvim.
---  - Si `bufnrs` viene explícito, respeta ese orden, resolviendo y quitando
---    duplicados.
---
---@param bufnrs integer[]?
---@param fallback_filter? hzsr.buf.filter_str|hzsr.buf.filter_fn|hzsr.buf.filter_str[]|hzsr.buf.filter_fn[]
---@param fallback_union? "and"|"or"
---@return integer[]
function M.resolve_buffers(bufnrs, fallback_filter, fallback_union)
  vim.validate("bufnrs", bufnrs, "table", true)

  if bufnrs == nil then
    return hzsr.buf.get_all(fallback_filter, fallback_union)
  end

  local wanted = {}

  for index, bufnr in ipairs(bufnrs) do
    vim.validate(("bufnrs[%d]"):format(index), bufnr, "number")
    wanted[hzsr.buf.resolve(bufnr)] = true
  end

  local ordered = {}

  for _, bufnr in ipairs(hzsr.buf.get_all()) do
    if wanted[bufnr] then
      ordered[#ordered + 1] = bufnr
      wanted[bufnr] = nil
    end
  end

  -- Fallback por si algún buffer válido no aparece en hzsr.buf.get_all().
  for bufnr in pairs(wanted) do
    ordered[#ordered + 1] = bufnr
  end

  return ordered
end

-- -----------------------------------------------------------------------------

---@return hzsr.edt.io.batch_report
function M.new_batch_report()
  return {
    ok = true,
    tried = {},
    success = {},
    rejected = {},
    cancelled = nil,
    errored = {},
    results = {},
  }
end

---@param report hzsr.edt.io.batch_report
---@param index integer
---@param out table
function M.add_batch_result(report, index, out)
  report.results[out.bufnr] = out

  if out.status == hzsr.edt.io.status.SUCCESS then
    table.insert(report.success, out.bufnr)
    return
  end

  report.ok = false

  if out.status == hzsr.edt.io.status.REJECT then
    table.insert(report.rejected, out.bufnr)
    return
  end

  if out.status == hzsr.edt.io.status.CANCEL then
    report.cancelled = index
    return
  end

  table.insert(report.errored, out.bufnr)
end

---@param status hzsr.edt.io.status
---@param bufnrs integer[]
---@param make_out fun(bufnr: integer): table
---@return hzsr.edt.io.batch_report
function M.make_batch_unrun_report(status, bufnrs, make_out)
  local report = M.new_batch_report()
  report.ok = false
  report.tried = vim.deepcopy(bufnrs)

  if status == hzsr.edt.io.status.CANCEL and #bufnrs > 0 then
    report.cancelled = 1
  end

  for _, bufnr in ipairs(bufnrs) do
    report.results[bufnr] = make_out(bufnr)

    if status == hzsr.edt.io.status.REJECT then
      table.insert(report.rejected, bufnr)
    elseif status ~= hzsr.edt.io.status.CANCEL then
      table.insert(report.errored, bufnr)
    end
  end

  return report
end

-- -----------------------------------------------------------------------------

return M
