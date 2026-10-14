local config_dir = "/home/saburou/.config/hzsr12"
local plugin = "/home/saburou/.local/share/hzsr12/lazy/todo-comments.nvim"

vim.opt.runtimepath:prepend(config_dir)
vim.opt.runtimepath:prepend(plugin)
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

describe("todo-comments: primer `:` de una etiqueta", function()
  local todo = require "lzy.todo-comments"
  local namespace = vim.api.nvim_create_namespace "todo-comments-leading-padding"

  -- La configuración del plugin se inicializa a mano: su `setup` la aplaza a
  -- `VimEnter`, que en un spec no llega.
  local plugin_config = require "todo-comments.config"
  plugin_config._options = todo.opts
  plugin_config._setup()

  --- Abre las líneas como Lua, con Tree-sitter, que es de donde el plugin saca
  --- qué es comentario, y devuelve las marcas como `fila:columna:grupo`.
  local function marks(lines, first, last)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "lua"
    vim.treesitter.start(buf, "lua")

    todo._update_leading_padding(buf)
    if first then
      todo._update_leading_padding(buf, first, last)
    end

    local result = {}
    for _, mark in
      ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true }))
    do
      result[#result + 1] = ("%d:%d:%s"):format(mark[2], mark[3], mark[4].hl_group)
    end
    vim.api.nvim_buf_delete(buf, { force = true })
    return result
  end

  -- En todas las muestras el `:` está en la columna 8 y la palabra empieza en
  -- la 9; las continuaciones llevan un `?` bajo los dos puntos.
  it("paints the colon column on every line that continues the tag", function()
    assert.are.same(
      {
        "0:8:TodoLeadingPaddingTODO",
        "1:8:TodoFgTODO",
        "2:8:TodoFgTODO",
      },
      marks {
        "-- HOLA :TODO: esto se colorea",
        "--      ?y esto también",
        "--      ?y esto",
        "local x = 1",
      }
    )
  end)

  it("stops at the first line with nothing under the keyword", function()
    assert.are.same(
      {
        "0:8:TodoLeadingPaddingTODO",
        "1:8:TodoFgTODO",
      },
      marks {
        "-- HOLA :TODO: esto se colorea",
        "--      ?esto también",
        "--",
        "--      ?esto ya no: el hueco de arriba corta el bloque",
      }
    )
  end)

  it("lets a new tag close the previous block", function()
    assert.are.same(
      {
        "0:8:TodoLeadingPaddingTODO",
        "1:8:TodoFgTODO",
        "2:8:TodoLeadingPaddingFIX",
        "3:8:TodoFgFIX",
      },
      marks {
        "-- HOLA :TODO: primera",
        "--      ?sigue la primera",
        "-- HOLA :BUG: segunda, con un alias",
        "--      ?sigue la segunda",
      }
    )
  end)

  it("keeps the block when only part of it is updated", function()
    local lines = { "-- HOLA :TODO: arriba" }
    for _ = 1, 30 do
      lines[#lines + 1] = "--      ?sigue"
    end

    -- La fila 25 queda más allá del contexto que se relee hacia arriba: la
    -- etiqueta hay que buscarla.
    local result = marks(lines, 25, 26)
    assert.are.equal(31, #result)
    assert.are.equal("25:8:TodoFgTODO", result[26])
  end)
end)
