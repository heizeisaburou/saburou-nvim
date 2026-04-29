-- hzsr.edt.io.save.save

local M = {}

local Detail = require "hzsr.edt.io.save.detail"
local IO = require "hzsr.edt.io.detail"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.save.opts
---@field path? string
---@field path_policy? hzsr.edt.io.path_policy
---@field conflict_policy? hzsr.edt.io.conflict_policy
---@field explicit_cancel? boolean
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field async? boolean

---@class hzsr.edt.io.save.opts.internal : hzsr.edt.io.reveal_opts
---@field path? string
---@field path_policy hzsr.edt.io.path_policy
---@field conflict_policy hzsr.edt.io.conflict_policy
---@field explicit_cancel boolean

---@class hzsr.edt.io.save.confirm_overwrite_opts
---@field explicit_cancel boolean

---@alias hzsr.edt.io.save.write_decision "ok"|"reject"|"cancel"

-- -----------------------------------------------------------------------------

---Guarda un buffer en disco.
---
---@param bufnr integer?
---@param opts hzsr.edt.io.save.opts?
---@return hzsr.edt.io.save.out?
function M.save(bufnr, opts)
  local b, o = Detail.parse_save_args(bufnr, opts)

  ---@type hzsr.edt.reveal.Reveal
  local reveal = IO.new_reveal(b, o)

  return IO.with_reveal(reveal, function()
    local kind, path = Detail.resolve_save_path(b, o)

    if kind == Detail.PATH_KIND.MISSING then
      hzsr.err.Error
        .new("hzsr.edt.io.save", "PATH_REQUIRED", "path_policy=require requiere opts.path", {
          bufnr = b,
          path_policy = o.path_policy,
        })
        :raise()
    end

    if kind == Detail.PATH_KIND.ASK then
      path = Detail.ask_save_path(reveal, b, o)

      if not path then
        return IO.make_out(hzsr.edt.io.status.CANCEL, b, nil, "guardado cancelado")
      end
    end

    if not path then
      return IO.make_out(
        hzsr.edt.io.status.ERROR,
        b,
        nil,
        "no se pudo resolver el path de guardado"
      )
    end

    local write_out, decision = Detail.write_to_save_path(reveal, b, path, o)

    if decision == "cancel" then
      return IO.make_out(hzsr.edt.io.status.CANCEL, b, write_out.path, "guardado cancelado", {
        write_status = write_out.status,
        existing_buf = write_out.existing_buf,
      })
    end

    if decision == "reject" then
      return IO.make_out(hzsr.edt.io.status.REJECT, b, write_out.path, "guardado rechazado", {
        write_status = write_out.status,
        existing_buf = write_out.existing_buf,
      })
    end

    if write_out.status ~= hzsr.buf.write.status.SUCCESS then
      return IO.make_out(hzsr.edt.io.status.ERROR, b, write_out.path, write_out.msg, {
        write_status = write_out.status,
        existing_buf = write_out.existing_buf,
      })
    end

    return IO.make_out(hzsr.edt.io.status.SUCCESS, b, write_out.path, "guardado correcto", {
      write_status = write_out.status,
      existing_buf = write_out.existing_buf,
    })
  end)
end

-- -----------------------------------------------------------------------------

return M
