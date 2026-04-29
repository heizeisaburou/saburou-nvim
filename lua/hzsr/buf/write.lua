-- hzsr.buf.write

local M = {}

--- @enum hzsr.buf.write.status
M.status = {
  SUCCESS = "success",
  UNNAMED = "unnamed",
  INVALID_PATH = "invalid_path",
  EXISTING_BUF = "existing_buf",
  IS_DIRECTORY = "is_directory",
  REQUIRE_OVERWRITE = "require_overwrite",
  UNKNOWN_ERROR = "unknown_error",
}

-- Restaura el nombre original del buffer tras un rename fallido + write fallido.
-- Si el buffer originalmente no tenía nombre, intentamos dejarlo sin nombre otra vez.
--
--- @param bufnr integer
--- @param original_name string
--- @return boolean ok
--- @return any err
local function restore_buffer_name(bufnr, original_name)
  local ok, err = pcall(function()
    if not original_name or original_name == "" then
      vim.api.nvim_buf_set_name(bufnr, "")
    else
      if not hzsr.buf.rename_to_path(bufnr, original_name) then
        error "failed to restore original buffer name"
      end
    end
  end)

  return ok, err
end

---@param path string
---@param target integer
local function cleanup_stale_path_buffer(path, target)
  local buf = vim.fn.bufnr(path)

  if buf == -1 or buf == target then
    return
  end

  local loaded = vim.api.nvim_buf_is_loaded(buf)
  local modified = loaded and vim.bo[buf].modified

  if modified then
    return
  end

  pcall(vim.api.nvim_buf_delete, buf, {
    force = true,
    unload = false,
  })
end

local function classify_write_error(msg)
  local code = hzsr.nvim.error.filter_code(msg)

  if code == "E13" then
    return M.status.REQUIRE_OVERWRITE
  elseif code == "E17" then
    return M.status.IS_DIRECTORY
  end

  return M.status.UNKNOWN_ERROR
end

---@class hzsr.buf.do_write.result
---@field status hzsr.buf.write.status
---@field msg? string

--- @param bufnr? integer
--- @param force? boolean
--- @return hzsr.buf.do_write.result result
local function do_write(bufnr, force)
  local target = bufnr or vim.api.nvim_get_current_buf()

  local old_confirm = vim.o.confirm
  vim.o.confirm = false

  local ok, err = pcall(vim.api.nvim_buf_call, target, function()
    vim.cmd(force and "write!" or "write")
  end)

  vim.o.confirm = old_confirm

  if not ok then
    local status = classify_write_error(err)
    local name = vim.api.nvim_buf_get_name(target)
    if status == M.status.REQUIRE_OVERWRITE then
      return {
        status = status,
        msg = ("'%s' existe y requiere overwrite"):format(name),
      }
    elseif status == M.status.IS_DIRECTORY then
      return { status = status, msg = ("'%s' es un directorio"):format(name) }
    end

    return {
      status = status,
      msg = ("error desconocido al escribir '%s': %s"):format(name, tostring(err)),
    }
  end

  return { status = M.status.SUCCESS }
end

---@class hzsr.buf.write.opts
---@field force_overwrite? boolean `true` para forzar la sobreescritura. En caso de false, la sobreescritura fallará.
---@field force? boolean `true` para forzar la escritura (`:write!`). Sino, se usa escritura normal (`:write`).

---@class hzsr.buf.write.result_x
---@field status hzsr.buf.write.status
---@field msg? string

--- @param bufnr? integer Buffer objetivo. Si es `nil`, se utiliza el buffer actual.
--- @param opts? hzsr.buf.write.opts
--- @return hzsr.buf.write.result_x result
function M.write(bufnr, opts)
  vim.validate("bufnr", bufnr, "number", true)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  local target = hzsr.buf.resolve(bufnr)
  local name = vim.api.nvim_buf_get_name(target)

  if name == "" then
    return { status = M.status.UNNAMED, msg = "el buffer no tiene nombre" }
  end

  local out = do_write(target, opts.force)

  if out.status ~= M.status.SUCCESS then
    -- Si escribir requiere overwrite, entonces manejamos nosotros force con 'write!' ya que:
    --   - Aunque ! agrupe más cosas, hemos identificado bien el caso y debería de funcionar bien siempre.
    --   - Si alguien debe asumir esta responsabilidad, entonces ese alguien es esta función.
    --
    if (out.status == M.status.REQUIRE_OVERWRITE) and opts.force_overwrite and not opts.force then
      out = do_write(target, true)
    end

    return { status = out.status, msg = out.msg }
  end

  return { status = M.status.SUCCESS }
