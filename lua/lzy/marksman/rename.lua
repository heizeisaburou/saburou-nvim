local M = {}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Marksman" })
end

local function read_lines(path)
	local bufnr = vim.fn.bufnr(path)
	if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end
	local ok, lines = pcall(vim.fn.readfile, path)
	return ok and lines or {}
end

local function encode_component(value)
	-- Decodifica primero: el destino puede venir ya escapado del buffer, y
	-- re-escaparlo convertiria %20 en %2520.
	return require("lzy.link_target").encode(vim.uri_decode(value) or value)
end

---@param kind string|nil `ref.kind`
---@param root string
local function replacement_path(raw_path, new_path, kind, root)
	local decoded = vim.uri_decode(raw_path) or raw_path
	local slash = math.max(decoded:match(".*()/") or 0, decoded:match(".*()\\") or 0)
	local prefix = decoded:sub(1, slash)
	local old_base = decoded:sub(slash + 1)
	local new_base = vim.fs.basename(new_path)
	if not old_base:match("%.[^%.]+$") then
		new_base = new_base:gsub("%.[^%.]+$", "")
	end

	-- Dentro de `[[...]]` el espacio va literal: escapar aquí es lo que convertía
	-- un rename a "Espacios y mayús" en `[[Espacios%20y%20mayús]]`. El escape es
	-- cosa del destino Markdown, donde el espacio sí corta.
	--
	-- Y la forma del nombre la decide el proyecto, no nosotros: en un proyecto
	-- con `style = "title-slug"` (el default de marksman) su linter propone
	-- `[[mi-nota]]`, así que escribir `[[Mi nota]]` dejaba el buffer con las dos.
	if kind == "wiki" then
		return prefix .. require("lzy.marksman.workspace").wiki_name(new_path, root)
	end

	local result = encode_component(prefix .. new_base):gsub("%%2F", "/")
	result = result:gsub("%%2f", "/")
	return result
end

local function is_bare_path(raw_path)
	local decoded = vim.uri_decode(raw_path) or raw_path
	return not decoded:find("[/\\]")
end

local function bare_path_collides(raw_path, old_path, new_path, root)
	if not is_bare_path(raw_path) then
		return false
	end
	local with_extension = (vim.uri_decode(raw_path) or raw_path):match("%.[^%.]+$") ~= nil
	local wanted = vim.fs.basename(new_path)
	if not with_extension then
		wanted = wanted:gsub("%.[^%.]+$", "")
	end
	for _, path in ipairs(require("lzy.marksman.workspace").files(root, { markdown = true })) do
		if vim.fs.normalize(path) ~= vim.fs.normalize(old_path) then
			local candidate = vim.fs.basename(path)
			if not with_extension then
				candidate = candidate:gsub("%.[^%.]+$", "")
			end
			if candidate == wanted then
				return true
			end
		end
	end
	return false
end

