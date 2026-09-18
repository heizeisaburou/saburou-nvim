local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(source))

---@param path string
---@param heading string
---@return string[]
local function table_after(path, heading)
  local found_heading = false
  local found_table = false
  local result = {}

  for _, line in ipairs(vim.fn.readfile(path)) do
    if line == heading then
      found_heading = true
    elseif found_heading and line:sub(1, 2) == "| " then
      found_table = true
      result[#result + 1] = line
    elseif found_table then
      break
    end
  end

  assert.is_true(found_heading, "No se encontró " .. heading .. " en " .. path)
  assert.is_true(found_table, "No se encontró una tabla después de " .. heading)
  return result
end

describe("Documentación de lenguajes", function()
  it("mantiene sincronizadas las matrices del README y la guía", function()
    local readme = table_after(vim.fs.joinpath(root, "README.md"), "## Lenguajes soportados")
    local guide = table_after(
      vim.fs.joinpath(root, "docs", "_ordenar", "language-dependencies.md"),
      "## Matriz de soporte"
    )

    assert.are.same(readme, guide)
  end)
end)
