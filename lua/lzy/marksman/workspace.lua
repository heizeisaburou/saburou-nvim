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
local files_cache = {}

---Invalida la lista cacheada de ficheros del proyecto. Lo llaman los flujos que
---crean notas, para que el diagnóstico no marque "no existe" una nota que
---acaba de aparecer.
---@param root string|nil sin argumento, invalida todo
function M.invalidate_files(root)
	if root == nil then
		files_cache = {}
		return
	end
	root = normalize(root)
	for key in pairs(files_cache) do
		if key:sub(1, #root) == root then
			files_cache[key] = nil
		end
	end
end

---@param root string
---@param opts { markdown?: boolean }|nil
---@return string[]
function M.files(root, opts)
	opts = opts or {}

	-- `resolve` llama aquí, y a `resolve` se le pregunta una vez por enlace: sin
	-- caché, diagnosticar una nota con veinte enlaces recorría el proyecto
	-- veinte veces. TTL corto, e invalidable para las altas (`invalidate_files`).
	local key = normalize(root) .. (opts.markdown and "\0md" or "\0all")
	local now = vim.uv.now()
	local cached = files_cache[key]
	if cached and now - cached.updated < 2000 then
		return cached.files
	end

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
	files_cache[key] = { updated = now, files = result }
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

	-- Rescate por slug, y sólo si no ha coincidido nada.
	--
	-- El servidor de marksman escribe los wikilinks en forma canónica: para
	-- `Espacios y mayús.md` inserta `[[espacios-y-mayús]]`, que no es el nombre
	-- de ningún fichero y por tanto no resolvía -- ni se podía seguir, ni
	-- crear. Aceptarlo al LEER es coherente con lo que ya hacemos con los
	-- anchors (`#Mi Heading` y `#mi-heading` resuelven igual) y desbloquea los
	-- enlaces que él mismo haya dejado escritos. Lo que insertamos nosotros
	-- sigue siendo el nombre legible.
	--
	-- Sólo para destinos desnudos: con carpeta, el sufijo ya es una coordenada
	-- y compararlo por slug abriría falsos positivos.
	if #result == 0 and not normalized_target:find("/", 1, true) then
		local wanted = M.slug((normalized_target:gsub("%.[^./]+$", "")))
		if wanted ~= "" then
			-- Sólo por nombre de fichero, nunca por título.
			--
			-- La identidad de una nota es su nombre (ver `wiki_name`), así que
			-- `[[una-nota]]` con un fichero llamado `Una nota nueva.md`
			-- sencillamente **no existe**, por mucho que su H1 diga `# Una nota`.
			-- Resolverlo por título daba por bueno un enlace que no nombra ningún
			-- fichero y escondía el desajuste en vez de enseñarlo.
			--
			-- Hubo una pasada por título aquí: la puse cuando `wiki_name` todavía
			-- slugificaba el H1 y escribíamos enlaces que no sabíamos releer. Al
			-- mover la identidad al nombre, esa incoherencia desapareció en su
			-- origen y la tolerancia se quedó sin motivo.
			for _, path in ipairs(M.files(root, { markdown = not opts.all_files })) do
				local stem = vim.fs.basename(path):gsub("%.[^./]+$", "")
				if M.slug(stem) == wanted then
					add_existing(result, seen, path, false)
				end
			end
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
	-- Implementación compartida: los dos motores escriben el mismo ancla para
	-- el mismo heading. Ver lzy.link_target.slug.
	return require("lzy.link_target").slug(fragment)
end

local style_cache = {}

---El estilo con que ESTE proyecto escribe los wikilinks.
---
---`.marksman.toml` es la declaración de estilo del proyecto, así que manda
---sobre todos los que escriben en él, nosotros incluidos:
---
---    [completion.wiki]
---    style = "file-stem"     -> [[Mi nota]]
---    style = "title-slug"    -> [[mi-nota]]
---
---Sin declararlo, marksman usa `title-slug` (medido contra el servidor). Antes
---escribíamos siempre verbatim, así que en un proyecto sin configurar el linter
---del servidor proponía `[[mi-nota]]` y nuestro rename dejaba `[[Mi nota]]`: el
---mismo buffer con dos formas.
---
---El lector es deliberadamente mínimo -- una sola clave, no un parser TOML --,
---así que no entiende comentarios raros ni sintaxis exótica. Si no la reconoce,
---cae al default, que es el del servidor.
---@param root string
---@return "file-stem"|"title-slug"
function M.wiki_style(root)
	root = normalize(root)
	local now = vim.uv.now()
	local cached = style_cache[root]
	if cached and now - cached.updated < 2000 then
		return cached.style
	end

	local style = "title-slug"
	local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(root, ".marksman.toml"))
	if ok then
		local in_section = false
		for _, line in ipairs(lines) do
			local section = line:match("^%s*%[([^%]]+)%]")
			if section then
				in_section = vim.trim(section) == "completion.wiki"
			elseif in_section then
				local value = line:match('^%s*style%s*=%s*"([^"]+)"')
					or line:match("^%s*style%s*=%s*'([^']+)'")
				if value == "file-stem" then
					style = value
					break
				elseif value == "title-slug" or value == "file-path" then
					-- Los dos nombres que se han visto para el estilo por defecto.
					style = "title-slug"
					break
				end
			end
		end
	end

	style_cache[root] = { updated = now, style = style }
	return style
