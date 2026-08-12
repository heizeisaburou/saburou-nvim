-- Selector de backlinks de Nyabsidian.
--
-- Upstream abre directamente la nota cuando solo existe un resultado. Para
-- revisar backlinks eso cambia el significado de la acción según el número de
-- matches; aquí el resultado, incluso vacío, pasa siempre por el picker.

local M = {}

local installed = false

---@param opts { references?: fun(callback: fun(err: any, locations: lsp.Location[])), pick?: fun(items: table[], opts: table), notify?: fun(msg: string, level?: integer) }|?
function M.open(opts)
  opts = opts or {}

  local references = opts.references
    or function(callback)
      require "obsidian.lsp.handlers._references"(nil, { tag = false }, callback)
    end

  references(function(err, locations)
    if err then
      local notify = opts.notify or vim.notify
      notify("No se pudieron obtener los backlinks: " .. tostring(err), vim.log.levels.ERROR)
      return
    end

    local items = vim.lsp.util.locations_to_items(locations or {}, "utf-8")
    local pick = opts.pick
      or function(values, picker_opts)
        Obsidian.picker.pick(values, picker_opts)
      end
    pick(items, { prompt_title = "Backlinks" })
  end)
end

function M.setup(state)
  if state then
    state.backlink_picker_patched = true
  end
  if installed then
    return
  end

  -- `:Obsidian backlinks` resuelve este módulo en cada invocación, por lo que
  -- sustituir la entrada del package mantiene tanto el comando como el keymap
  -- oficiales, cambiando únicamente la política 0/1/N del resultado.
  package.loaded["obsidian.commands.backlinks"] = function()
    M.open()
  end
  installed = true
end

return M
