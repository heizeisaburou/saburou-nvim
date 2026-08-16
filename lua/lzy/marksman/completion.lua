local M = {}
local cache = {}

local function has_marksman(bufnr)
	return #vim.lsp.get_clients({ bufnr = bufnr, name = "marksman" }) > 0
end

local function project_notes(root)
	local now = vim.uv.now()
	local current = cache[root]
	if not current or now - current.updated > 2000 then
		current = {
			updated = now,
			files = require("lzy.marksman.workspace").files(root, { markdown = true }),
		}
		cache[root] = current
	end
	return current.files
end

local function context(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local line = lines[row + 1] or ""
	local parser = require("lzy.marksman.parser")
	local excluded = parser.excluded_rows(lines)
	if excluded[row] then
		return nil
	end
	local ref = parser.at(lines, row, math.max(col - 1, 0))
	if ref and (ref.kind == "inline" or ref.kind == "wiki") and ref.path_range then
		if col >= ref.path_range.start_col and col <= ref.path_range.end_col then
			return {
				row = row,
				col = col,
				line = line,
				kind = ref.kind,
				range = ref.path_range,
				query = line:sub(ref.path_range.start_col + 1, col),
			}
		end
	end
	local definition = parser.definition(line, row)
	if definition and col >= definition.path_range.start_col and col <= definition.path_range.end_col then
		return {
			row = row,
			col = col,
			line = line,
			kind = definition.kind,
			range = definition.path_range,
			query = line:sub(definition.path_range.start_col + 1, col),
		}
	end

	-- Treesitter no produce todavía un nodo para `[[/` ni `[texto](/`.
	-- Reconocemos solo el destino incompleto que termina bajo el cursor; los
	-- delimitadores siguen fuera del textEdit y cmp puede completarlo sin
	-- convertir el enlace en texto visible.
	local prefix = line:sub(1, col)
	local wiki_open = prefix:match(".*()%[%[")
	if wiki_open then
		local query = prefix:sub(wiki_open + 2)
		if not query:find("[]|#%s]") then
			return {
				row = row,
				col = col,
				line = line,
				kind = "wiki",
				range = { start_col = wiki_open + 1, end_col = col },
				query = query,
			}
		end
	end

	local inline_open = prefix:match(".*()%]%(")
	if inline_open then
		local query = prefix:sub(inline_open + 2)
		if not query:find("[%)#%s]") then
			return {
				row = row,
				col = col,
				line = line,
				kind = "inline",
				range = { start_col = inline_open + 1, end_col = col },
				query = query,
			}
		end
	end
end

function M.source()
	local source = {}

	function source:is_available()
		local bufnr = vim.api.nvim_get_current_buf()
		return vim.bo[bufnr].filetype:match("^markdown") ~= nil and has_marksman(bufnr)
	end

	function source:get_trigger_characters()
		return { "/", "." }
	end

	function source:get_position_encoding_kind()
		return "utf-8"
	end

	function source:complete(_, callback)
		local bufnr = vim.api.nvim_get_current_buf()
		local ctx = context(bufnr)
		if not ctx then
			return callback({ isIncomplete = false, items = {} })
		end
		local root = require("lzy.marksman.workspace").root(bufnr)
		local source_path = vim.api.nvim_buf_get_name(bufnr)
		if not root or source_path == "" then
			return callback({ isIncomplete = false, items = {} })
		end

		local coord = require("lzy.link_target")
		local query = vim.uri_decode(ctx.query) or ctx.query
		local needle = vim.fn.tolower(coord.needle(query))
		-- Una coordenada explícita ya expresa intención suficiente. En concreto,
		-- `/` debe listar las notas de la raíz inmediatamente, no dejar visibles
		-- únicamente los directorios que devuelve la completion nativa.
		if not coord.is_explicit(query) and #vim.fs.basename(needle):gsub("%.md$", "") < 2 then
			return callback({ isIncomplete = true, items = {} })
		end

		local source_dir = vim.fs.dirname(source_path)
		local items = {}
		local function range()
			return {
				start = { line = ctx.row, character = ctx.range.start_col },
				["end"] = { line = ctx.row, character = ctx.range.end_col },
			}
		end

		-- Una carpeta no es destino, pero es el camino: sin ella `[[/` no ofrece
		-- nada hasta acertar a ciegas el nombre del archivo. Las notas del nivel
		-- ya las pone el índice del proyecto, más abajo.
		for _, dir in ipairs(coord.entries(query, root)) do
			local target = coord.encode(dir.target)
			items[#items + 1] = {
				label = target,
				filterText = target,
				detail = dir.scope == "system" and "Carpeta del sistema" or "Carpeta del proyecto",
				kind = vim.lsp.protocol.CompletionItemKind.Folder,
				textEdit = { newText = target, range = range() },
			}
		end

		for _, path in ipairs(project_notes(root)) do
			local root_relative = assert(vim.fs.relpath(root, path))
			local searchable = vim.fn.tolower(root_relative)
			if searchable:find(needle, 1, true) then
				local target
				if coord.coordinate(query) == coord.NOTE_RELATIVE then
					target = coord.note_relative(path, source_dir, query)
				else
					target = "/" .. root_relative
				end
				if target then
					target = coord.encode(target)
					items[#items + 1] = {
						label = target,
						-- Debe hablar el idioma de la coordenada tecleada: filtrar
						-- `/docs` contra `docs/api.md` da score 0 en cmp y el item
						-- desaparece, que es el síntoma de "empezar por / no hace nada".
						filterText = coord.filter_text(query, target, root_relative),
						detail = "Nota del proyecto Marksman",
						kind = vim.lsp.protocol.CompletionItemKind.File,
						textEdit = { newText = target, range = range() },
					}
				end
			end
		end
		callback({ isIncomplete = true, items = items })
	end

	return source
end

return M
