-- Llevar los enlaces ya escritos a su forma canónica.
--
-- El vault se desincroniza pase lo que pase: la app de Obsidian, un merge de
-- git o una edición a mano escriben enlaces sin pasar por aquí. Y crear una
-- nota puede volver ambiguos enlaces que ya existían y que nadie ha tocado.
--
-- Dos entradas, con criterios distintos a propósito:
--
--   M.plan()          todo el vault, canonizando (`:NyabsidianRelink`). Es una
--                     acción explícita y revisable, así que acorta y alarga.
--   M.on_note_added() sólo los enlaces que la nota nueva acaba de volver
--                     ambiguos, y sólo para ALARGARLOS. Corre solo, sin que
--                     nadie lo pida, así que se limita a la corrección: un
--                     enlace que ha pasado a apuntar a otro sitio. El estilo
--                     no se toca por la espalda.
--
-- Lo que NUNCA se toca: enlaces que no resuelven, o que resuelven a más de una
-- cosa. En una pasada masiva, no saber es razón para no tocar. Los enlaces
-- rotos son cosa de lzy.obsidian.diagnostics.

local M = {}

---@param path string|table
---@return string
local function normalize(path)
  return vim.fs.normalize(tostring(path))
end

---@param bufnr integer|?
---@return string|nil
local function vault_root(bufnr)
  if not rawget(_G, "Obsidian") then
    return nil
  end
  local ok, api = pcall(require, "obsidian.api")
  if not ok then
    return nil
  end
  local source = bufnr and vim.api.nvim_buf_get_name(bufnr) or nil
  local workspace = source and source ~= "" and api.find_workspace(source) or nil
  if workspace then
    return normalize(workspace.root)
  end
  return Obsidian.dir and normalize(Obsidian.dir) or nil
end