end

-- -----------------------------------------------------------------------------

---@class hzsr.buf.write_to.opts
---@field force_overwrite? boolean `true` para forzar la sobreescritura. En caso de false, la sobreescritura fallará.
---@field force? boolean `true` para forzar la escritura (`:write!`). Sino, se usa escritura normal (`:write`).

---@class hzsr.buf.write_to.result_x
---@field status hzsr.buf.write.status
---@field path string
---@field existing_buf? integer
---@field msg? string

-- Escribe un buffer en `path`.
--
-- Contrato del resultado:
--   - Siempre devuelve `result.path`.
--   - Si `status == SUCCESS`, `result.path` es el path resuelto usado para escribir.
--   - Si `status == INVALID_PATH`, `result.path` es `""`.
--   - No resuelve symlinks; solo normaliza a path absoluto.
--
-- Excepciones:
--   - `hzsr.buf.write:RENAME_TO_PATH_FAILED` - fallo al renombrar el buffer
--     - data = { bufnr, original_name, path }
--   - `hzsr.buf.write:RESTORE_NAME_FAILED` - fallo al tratar de restaurar el buffer renombrado.
--     - data = { bufnr, original_name, path, write_msg, restore_err }
--
--- @param bufnr? integer Buffer objetivo. Si es `nil`, se utiliza el buffer actual.
--- @param path string Ruta de destino.
--- @param opts? hzsr.buf.write_to.opts
--- @return hzsr.buf.write_to.result_x
function M.write_to(bufnr, path, opts)
  vim.validate("bufnr", bufnr, "number", true)
  vim.validate("path", path, "string", false)
  vim.validate("opts", opts, "table", true)

  local target = hzsr.buf.resolve(bufnr)
  opts = opts or {}

  if path == "" then
    return { status = M.status.INVALID_PATH, msg = "debes indicar un path", path = "" }
  end

  local resolved_path = hzsr.sys.path.resolve(path)

  if resolved_path == "" then
    return {
      status = M.status.INVALID_PATH,
      msg = ("'%s' es un path inválido"):format(path),
      path = "",
    }
  end

  -- Si ya existe otro buffer asociado a esta ruta, abortamos incluso con force_overwrite.
  -- El problema aquí no es sólo de sobreescritura de archivo: resolver este caso correctamente
  -- exigiría reconciliar dos buffers distintos que apuntarían al mismo path, y eso implica
  -- decisiones de UI/ventanas (qué buffer conservar, cuál sustituir, qué ventanas actualizar,
  -- etc.). Ese tipo de coordinación no puede resolverse de forma segura a nivel de buffer.
  local existing_buf = vim.fn.bufnr(resolved_path)
  if existing_buf ~= -1 and existing_buf ~= target then
    return {
      status = M.status.EXISTING_BUF,
      path = resolved_path,
      existing_buf = existing_buf,
      msg = ("ya existe otro buffer asociado a '%s'"):format(resolved_path),
    }
  end

  local original_name = vim.api.nvim_buf_get_name(target)
  if not hzsr.buf.rename_to_path(target, resolved_path) then
    hzsr.err.Error
      .new("hzsr.buf.write", "RENAME_TO_PATH_FAILED", "buffer could not be renamed before write", {
        bufnr = target,
        original_name = original_name,
        path = resolved_path,
      })
      :raise()
  end

  local out = M.write(target, { force = opts.force, force_overwrite = opts.force_overwrite })

  if out.status ~= M.status.SUCCESS then
    local restored, restore_err = restore_buffer_name(target, original_name)

    if not restored then
      hzsr.err.Error
        .new(
          "hzsr.buf.write",
          "RESTORE_NAME_FAILED",
          "write failed and original buffer name could not be restored",
          {
            bufnr = target,
            original_name = original_name,
            path = resolved_path,
            write_msg = out.msg,
            restore_err = restore_err,
          }
        )
        :raise()
    end

    cleanup_stale_path_buffer(resolved_path, target)

    return { status = out.status, msg = out.msg, path = resolved_path }
  end

  return { status = M.status.SUCCESS, path = resolved_path }
end

return M