end

---El nombre con el que este proyecto escribe un wikilink a `path`.
---
---El estilo decide la **forma** —`Mi nota` o `mi-nota`— pero la identidad es
---siempre el **nombre del fichero completo**, nunca una derivada del título.
---
---Marksman, con `title-slug`, slugifica el título (el H1). Nosotros no, y es
---deliberado: el título es un identificador con fugas.
---
---  * **Es lossy.** Una nota `matematicas-aritmetica.md` encabezada
---    `# Matematicas` se enlazaría como `[[matematicas]]`, que dice menos que
---    el nombre y se vuelve ambiguo en cuanto aparece otra nota de matemáticas.
---  * **No es único.** Dos guías con `# Introducción` dan el mismo destino, y
---    ni añadir la carpeta las separa si comparten carpeta. Los nombres de
---    fichero sí son únicos: lo garantiza el sistema de ficheros.
---  * **No es estable.** Editar el H1 cambiaría en silencio la forma canónica
---    de todos los enlaces que apuntan a esa nota.
---
---Cuando el H1 coincide con el nombre —lo normal, y lo que asume
---`title_from_heading`— las dos definiciones dan lo mismo y no hay divergencia.
---Sólo se separan en notas cuyo H1 ya discrepa de su propio nombre.
---@param path string
---@param root string
---@return string
function M.wiki_name(path, root)
	local stem = vim.fs.basename(path):gsub("%.[^./]+$", "")
	if M.wiki_style(root) == "file-stem" then
		return stem
	end
	return M.slug(stem)
end

---La forma canónica del destino a `path`, en la sintaxis que lo va a alojar.
---
---Único sitio donde se decide esto. Antes lo calculaban por su cuenta el
---rename, el reapuntado al crear y el completado, y de ahí salieron varias
---divergencias seguidas.
---
---  wiki      el nombre en el estilo del proyecto (`wiki_name`), ampliado con
---            la carpeta si ese nombre no es inequívoco
---  markdown  ruta desde la raíz, escapada y con extensión: la resuelve GitHub
---            siguiendo la ruta literal, no buscando
---@param path string
---@param root string
---@param kind string|nil `ref.kind`
---@param source_path string|nil desde dónde se enlaza (para desambiguar)
---@return string|nil
function M.canonical_target(path, root, kind, source_path)
	local relative = vim.fs.relpath(normalize(root), normalize(path))
	if not relative then
		return nil
	end
	if kind ~= "wiki" then
		return "/" .. require("lzy.link_target").encode(relative)
	end

	-- Ida y vuelta: una forma sólo es canónica si vuelve a resolver a ESTE
	-- fichero y a ninguno más.
	--
	-- Con `title-slug` la identidad es el título, y los títulos **no son
	-- únicos**: dos notas distintas de la misma carpeta con el mismo H1 dan el
	-- mismo destino, y ni añadir la carpeta lo separa. Sin esta comprobación,
	-- canonizar convertía dos enlaces que funcionaban en uno ambiguo -- rompía
	-- justo lo que venía a arreglar. Cuando no hay forma inequívoca se devuelve
	-- nil y quien llama deja el enlace como está.
	local name = M.wiki_name(path, root)
	local wanted = normalize(path)
	local function unique_to_us(candidate)
		local matches = M.resolve(candidate, { source_path = source_path or path, root = root })
		return #matches == 1 and normalize(matches[1]) == wanted
	end

	if unique_to_us(name) then
		return name
	end
	local dir = vim.fs.dirname(relative)
	local qualified = "/" .. (dir == "." and name or dir .. "/" .. name)
	if unique_to_us(qualified) then
		return qualified
	end
	return nil
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