---Los ficheros que responden al mismo nombre pelado que `new_path`, para que la
---primitiva compartida pueda desambiguar sin conocer el índice de un vault
---(fuera de un vault no hay ninguno).
local function homonyms_of(new_path, old_path, root)
	local wanted = vim.fs.basename(new_path):gsub("%.[^%.]+$", ""):lower()
	local found = {}
	for _, path in ipairs(require("lzy.marksman.workspace").files(root, { markdown = true })) do
		if
			vim.fs.normalize(path) ~= vim.fs.normalize(old_path)
			and vim.fs.basename(path):gsub("%.[^%.]+$", ""):lower() == wanted
		then
			found[#found + 1] = path
		end
	end
	return found
end

---@param kind string|nil `ref.kind`
local function safe_replacement_path(raw_path, old_path, new_path, root, kind)
	if not bare_path_collides(raw_path, old_path, new_path, root) then
		return replacement_path(raw_path, new_path, kind, root)
	end

	local relative
	if kind == "wiki" then
		-- Un `[[wiki]]` lo resuelve un motor que busca, así que le vale el sufijo
		-- MÍNIMO que separe: `c/nota` donde antes salía `a/b/c/nota`. Misma
		-- primitiva que el lado Obsidian, para que los dos desambigüen igual.
		relative = require("lzy.obsidian.coordinate").minimal(new_path, {
			root = root,
			homonyms = homonyms_of(new_path, old_path, root),
		})
		-- El sufijo lo decide la desambiguación; cómo se escribe el NOMBRE, el
		-- proyecto (ver workspace.wiki_style).
		local name = require("lzy.marksman.workspace").wiki_name(new_path, root)
		relative = relative:gsub("[^/]+$", (name:gsub("%%", "%%%%")))
	else
		-- Un destino Markdown lo resuelve GitHub siguiendo la ruta literal: un
		-- sufijo mínimo depende de la búsqueda y ahí daría 404. Ruta desde la
		-- raíz, siempre (docs/todo-markdown.md §1.6).
		relative = "/" .. assert(vim.fs.relpath(root, new_path))
	end

	if not (vim.uri_decode(raw_path) or raw_path):match("%.[^%.]+$") then
		relative = relative:gsub("%.[^%.]+$", "")
	elseif not relative:match("%.[^%.]+$") then
		relative = relative .. (vim.fs.basename(new_path):match("%.[^%.]+$") or "")
	end

	local encoded = encode_component(relative):gsub("%%2F", "/")
	return encoded:gsub("%%2f", "/")
end

local function contains_path(paths, wanted)
	wanted = vim.fs.normalize(wanted)
	for _, path in ipairs(paths) do
		if vim.fs.normalize(path) == wanted then
			return true
		end
	end
	return false
end

local function encoded_range(value_range, line, encoding)
	if not encoding or encoding == "utf-8" then
		return value_range
	end
	return {
		start_col = vim.str_utfindex(line, encoding, value_range.start_col, false),
		end_col = vim.str_utfindex(line, encoding, value_range.end_col, false),
	}
end

local function add_change(changes, path, row, value_range, new_text, encoding, line)
	value_range = encoded_range(value_range, line or "", encoding)
	local uri = vim.uri_from_fname(path)
	changes[uri] = changes[uri] or {}
	changes[uri][#changes[uri] + 1] = {
		range = {
			start = { line = row, character = value_range.start_col },
			["end"] = { line = row, character = value_range.end_col },
		},
		newText = new_text,
	}
end

local function target_refs(path)
	local parser = require("lzy.marksman.parser")
	local result = {}
	local lines = read_lines(path)
	local excluded = parser.excluded_rows(lines)
	for idx, line in ipairs(lines) do
		if not excluded[idx - 1] then
			local definition = parser.definition(line, idx - 1)
			if definition then
				definition.source_line = line
				result[#result + 1] = definition
			else
				for _, ref in ipairs(parser.links(line, idx - 1)) do
					if ref.kind == "inline" or ref.kind == "wiki" then
						ref.source_line = line
						result[#result + 1] = ref
					end
				end
			end
		end
	end
	return result
end

local function valid_note_name(new_name, old_path)
	if type(new_name) ~= "string" or new_name == "" then
		return nil, "El nombre de la nota no puede estar vacío"
	elseif new_name ~= vim.trim(new_name) then
		return nil, "El nombre no puede empezar ni terminar con espacios"
	end
	local old_ext = old_path:match("%.([^./\\]+)$") or "md"
	if new_name:lower():sub(-#old_ext - 1) == "." .. old_ext:lower() then
		new_name = new_name:sub(1, -#old_ext - 2)
	end
	if
		new_name == ""
		or new_name == "."
		or new_name == ".."
		or new_name:find("[/\\]")
		or new_name:find('[%c<>:%"|%?%*#]')
		or new_name:sub(-1) == "."
	then
		return nil, "El nombre debe ser un basename válido, sin carpetas"
	end
	local device = new_name:match("^([^%.]+)")
	if device then
		device = device:upper()
		if
			device == "CON"
			or device == "PRN"
			or device == "AUX"
			or device == "NUL"
			or device:match("^COM[1-9]$")
			or device:match("^LPT[1-9]$")
		then
			return nil, "Ese nombre está reservado por Windows"
		end
	end
	return new_name
end

---@param old_path string
---@param new_name string
---@param root string
---@return lsp.WorkspaceEdit|nil
---@return string|nil
---@return integer|nil
function M.note_edit(old_path, new_name, root)
	old_path, root = vim.fs.normalize(old_path), vim.fs.normalize(root)
	local relative = vim.fs.relpath(root, old_path)
	if not relative or vim.startswith(relative, "..") then
		return nil, "Marksman solo renombra notas dentro del workspace"
	elseif not vim.uv.fs_stat(old_path) then
		return nil, "La nota de origen ya no existe"
	end
	local validated, err = valid_note_name(new_name, old_path)
	if not validated then
		return nil, err
	end
	new_name = validated
	local ext = old_path:match("(%.[^./\\]+)$") or ".md"
	local new_path = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(old_path), new_name .. ext))
	if new_path == vim.fs.normalize(old_path) then
		return nil, "La nota ya tiene ese nombre"
	elseif vim.uv.fs_stat(new_path) then
		return nil, "Ya existe " .. new_path
	end

	local workspace = require("lzy.marksman.workspace")
	local changes, count, ambiguous = {}, 0, 0
	for _, source_path in ipairs(workspace.files(root, { markdown = true })) do
		for _, ref in ipairs(target_refs(source_path)) do
			if ref.path and ref.path ~= "" then
				local matches = workspace.resolve(ref.path, {
					source_path = source_path,
					root = root,
				})
				if #matches == 1 and contains_path(matches, old_path) then
					add_change(
						changes,
						source_path,
						ref.range.start_row,
						ref.path_range,
						safe_replacement_path(ref.path, old_path, new_path, root, ref.kind)
					)
					count = count + 1
				elseif #matches > 1 and contains_path(matches, old_path) then
					ambiguous = ambiguous + 1
				end
			end
		end
	end

	local document_changes = {}
	for uri, edits in pairs(changes) do
		table.sort(edits, function(left, right)
			if left.range.start.line == right.range.start.line then
				return left.range.start.character > right.range.start.character
			end
			return left.range.start.line > right.range.start.line
		end)
		document_changes[#document_changes + 1] = {
			textDocument = { uri = uri, version = vim.NIL },
			edits = edits,
		}
	end
	document_changes[#document_changes + 1] = {
		kind = "rename",
		oldUri = vim.uri_from_fname(old_path),
		newUri = vim.uri_from_fname(new_path),
		options = { overwrite = false, ignoreIfExists = false },
	}
	return { documentChanges = document_changes }, nil, count, ambiguous
end

local function edit_at_range(edit, uri, row, value_range)
	for change_uri, edits in pairs(edit.changes or {}) do
		if change_uri == uri then
			for _, text_edit in ipairs(edits) do
				local current = text_edit.range
				if
					current.start.line == row
					and current.start.character == value_range.start_col
					and current["end"].character == value_range.end_col
				then
					return text_edit
				end
			end
		end
	end
	for _, change in ipairs(edit.documentChanges or {}) do
		if change.textDocument and change.textDocument.uri == uri then
			for _, text_edit in ipairs(change.edits or {}) do
				local current = text_edit.range
				if
					current.start.line == row
					and current.start.character == value_range.start_col
					and current["end"].character == value_range.end_col
				then
					return text_edit
				end
			end
		end
	end
end

local function changed_anchors(target_path, target_row, old_fragment, new_name)
	local workspace = require("lzy.marksman.workspace")
	local headings = workspace.headings(read_lines(target_path))
	if target_row == nil then
		local wanted = workspace.slug(vim.uri_decode(old_fragment) or old_fragment)
		for _, heading in ipairs(headings) do
			if heading.anchor == wanted then
				target_row = heading.row
				break
			end
		end
	end
	if target_row == nil then
		return {}
	end

	local counts, changes = {}, {}
	for _, heading in ipairs(headings) do
		local display = heading.row == target_row and new_name or heading.text
		local base = workspace.slug(display)
		local duplicate = counts[base] or 0
		counts[base] = duplicate + 1
		local anchor = duplicate == 0 and base or (base .. "-" .. duplicate)
		if anchor ~= heading.anchor then
			changes[#changes + 1] = {
				old_anchor = heading.anchor,
				new_anchor = anchor,
				display = display,
			}
		end
	end
	return changes
end

---@param edit lsp.WorkspaceEdit|nil
---@param target_path string
---@param old_fragment string
---@param new_name string
---@param root string
---@return lsp.WorkspaceEdit
function M.augment_heading_edit(edit, target_path, old_fragment, new_name, root, encoding, target_row)
	edit = edit or {}
	edit.changes = edit.changes or {}
	local workspace = require("lzy.marksman.workspace")
	local anchor_changes = changed_anchors(target_path, target_row, old_fragment, new_name)
	local by_old_anchor = {}
	for _, change in ipairs(anchor_changes) do
		by_old_anchor[change.old_anchor] = change
	end
	for _, source_path in ipairs(workspace.files(root, { markdown = true })) do
		for _, ref in ipairs(target_refs(source_path)) do
			if ref.fragment then
				local matches = workspace.resolve(ref.path, { source_path = source_path, root = root })
				local old_anchor = workspace.slug(vim.uri_decode(ref.fragment) or ref.fragment)
				local anchor_change = by_old_anchor[old_anchor]
				if #matches == 1 and contains_path(matches, target_path) and anchor_change then
					local uri = vim.uri_from_fname(source_path)
					local lsp_range = encoded_range(ref.fragment_range, ref.source_line, encoding)
					-- Igual que obsidian-ls: el heading visible conserva mayúsculas y
					-- espacios, pero todo fragmento se escribe en su forma canónica. La
					-- sintaxis wiki no es una excepción ni una segunda etiqueta.
					local replacement = anchor_change.new_anchor
					if ref.fragment:find("%%[%da-fA-F][%da-fA-F]") then
						replacement = require("lzy.link_target").encode(replacement)
					end
					local existing = edit_at_range(edit, uri, ref.range.start_row, lsp_range)
					if existing then
						existing.newText = replacement
					else
						add_change(
							edit.changes,
							source_path,
							ref.range.start_row,
							ref.fragment_range,
							replacement,
							encoding,
							ref.source_line
						)
					end
				end
			end
		end
	end
	return edit
end

local function apply(edit, encoding)
	if not edit then
		return
	end
	vim.lsp.util.apply_workspace_edit(edit, encoding or "utf-8")
	vim.cmd("silent! wall")
end

local function input(prompt, default, callback)
	vim.ui.input({ prompt = prompt, default = default, scope = "cursor" }, function(value)
		if value and vim.trim(value) ~= "" then
			callback(value)
		end
	end)
end

local function choose(paths, prompt, callback)
	if #paths == 0 then
		notify("No se encontró el destino", vim.log.levels.ERROR)
	elseif #paths == 1 then
		callback(paths[1])
	else
		vim.ui.select(paths, { prompt = prompt }, callback)
	end
end

local function marksman_client(bufnr)
	return vim.lsp.get_clients({ bufnr = bufnr, name = "marksman" })[1]
end

local function rename_heading_at(location, root, old_anchor)
	local path = vim.uri_to_fname(location.uri)
	local bufnr = vim.fn.bufadd(path)
	vim.fn.bufload(bufnr)
	local client = marksman_client(vim.api.nvim_get_current_buf())
	if not client then
		return notify("Marksman no está conectado", vim.log.levels.ERROR)
	end
	vim.lsp.buf_attach_client(bufnr, client.id)
	local line = vim.api.nvim_buf_get_lines(bufnr, location.range.start.line, location.range.start.line + 1, false)[1]
		or ""
	local old_name = line:sub(location.range.start.character + 1, location.range["end"].character)
	local declared_heading = require("lzy.marksman.workspace").heading_at(path, location.range.start.line)
	old_anchor = old_anchor or declared_heading and declared_heading.anchor or old_name
	input("Nuevo heading: ", old_name, function(new_name)
		if new_name ~= vim.trim(new_name) then
			return notify("El heading no puede empezar ni terminar con espacios", vim.log.levels.ERROR)
		elseif new_name:find("[\r\n]") then
			return notify("El heading no puede contener saltos de línea", vim.log.levels.ERROR)
		elseif new_name:find("#", 1, true) then
			return notify("El heading no puede contener '#': separa el fragment", vim.log.levels.ERROR)
		elseif require("lzy.marksman.workspace").slug(new_name) == "" then
			return notify("El heading debe producir un fragment válido", vim.log.levels.ERROR)
		elseif new_name == old_name then
			return
		end
		local params = {
			textDocument = { uri = location.uri },
			position = location.range.start,
			newName = new_name,
		}
		client:request("textDocument/rename", params, function(err, edit)
			if err then
				return notify(err.message or tostring(err), vim.log.levels.ERROR)
			end
			apply(
				M.augment_heading_edit(
					edit,
					path,
					old_anchor,
					new_name,
					root,
					client.offset_encoding,
					location.range.start.line
				),
				client.offset_encoding
			)
		end, bufnr)
	end)
end

---@param ref table
---@param component table
---@param bufnr integer
---@return boolean
function M.link(ref, component, bufnr)
	local workspace = require("lzy.marksman.workspace")
	local root = workspace.root(bufnr)
	local source_path = vim.api.nvim_buf_get_name(bufnr)
	if not root or source_path == "" then
		return false
	end

	if component.kind == "label" or component.kind == "description" or component.kind == "url" then
		input("Nuevo texto: ", component.text, function(value)
			vim.api.nvim_buf_set_text(
				bufnr,
				ref.range.start_row,
				component.range.start_col,
				ref.range.start_row,
				component.range.end_col,
				{ value }
			)
		end)
		return true
	elseif component.kind == "reference_id" then
		vim.lsp.buf.rename(nil, { name = "marksman", bufnr = bufnr })
		return true
	end

	local definition = ref.kind == "reference_use" and ref.definition or ref
	if not definition or not definition.path then
		return false
	end
	local paths = workspace.resolve(definition.path, { source_path = source_path, root = root })
	choose(paths, "Elige la nota", function(path)
		if not path then
			return
		end
		if not workspace.is_markdown(path) then
			notify("El rename de adjuntos no está habilitado en Marksman", vim.log.levels.INFO)
			return
		end
		if component.kind == "note" then
			local stem = vim.fs.basename(path):gsub("%.[^%.]+$", "")
			input("Nuevo nombre de nota: ", stem, function(new_name)
				local ok, wall_err = pcall(vim.cmd.wall)
				if not ok then
					return notify(tostring(wall_err), vim.log.levels.ERROR)
				end
				local edit, err, count, ambiguous = M.note_edit(path, new_name, root)
				if not edit then
					return notify(err or "No se pudo renombrar la nota", vim.log.levels.ERROR)
				end
				apply(edit)
				local message = ("Nota renombrada; %d enlace(s) actualizado(s)"):format(count or 0)
				if ambiguous and ambiguous > 0 then
					message = message .. ("; %d enlace(s) ambiguo(s) sin tocar"):format(ambiguous)
				end
				notify(message)
			end)
		elseif component.kind == "heading" then
			local location = workspace.location(path, definition.fragment)
			if not location then
				return notify("No existe el heading enlazado", vim.log.levels.ERROR)
			end
			rename_heading_at(location, root, definition.fragment)
		end
	end)
	return true
end

---@param bufnr integer
---@return boolean
function M.heading_declaration(bufnr)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local heading = vim.iter(require("lzy.marksman.workspace").headings(lines)):find(function(value)
		return value.row == row - 1
	end)
	if not heading then
		return false
	end
	if col < heading.start_col or col > heading.end_col then
		return false
	end
	local root = require("lzy.marksman.workspace").root(bufnr)
	if not root then
		return false
	end
	rename_heading_at({
		uri = vim.uri_from_bufnr(bufnr),
		range = {
			start = { line = row - 1, character = heading.start_col },
			["end"] = { line = row - 1, character = heading.end_col },
		},
	}, root, heading.anchor)
	return true
end

---@param bufnr integer
function M.current_note(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	local root = require("lzy.marksman.workspace").root(bufnr)
	if not root or path == "" or not require("lzy.marksman.workspace").is_markdown(path) then
		return false
	end
	local stem = vim.fs.basename(path):gsub("%.[^%.]+$", "")
	input("Nuevo nombre de nota: ", stem, function(new_name)
		local ok, wall_err = pcall(vim.cmd.wall)
		if not ok then
			return notify(tostring(wall_err), vim.log.levels.ERROR)
		end
		local edit, err, count, ambiguous = M.note_edit(path, new_name, root)
		if not edit then
			return notify(err or "No se pudo renombrar la nota", vim.log.levels.ERROR)
		end
		apply(edit)
		local message = ("Nota renombrada; %d enlace(s) actualizado(s)"):format(count or 0)
		if ambiguous and ambiguous > 0 then
			message = message .. ("; %d enlace(s) ambiguo(s) sin tocar"):format(ambiguous)
		end
		notify(message)
	end)
	return true
end

return M