---@param path string
---@return string[]
local function read_lines(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

--- El fragmento (`#heading`) de un target, para devolverlo tal cual.
---@param target string
---@return string coordinate
---@return string fragment incluye el `#`, o "" si no hay
local function split_fragment(target)
  local hash = target:find("#", 1, true)
  if not hash then
    return target, ""
  end
  return target:sub(1, hash - 1), target:sub(hash)
end

--- A qué fichero apunta este target, si es que apunta a uno solo.
--- `exclude` es lo que hace posible reparar una ambigüedad recién creada: al
--- ignorar la nota que acaba de aparecer, lo que queda es el destino que el
--- enlace tenía cuando se escribió. Sin eso no se podría tocar —el enlace ya
--- resuelve a dos sitios— y justo por eso hay que tocarlo.
---@param target string sin fragmento
---@param source_path string
---@param root string
---@param index nyabsidian.AttachmentIndex
---@param exclude string|nil ruta a ignorar al resolver
---@return string|nil path
local function resolve_one(target, source_path, root, index, exclude)
  local attachments = require "lzy.obsidian.attachments"
  if attachments.is_target(target, { source_path = source_path, root = root, index = index }) then
    local resolved = attachments.resolve(target, {
      source_path = source_path,
      root = root,
      index = index,
    })
    if resolved.status ~= "resolved" then
      return nil
    end
    return normalize(resolved.path) ~= exclude and resolved.path or nil
  end

  local paths = require("lzy.obsidian.notes").resolve_sync(target, root)
  if exclude then
    paths = vim.tbl_filter(function(candidate)
      return normalize(candidate) ~= exclude
    end, paths)
  end
  return #paths == 1 and paths[1] or nil
end

---@class nyabsidian.RelinkPlan
---@field changes table<string, lsp.TextEdit[]> por ruta de fichero
---@field count integer enlaces que cambian
---@field files integer ficheros afectados

---@param opts { root?: string, only_name?: string, expand_only?: boolean, exclude?: string }|?
---@return nyabsidian.RelinkPlan|nil plan
---@return string|nil err
function M.plan(opts)
  opts = opts or {}
  local root = opts.root and normalize(opts.root) or vault_root()
  local exclude = opts.exclude and normalize(opts.exclude) or nil
  if not root then
    return nil, "no hay ningún vault activo"
  end

  local attachments = require "lzy.obsidian.attachments"
  local coordinate = require "lzy.obsidian.coordinate"
  local notes = require "lzy.obsidian.notes"

  -- Un índice para toda la pasada, no uno por enlace. Se invalida una vez aquí
  -- justo porque después NO se va a volver a mirar el disco (ver `fresh` en
  -- lzy.obsidian.coordinate).
  pcall(notes.invalidate_index, root)
  local index = attachments.build_index(root)

  local wanted = opts.only_name and opts.only_name:lower() or nil
  local changes, count, files = {}, 0, 0

  for _, source_path in ipairs(index.references) do
    if coordinate.is_note(source_path) then
      local edits = {}
      -- Nunca dentro de un bloque de código: ahí un `[[x]]` es un ejemplo y
      -- canonizarlo corrompe el bloque.
      local lines = read_lines(source_path)
      local excluded = require("lzy.link_target").excluded_rows(lines)
      for row, line in ipairs(lines) do
        for _, ref in ipairs(excluded[row - 1] and {} or attachments.parse_refs(line, row - 1)) do
          local kind = ref.kind
          if (kind == "wiki" or kind == "markdown") and ref.target_range then
            local coord, fragment = split_fragment(ref.target)
            local decoded = vim.uri_decode(coord) or coord
            if coord ~= "" and not require("obsidian.util").is_uri(decoded) then
              local matches_filter = wanted == nil
                or vim.fs.basename(decoded:gsub("%.[^./]+$", "")):lower() == wanted
              if matches_filter then
                local target_path = resolve_one(coord, source_path, root, index, exclude)
                if target_path then
                  local canonical = coordinate.write(target_path, {
                    root = root,
                    kind = kind,
                    index = index,
                  })
                  -- `expand_only`: la re-minimización automática sólo repara
                  -- ambigüedad, nunca reordena por gusto.
                  local grows = #canonical > #coord
                  -- En un `[[Destino]]` sin alias el destino ES el texto que se
                  -- lee, así que corregirle la caja cambia la prosa. Y no gana
                  -- nada: la caja sólo importa para GitHub, que ni siquiera
                  -- renderiza wikilinks. En un enlace Markdown sí se corrige,
                  -- porque ahí la caja decide si resuelve o da 404.
                  local case_only = kind == "wiki" and canonical:lower() == coord:lower()
                  -- Un destino entre ángulos ya es portable: `[x](<a b.md>)` es
                  -- CommonMark válido, funciona en GitHub y conserva el espacio
                  -- legible. Reescribirlo a `%20` metería el escape DENTRO de
                  -- los ángulos -- redundante, más feo, y peleándose con una
                  -- forma correcta que alguien eligió a propósito.
                  local angled = kind == "markdown"
                    and ref.target_range.start_col > 0
                    and line:sub(ref.target_range.start_col, ref.target_range.start_col) == "<"
                  if
                    canonical ~= coord
                    and not case_only
                    and not angled
                    and (not opts.expand_only or grows)
                  then
                    edits[#edits + 1] = {
                      range = {
                        start = { line = row - 1, character = ref.target_range.start_col },
                        ["end"] = { line = row - 1, character = ref.target_range.end_col },
                      },
                      newText = canonical .. fragment,
                    }
                    count = count + 1
                  end
                end
              end
            end
          end
        end
      end

      if #edits > 0 then
        -- De atrás hacia adelante: si no, cada edición desplaza las columnas de
        -- las siguientes de su misma línea.
        table.sort(edits, function(a, b)
          if a.range.start.line == b.range.start.line then
            return a.range.start.character > b.range.start.character
          end
          return a.range.start.line > b.range.start.line
        end)
        changes[source_path] = edits
        files = files + 1
      end
    end
  end

  return { changes = changes, count = count, files = files }
end

---@param plan nyabsidian.RelinkPlan
---@return lsp.WorkspaceEdit
function M.workspace_edit(plan)
  local documentChanges = {}
  for path, edits in pairs(plan.changes) do
    documentChanges[#documentChanges + 1] = {
      textDocument = { uri = vim.uri_from_fname(path), version = vim.NIL },
      edits = edits,
    }
  end
  return { documentChanges = documentChanges }
end

---@param opts { root?: string, notify?: fun(msg: string, level?: integer), confirm?: fun(prompt: string): boolean }|?
function M.run(opts)
  opts = opts or {}
  local notify = opts.notify
    or function(msg, level)
      vim.notify(msg, level or vim.log.levels.INFO, { title = "Nyabsidian" })
    end

  local plan, err = M.plan { root = opts.root }
  if not plan then
    return notify(err or "no se pudo planificar", vim.log.levels.ERROR)
  end
  if plan.count == 0 then
    return notify "Los enlaces ya están en su forma canónica"
  end

  local prompt = ("Reescribir %d enlace(s) en %d fichero(s)?"):format(plan.count, plan.files)
  local accepted = opts.confirm and opts.confirm(prompt)
    or (not opts.confirm and vim.fn.confirm(prompt, "&Sí\n&No", 2) == 1)
  if not accepted then
    return notify("Sin cambios", vim.log.levels.WARN)
  end

  vim.lsp.util.apply_workspace_edit(M.workspace_edit(plan), "utf-8")
  vim.schedule(function()
    vim.cmd "silent! wall"
  end)
  notify(("Reescritos %d enlace(s) en %d fichero(s)"):format(plan.count, plan.files))
end

--- Una nota nueva puede volver ambiguos enlaces que ya existían y que apuntaban
--- sin problema a otra homónima. Eso no es estilo: son enlaces que han pasado a
--- señalar otra cosa.
---
--- La puerta es barata a propósito -- mirar si el nombre colisiona es un lookup
--- contra el índice --, así que el alta de una nota que no colisiona (la
--- inmensa mayoría) no paga la pasada.
---@param path string la nota recién creada
---@param opts { root?: string, notify?: fun(msg: string, level?: integer) }|?
---@return integer rewritten
function M.on_note_added(path, opts)
  opts = opts or {}
  local root = opts.root and normalize(opts.root) or vault_root()
  if not root then
    return 0
  end

  local coordinate = require "lzy.obsidian.coordinate"
  path = normalize(path)
  if not coordinate.is_ambiguous(path, { root = root, fresh = true }) then
    return 0
  end

  local name = coordinate.strip_note_extension(vim.fs.basename(path))
  local plan = M.plan {
    root = root,
    only_name = name,
    expand_only = true,
    -- Ignorando la recién llegada, lo que queda es a dónde apuntaban antes.
    exclude = path,
  }
  if not plan or plan.count == 0 then
    return 0
  end

  vim.lsp.util.apply_workspace_edit(M.workspace_edit(plan), "utf-8")
  vim.schedule(function()
    vim.cmd "silent! wall"
  end)

  local notify = opts.notify
    or function(msg, level)
      vim.notify(msg, level or vim.log.levels.INFO, { title = "Nyabsidian" })
    end
  notify(
    ("'%s' colisiona con otra nota: %d enlace(s) ampliados para que sigan apuntando a la suya"):format(
      name,
      plan.count
    )
  )
  return plan.count
end

return M
