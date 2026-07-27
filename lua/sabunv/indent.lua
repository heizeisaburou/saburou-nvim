-- sabunv.indent

local M = {}

local overrides = {}
local user_config = nil

local valid_styles = {
  spaces = true,
  tabs = true,
}

---@class sabunv.indent.config
---@field style "spaces"|"tabs"
---@field width integer

---@class sabunv.indent.user_config
---@field default sabunv.indent.config
---@field filetypes table<string, sabunv.indent.config>

---@param config any
---@param context string
---@return sabunv.indent.config
local function validate_config(config, context)
  assert(type(config) == "table", context .. " debe ser una tabla")
  assert(valid_styles[config.style], context .. ".style debe ser 'spaces' o 'tabs'")
  assert(
    type(config.width) == "number" and config.width > 0 and config.width % 1 == 0,
    context .. ".width debe ser un entero positivo"
  )

  return {
    style = config.style,
    width = config.width,
  }
end

---@param config any
---@return sabunv.indent.user_config
local function validate_user_config(config)
  assert(type(config) == "table", "La configuración de indentación debe ser una tabla")

  local normalized = {
    default = validate_config(config.default, "indent.default"),
    filetypes = {},
  }

  for filetype, filetype_config in pairs(config.filetypes or {}) do
    assert(type(filetype) == "string" and filetype ~= "", "indent.filetypes contiene un filetype inválido")

    local merged = vim.tbl_extend("force", {}, normalized.default, filetype_config)
    normalized.filetypes[filetype] = validate_config(merged, "indent.filetypes." .. filetype)
  end

  return normalized
end

---@param values any
---@return table<string, sabunv.indent.config>
function M.normalize_overrides(values)
  local normalized = {}

  if type(values) ~= "table" then
    return normalized
  end

  for filetype, config in pairs(values) do
    if
      type(filetype) == "string"
      and filetype ~= ""
      and type(config) == "table"
      and valid_styles[config.style]
      and type(config.width) == "number"
      and config.width > 0
      and config.width % 1 == 0
    then
      normalized[filetype] = {
        style = config.style,
        width = config.width,
      }
    end
  end

  return normalized
end

local function sync_memory_state()
  vim.g.sabunv_indent_overrides = vim.deepcopy(overrides)
  vim.g.sabunv_indent_overrides_initialized = true
end

local function restore_overrides()
  if vim.g.sabunv_indent_overrides_initialized == true then
    overrides = M.normalize_overrides(vim.g.sabunv_indent_overrides)
    sync_memory_state()
    return
  end

  local restart_overrides = {}
  local ok, restart = pcall(require, "sabunv.restart")

  if ok and type(restart.load_indent_overrides) == "function" then
    local loaded, saved = pcall(restart.load_indent_overrides)
    if loaded then
      restart_overrides = saved
    end
  end

  overrides = M.normalize_overrides(restart_overrides)
  sync_memory_state()
end

local function ensure_setup()
  assert(user_config, "sabunv.indent.setup debe ejecutarse antes de usar la política")
end

---@param filetype? string
---@return sabunv.indent.config
function M.get(filetype)
  ensure_setup()

  filetype = filetype or ""

  local configured = user_config.filetypes[filetype] or {}
  local runtime = overrides[filetype] or {}
  local resolved = vim.tbl_extend("force", {}, user_config.default, configured, runtime)

  return validate_config(resolved, "indent resuelto para " .. (filetype ~= "" and filetype or "default"))
end

---@param bufnr? integer
---@return sabunv.indent.config
function M.for_buffer(bufnr)
  bufnr = bufnr or 0
  return M.get(vim.bo[bufnr].filetype)
end

