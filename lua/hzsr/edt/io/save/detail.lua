-- hzsr.edt.io.save.detail

local M = {}

---@enum hzsr.edt.io.save.path_kind
M.PATH_KIND = {
  ASK = "ask",
  PATH = "path",
  MISSING = "missing",
}

-- -----------------------------------------------------------------------------

---@param bufnr integer?
---@param opts hzsr.edt.io.save.opts?
---@return integer
---@return hzsr.edt.io.save.opts.internal
function M.parse_save_args(bufnr, opts)
  vim.validate("bufnr", bufnr, "number", true)
  vim.validate("opts", opts, "table", true)

  local target = hzsr.buf.resolve(bufnr)

  opts = opts or {}

  vim.validate("opts.path", opts.path, "string", true)

  vim.validate("opts.path_policy", opts.path_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.path_policy)
  end, [["auto"|"ask"|"require"?]])

  vim.validate("opts.conflict_policy", opts.conflict_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.conflict_policy)
  end, [["confirm"|"force"|"require"?]])

  vim.validate("opts.explicit_cancel", opts.explicit_cancel, "boolean", true)

  vim.validate("opts.reveal_mode", opts.reveal_mode, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.mode)
  end, "hzsr.edt.reveal.mode?")

  vim.validate("opts.reveal_strategy", opts.reveal_strategy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.strategy)
  end, "hzsr.edt.reveal.strategy?")

  vim.validate("opts.reveal_hl", opts.reveal_hl, "string", true)
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.save.opts.internal
  local iopts = vim.tbl_extend("force", {
    path_policy = hzsr.edt.io.path_policy.AUTO,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = false,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffAdd",
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.io.save")
  iopts.path = iopts.path ~= "" and iopts.path or nil

  return target, iopts
end

-- -----------------------------------------------------------------------------

---@param opts hzsr.edt.io.save.opts.internal
---@return string?
function M.get_explicit_path(opts)
  if not opts.path then
    return nil
  end

  return hzsr.sys.path.resolve(opts.path)
end

---@param bufnr integer
---@return string?
function M.get_buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)

  if name == "" then
    return nil
  end

  return hzsr.sys.path.resolve(name)
end

-- -----------------------------------------------------------------------------

---@param bufnr integer
---@param opts hzsr.edt.io.save.opts.internal
---@return hzsr.edt.io.save.path_kind path_kind
---@return string? path
function M.resolve_save_path(bufnr, opts)
  local policy = opts.path_policy
  local explicit_path = M.get_explicit_path(opts)

  if policy == hzsr.edt.io.path_policy.REQUIRE then
    if not explicit_path then
      return M.PATH_KIND.MISSING, nil
    end

    return M.PATH_KIND.PATH, explicit_path
  end

  if policy == hzsr.edt.io.path_policy.ASK then
    return M.PATH_KIND.ASK, nil
  end

  if explicit_path then
    return M.PATH_KIND.PATH, explicit_path
  end

  local buffer_path = M.get_buffer_path(bufnr)
  if buffer_path then
    return M.PATH_KIND.PATH, buffer_path
  end

  return M.PATH_KIND.ASK, nil
end

-- -----------------------------------------------------------------------------

---@param bufnr integer
---@param opts hzsr.edt.io.save.opts.internal
---@return string
function M.get_save_path_hint(bufnr, opts)
  local explicit_path = M.get_explicit_path(opts)
  if explicit_path then
    return explicit_path
  end

  local buffer_path = M.get_buffer_path(bufnr)
  if buffer_path then
    return buffer_path
  end

  return vim.fn.getcwd() .. hzsr.sys.os_sep
end

---@param reveal hzsr.edt.reveal.Reveal
---@param bufnr integer
---@param opts hzsr.edt.io.save.opts.internal
---@return string?
function M.ask_save_path(reveal, bufnr, opts)
  local hint = M.get_save_path_hint(bufnr, opts)
  local answer = reveal:ask("Save to:", hint, "file")

  if not answer or answer == "" then
    return nil
  end

  return hzsr.sys.path.resolve(answer)
end

-- -----------------------------------------------------------------------------

---@param opts hzsr.edt.io.save.opts.internal
---@return hzsr.buf.write_to.opts
function M.get_write_opts(opts)
  return {
    force = false,
    force_overwrite = opts.conflict_policy == hzsr.edt.io.conflict_policy.FORCE,
  }
end

---@param reveal hzsr.edt.reveal.Reveal
---@param prompt string
---@param msg? string
---@param opts hzsr.edt.io.save.confirm_overwrite_opts
---@return hzsr.inp.pick.confirm.result
function M.confirm_overwrite(reveal, prompt, msg, opts)
  if msg and msg ~= "" then
    vim.notify(msg, vim.log.levels.WARN)
  end

  return reveal:confirm(prompt, {
    default = opts.explicit_cancel and "cancel" or "no",
    explicit_cancel = opts.explicit_cancel,
  })
end

---@param reveal hzsr.edt.reveal.Reveal
---@param write_out hzsr.buf.write_to.result_x
---@param opts hzsr.edt.io.save.opts.internal
---@return hzsr.edt.io.save.write_decision decision
function M.resolve_overwrite_decision(reveal, write_out, opts)
  if opts.conflict_policy == hzsr.edt.io.conflict_policy.FORCE then
    return "ok"
  end

  if opts.conflict_policy == hzsr.edt.io.conflict_policy.REQUIRE then
    return "reject"
  end

  local prompt

  if write_out.status == hzsr.buf.write.status.EXISTING_BUF then
    prompt = ("¿Sobrescribir buffer existente '%s'?"):format(write_out.path)
  else
    prompt = ("¿Sobrescribir '%s'?"):format(write_out.path)
  end

  local answer = M.confirm_overwrite(reveal, prompt, write_out.msg, {
    explicit_cancel = opts.explicit_cancel,
  })

  if answer == "yes" then
    return "ok"
  end

  if answer == "cancel" then
    return "cancel"
  end

  return "reject"
end

---@param bufnr integer
---@param write_out hzsr.buf.write_to.result_x
---@return hzsr.buf.write_to.result_x
function M.overwrite_existing_buf(bufnr, write_out)
  local existing_buf = write_out.existing_buf

  if not existing_buf or not hzsr.buf.is_valid(existing_buf) then
    return write_out
  end

  hzsr.buf.merge_into_existing(bufnr, existing_buf, {
    replace_windows = true,
  })

  local out = hzsr.buf.write.write(existing_buf, {
    force = false,
    force_overwrite = true,
  })

  if out.status ~= hzsr.buf.write.status.SUCCESS then
    return {
      status = out.status,
      path = write_out.path,
      existing_buf = existing_buf,
      msg = out.msg,
    }
  end

  return {
    status = hzsr.buf.write.status.SUCCESS,
    path = write_out.path,
    existing_buf = existing_buf,
  }
end

---@param reveal hzsr.edt.reveal.Reveal
---@param bufnr integer
---@param path string
---@param opts hzsr.edt.io.save.opts.internal
---@return hzsr.buf.write_to.result_x
---@return hzsr.edt.io.save.write_decision decision
function M.write_to_save_path(reveal, bufnr, path, opts)
  local write_out = hzsr.buf.write.write_to(bufnr, path, M.get_write_opts(opts))

  if write_out.status == hzsr.buf.write.status.SUCCESS then
    return write_out, "ok"
  end

  if
    write_out.status ~= hzsr.buf.write.status.REQUIRE_OVERWRITE
    and write_out.status ~= hzsr.buf.write.status.EXISTING_BUF
  then
    return write_out, "ok"
  end

  local decision = M.resolve_overwrite_decision(reveal, write_out, opts)

  if decision ~= "ok" then
    return write_out, decision
  end

  if write_out.status == hzsr.buf.write.status.EXISTING_BUF then
    return M.overwrite_existing_buf(bufnr, write_out), "ok"
  end

  write_out = hzsr.buf.write.write_to(bufnr, path, {
    force = false,
    force_overwrite = true,
  })

  return write_out, "ok"
end

-- -----------------------------------------------------------------------------

return M
