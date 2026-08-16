-- Índice y resolución de paths con las mismas coordenadas que Marksman.

local M = {}

-- Compartida con la completion de obsidian: qué cuenta como nota es la misma
-- pregunta en los dos lados. Ver lzy.link_target.
local MARKDOWN_EXTENSIONS = require("lzy.link_target").MARKDOWN_EXTENSIONS

local SKIP_DIRECTORIES = {
	[".git"] = true,
	[".hg"] = true,
	[".svn"] = true,
	["node_modules"] = true,
}

local function normalize(path)
	return vim.fs.normalize(path)
end

local function is_file(path)
	local stat = vim.uv.fs_stat(path)
	return stat and stat.type == "file"
end

local function extension(path)
	return path:match("%.([^./\\]+)$")
end

local function is_markdown(path)
	local ext = extension(path)
	return ext and MARKDOWN_EXTENSIONS[ext:lower()] or false
end

---Compartido con la completion de obsidian: ver lzy.link_target.
---@param path string
---@param from_dir string
---@return string
function M.relative(path, from_dir)
	return require("lzy.link_target").relative(path, from_dir)
end

---@param bufnr integer|nil
---@return string|nil
function M.root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "marksman" })) do
		local root = client.root_dir
			or client.config and client.config.root_dir
			or client.workspace_folders
				and client.workspace_folders[1]
				and vim.uri_to_fname(client.workspace_folders[1].uri)
		if root and root ~= "" then
			return normalize(root)
		end
	end
	return vim.fs.root(bufnr, { ".marksman.toml", ".git" })
end