---@param bufnr integer
function M.apply(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local config = M.for_buffer(bufnr)
  local bo = vim.bo[bufnr]

  bo.expandtab = config.style == "spaces"
  bo.shiftwidth = config.width
  bo.tabstop = config.width
  bo.softtabstop = config.width
end

---@param filetype? string
function M.apply_all(filetype)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and (filetype == nil or vim.bo[bufnr].filetype == filetype) then
      M.apply(bufnr)
    end
  end
end

---@return table<string, sabunv.indent.config>
function M.overrides()
  return vim.deepcopy(overrides)
end

---@param filetype string
---@param config table
---@return sabunv.indent.config
function M.set(filetype, config)
  ensure_setup()
  assert(type(filetype) == "string" and filetype ~= "", "Se necesita un filetype para el override")
  assert(type(config) == "table", "El override de indentación debe ser una tabla")

  local resolved = vim.tbl_extend("force", {}, M.get(filetype), config)
  overrides[filetype] = validate_config(resolved, "override de indentación para " .. filetype)

  sync_memory_state()
  M.apply_all(filetype)

  return vim.deepcopy(overrides[filetype])
end

---@param filetype? string
function M.reset(filetype)
  ensure_setup()

  if filetype == nil then
    overrides = {}
    sync_memory_state()
    M.apply_all()
    return
  end

  assert(type(filetype) == "string" and filetype ~= "", "Se necesita un filetype para resetear")

  overrides[filetype] = nil
  sync_memory_state()
  M.apply_all(filetype)
end

local function current_filetype()
  local filetype = vim.bo.filetype
  assert(filetype ~= "", "El buffer actual no tiene filetype")
  return filetype
end

local function setup_commands()
  vim.api.nvim_create_user_command("IndentSet", function(args)
    assert(#args.fargs <= 3, "Uso: IndentSet {spaces|tabs} [width] [filetype]")

    local style = args.fargs[1]
    assert(valid_styles[style], "Uso: IndentSet {spaces|tabs} [width] [filetype]")

    local config = { style = style }
    local width = tonumber(args.fargs[2])
    local filetype

    if args.fargs[3] then
      assert(width, "Al indicar un tercer argumento, el segundo debe ser width")
      config.width = width
      filetype = args.fargs[3]
    elseif args.fargs[2] then
      if width then
        config.width = width
        filetype = current_filetype()
      else
        filetype = args.fargs[2]
      end
    else
      filetype = current_filetype()
    end

    local applied = M.set(filetype, config)
    vim.notify(("Indent %s: %s, width=%d"):format(filetype, applied.style, applied.width), vim.log.levels.INFO)
  end, {
    nargs = "+",
    force = true,
    complete = function(_, command_line)
      local count = #vim.split(command_line, "%s+", { trimempty = true })
      if count <= 2 then
        return { "spaces", "tabs" }
      end
      return vim.fn.getcompletion("", "filetype")
    end,
    desc = "Sobrescribir temporalmente la indentación de un filetype",
  })

  vim.api.nvim_create_user_command("IndentReset", function(args)
    if args.bang then
      M.reset()
      vim.notify("Overrides de indentación eliminados", vim.log.levels.INFO)
      return
    end

    local filetype = args.args ~= "" and args.args or current_filetype()
    M.reset(filetype)
    vim.notify("Override de indentación eliminado: " .. filetype, vim.log.levels.INFO)
  end, {
    nargs = "?",
    bang = true,
    force = true,
    complete = "filetype",
    desc = "Eliminar un override de indentación; con ! elimina todos",
  })
end

---@param config sabunv.indent.user_config
function M.setup(config)
  user_config = validate_user_config(config)
  restore_overrides()

  local default = M.get()
  vim.o.expandtab = default.style == "spaces"
  vim.o.shiftwidth = default.width
  vim.o.tabstop = default.width
  vim.o.softtabstop = default.width

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("SabunvIndentPolicy", { clear = true }),
    callback = function(args)
      M.apply(args.buf)
    end,
    desc = "Aplicar la política de indentación del filetype",
  })

  setup_commands()
  M.apply_all()
end

return M
