-- lzy/l_moonfly/validation

local M = {}

local tbl = require "hzsr.tbl"

local METHOD_ID = "moonfly_manager.setup()"

local VALID_TRANSPARENT = { "none", "tree", "bg", "both" }
local VALID_SEP_STYLE = { "thin", "slant", "slope" }
local VALID_SEP_COLOR = { "gray", "blue" }

local ALLOWED_THEME_FIELDS = {
  transparent = true,
  bufferline = true,
  statuscol = true,
  nvimtree = true,
  lualine = true,
}

local ALLOWED_BUFFERLINE_FIELDS = {
  enabled = true,
  sep_style = true,
  sep_color = true,
}

local ALLOWED_STATUSCOL_FIELDS = {
  enabled = true,
}

local ALLOWED_NVIMTREE_FIELDS = {
  enabled = true,
}

local ALLOWED_LUALINE_FIELDS = {
  enabled = true,
}

---@param value unknown
---@param field string
local function expect_table(value, field)
  if type(value) ~= "table" then
    error(METHOD_ID .. ": " .. field .. " debe ser una tabla")
  end
end

---@param value unknown
---@param field string
local function expect_string(value, field)
  if type(value) ~= "string" then
    error(METHOD_ID .. ": " .. field .. " debe ser string")
  end
end

---@param value unknown
---@param field string
local function expect_boolean(value, field)
  if type(value) ~= "boolean" then
    error(METHOD_ID .. ": " .. field .. " debe ser boolean")
  end
end

---@param value string
---@param valid string[]
---@param field string
local function expect_one_of(value, valid, field)
  if not tbl.contains(valid, value) then
    error(
      METHOD_ID .. ": " .. field .. " inválido. Valores válidos: " .. table.concat(valid, ", ")
    )
  end
end

---@param t table
---@param allowed table<string, boolean>
---@param field string
local function reject_unknown_fields(t, allowed, field)
  for key, _ in pairs(t) do
    if not allowed[key] then
      error(METHOD_ID .. ": campo desconocido `" .. key .. "` en " .. field)
    end
  end
end

---@param value unknown
---@param valid string[]
---@param field string
local function validate_optional_string_enum(value, valid, field)
  if value == nil then
    return
  end

  expect_string(value, field)
  expect_one_of(value, valid, field)
end

---@param value unknown
---@param field string
local function validate_optional_boolean(value, field)
  if value == nil then
    return
  end

  expect_boolean(value, field)
end

---@param user_opts? HzsrThemeOpts
function M.user_opts(user_opts)
  if user_opts == nil then
    return
  end

  expect_table(user_opts, "user_opts")
  reject_unknown_fields(user_opts, ALLOWED_THEME_FIELDS, "user_opts")

  validate_optional_string_enum(user_opts.transparent, VALID_TRANSPARENT, "transparent")

  if user_opts.bufferline ~= nil then
    expect_table(user_opts.bufferline, "bufferline")
    reject_unknown_fields(user_opts.bufferline, ALLOWED_BUFFERLINE_FIELDS, "bufferline")

    validate_optional_boolean(user_opts.bufferline.enabled, "bufferline.enabled")
    validate_optional_string_enum(
      user_opts.bufferline.sep_style,
      VALID_SEP_STYLE,
      "bufferline.sep_style"
    )
    validate_optional_string_enum(
      user_opts.bufferline.sep_color,
      VALID_SEP_COLOR,
      "bufferline.sep_color"
    )
  end

  if user_opts.statuscol ~= nil then
    expect_table(user_opts.statuscol, "statuscol")
    reject_unknown_fields(user_opts.statuscol, ALLOWED_STATUSCOL_FIELDS, "statuscol")

    validate_optional_boolean(user_opts.statuscol.enabled, "statuscol.enabled")
  end

  if user_opts.nvimtree ~= nil then
    expect_table(user_opts.nvimtree, "nvimtree")
    reject_unknown_fields(user_opts.nvimtree, ALLOWED_NVIMTREE_FIELDS, "nvimtree")

    validate_optional_boolean(user_opts.nvimtree.enabled, "nvimtree.enabled")
  end

  if user_opts.lualine ~= nil then
    expect_table(user_opts.lualine, "lualine")
    reject_unknown_fields(user_opts.lualine, ALLOWED_LUALINE_FIELDS, "lualine")

    validate_optional_boolean(user_opts.lualine.enabled, "lualine.enabled")
  end
end

return M