---@param root string
---@param opts { markdown?: boolean }|nil
---@return string[]
function M.files(root, opts)
	opts = opts or {}
	local result = {}
	for relative, kind in
		vim.fs.dir(root, {
			depth = 100,
			skip = function(dir)
				return not SKIP_DIRECTORIES[vim.fs.basename(dir)]
			end,
		})
	do
		local path = normalize(vim.fs.joinpath(root, relative))
		if kind == "file" and (not opts.markdown or is_markdown(path)) then
			result[#result + 1] = path
		end
	end
	table.sort(result)
	return result
end

local function add_existing(result, seen, path, allow_extension)
	local candidates = { path }
	if allow_extension and not extension(path) then
		for ext in pairs(MARKDOWN_EXTENSIONS) do
			candidates[#candidates + 1] = path .. "." .. ext
		end
	end
	for _, candidate in ipairs(candidates) do
		candidate = normalize(candidate)
		if not seen[candidate] and is_file(candidate) then
			seen[candidate] = true
			result[#result + 1] = candidate
		end
	end
end

---@param target string
---@param opts { source_path: string, root: string, markdown?: boolean, all_files?: boolean }
---@return string[]
function M.resolve(target, opts)
	target = vim.trim(target or "")
	if target:match("^[%a][%w+.-]*:") and not target:match("^%a:[/\\]") then
		return {}
	end
	target = target:gsub("#.*$", "")
	target = vim.uri_decode(target) or target
	if target == "" then
		return { normalize(opts.source_path) }
	end

	local root = normalize(opts.root)
	local source_dir = vim.fs.dirname(normalize(opts.source_path))
	local result, seen = {}, {}
	local allow_extension = opts.markdown ~= false

	-- CommonMark root-relative. A Windows drive remains an absolute system path.
	if target:match("^%a:[/\\]") then
		add_existing(result, seen, target, allow_extension)
		return result
	elseif vim.startswith(target, "/") then
		add_existing(result, seen, vim.fs.joinpath(root, target:sub(2)), allow_extension)
		if #result == 0 then
			-- La barra es ambigua a propósito (ver lzy.link_target): la completion
			-- ofrece carpetas de las dos raíces, así que un destino que no cuelga
			-- del proyecto se prueba como ruta absoluta del sistema.
			add_existing(result, seen, target, allow_extension)
		end
		return result
	elseif vim.startswith(target, "./") or vim.startswith(target, "../") then
		add_existing(result, seen, vim.fs.joinpath(source_dir, target), allow_extension)
		return result
	end

	-- Los destinos desnudos son búsquedas de workspace en Marksman. Incluimos
	-- los exactos local/root y todos los suffix matches para conservar la
	-- ambigüedad en vez de elegir silenciosamente el vecino.
	add_existing(result, seen, vim.fs.joinpath(source_dir, target), allow_extension)
	add_existing(result, seen, vim.fs.joinpath(root, target), allow_extension)

	local normalized_target = normalize(target):gsub("^%./", "")
	local target_ext = extension(normalized_target)
	for _, path in ipairs(M.files(root, { markdown = not opts.all_files })) do
		local relative = assert(vim.fs.relpath(root, path))
		local matches
		if target_ext then
			matches = relative == normalized_target
				or vim.endswith(relative, "/" .. normalized_target)
				or vim.fs.basename(relative) == normalized_target
		else
			local without_ext = relative:gsub("%.[^./]+$", "")
			matches = without_ext == normalized_target
				or vim.endswith(without_ext, "/" .. normalized_target)
				or vim.fs.basename(without_ext) == normalized_target
		end
		if matches then
			add_existing(result, seen, path, false)
		end
	end
	table.sort(result)
	return result
end

---@param path string
---@return boolean
function M.is_markdown(path)
	return is_markdown(path)
end

---@param fragment string
---@return string
function M.slug(fragment)
	fragment = vim.fn.tolower(vim.trim(fragment))
	local result = {}
	for _, char in ipairs(vim.fn.split(fragment, "\\zs")) do
		if char == " " or char == "_" or vim.fn.matchstr(char, [[\s]]) == char then
			result[#result + 1] = "-"
		elseif char == "-" or vim.fn.matchstr(char, [[\k]]) == char then
			result[#result + 1] = char
		end
	end
	local slug = table.concat(result):gsub("%-+", "-"):gsub("^%-", "")
	slug = slug:gsub("%-$", "")
	return slug
end

---@param lines string[]
---@return table[]
function M.headings(lines)
	local candidates = {}
	-- El parser necesita el EOF lógico tras una underline Setext final.
	local text = table.concat(lines, "\n") .. "\n"
	local ok, parser = pcall(vim.treesitter.get_string_parser, text, "markdown")
	local tree = ok and parser:parse()[1] or nil
	if tree then
		local function walk(node)
			local kind = node:type()
			if kind == "atx_heading" or kind == "setext_heading" then
				local inline, level
				for child in node:iter_children() do
					local child_kind = child:type()
					if child_kind == "inline" then
						inline = child
					elseif child_kind == "paragraph" then
						for nested in child:iter_children() do
							if nested:type() == "inline" then
								inline = nested
								break
							end
						end
					end
					level = level
						or tonumber(child_kind:match("^atx_h(%d)_marker$"))
						or tonumber(child_kind:match("^setext_h(%d)_underline$"))
				end
				if inline and level then
					local start_row, start_col, end_row = inline:range()
					-- Los Setext multilínea siguen en manos de Marksman; el adaptador
					-- solo necesita indexar con precisión el caso de una línea.
					if start_row == end_row then
						local heading = vim.treesitter.get_node_text(inline, text):gsub("%s+#+%s*$", "")
						candidates[#candidates + 1] = {
							row = start_row,
							level = level,
							text = heading,
							start_col = start_col,
							end_col = start_col + #heading,
							setext = kind == "setext_heading",
						}
					end
				end
				return
			end
			for child in node:iter_children() do
				if child:named() then
					walk(child)
				end
			end
		end
		walk(tree:root())
	else
		-- Fallback mínimo para instalaciones donde el parser aún no esté listo.
		-- En la configuración normal Treesitter está instalado antes de Marksman.
		for idx, line in ipairs(lines) do
			local hashes, heading = line:match("^%s*(#+)%s+(.+)%s*$")
			local setext = not hashes
				and lines[idx + 1]
				and lines[idx + 1]:match("^%s*[=-]+%s*$")
				and not line:match("^%s*$")
			if setext then
				hashes, heading = lines[idx + 1]:find("=") and "#" or "##", vim.trim(line)
			end
			if hashes then
				heading = heading:gsub("%s+#+%s*$", "")
				candidates[#candidates + 1] = {
					row = idx - 1,
					level = #hashes,
					text = heading,
					start_col = assert(line:find(heading, 1, true)) - 1,
					end_col = assert(line:find(heading, 1, true)) - 1 + #heading,
					setext = setext and true or false,
				}
			end
		end
	end

	table.sort(candidates, function(left, right)
		return left.row < right.row
	end)
	local result, counts = {}, {}
	for _, heading in ipairs(candidates) do
		local base = M.slug(heading.text)
		local duplicate = counts[base] or 0
		counts[base] = duplicate + 1
		heading.anchor = duplicate == 0 and base or (base .. "-" .. duplicate)
		result[#result + 1] = heading
	end
	return result
end

---@param path string
---@param row integer
---@return table|nil
function M.heading_at(path, row)
	for _, heading in ipairs(M.headings(vim.fn.readfile(path))) do
		if heading.row == row then
			return heading
		end
	end
end

---@param path string
---@param row integer
---@param new_name string
---@return string
function M.renamed_anchor(path, row, new_name)
	local base, duplicate = M.slug(new_name), 0
	for _, heading in ipairs(M.headings(vim.fn.readfile(path))) do
		if heading.row >= row then
			break
		elseif M.slug(heading.text) == base then
			duplicate = duplicate + 1
		end
	end
	return duplicate == 0 and base or (base .. "-" .. duplicate)
end

---@param path string
---@param fragment string|nil
---@return lsp.Location|nil
function M.location(path, fragment)
	local row, start_col, end_col = 0, 0, 0
	if fragment and fragment ~= "" then
		local wanted = M.slug(vim.uri_decode(fragment) or fragment)
		local lines = vim.fn.readfile(path)
		local found = false
		for _, heading in ipairs(M.headings(lines)) do
			if heading.anchor == wanted then
				row = heading.row
				start_col = heading.start_col
				end_col = heading.end_col
				found = true
				break
			end
		end
		if not found then
			return nil
		end
	end
	return {
		uri = vim.uri_from_fname(path),
		range = {
			start = { line = row, character = start_col },
			["end"] = { line = row, character = end_col },
		},
	}
end

return M
