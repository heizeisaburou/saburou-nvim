local M = {}

local function is_external(path)
	return path:match("^[%a][%w+.-]*:") and not path:match("^%a:[/\\]")
end

local function context(bufnr)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local ref = require("lzy.marksman.parser").at(lines, row - 1, col)
	return ref, ref and require("lzy.marksman.parser").component(ref, col) or nil
end

local function definition(ref)
	return ref.kind == "reference_use" and ref.definition or ref
end

local function resolved_paths(ref, bufnr)
	local declared = definition(ref)
	if not declared or not declared.path then
		return {}, nil, nil
	end
	local workspace = require("lzy.marksman.workspace")
	local root = workspace.root(bufnr)
	local source_path = vim.api.nvim_buf_get_name(bufnr)
	if not root or source_path == "" then
		return {}, nil, nil
	end
	return workspace.resolve(declared.path, { source_path = source_path, root = root }), declared, root
end

local function choose(paths, prompt, callback)
	if #paths == 1 then
		callback(paths[1])
	elseif #paths > 1 then
		vim.ui.select(paths, { prompt = prompt }, callback)
	else
		vim.notify("No se encontró la nota enlazada", vim.log.levels.INFO, { title = "Marksman" })
	end
end

local function open_resolved(path, declared)
	local workspace = require("lzy.marksman.workspace")
	if not workspace.is_markdown(path) then
		return require("sabunv.nvim.file_opener").open_path(path, { title = "Marksman" })
	end
	local location = workspace.location(path, declared.fragment)
	if not location and declared.fragment then
		vim.notify(
			("No existe el heading '%s'; abriendo la nota"):format(declared.fragment),
			vim.log.levels.ERROR,
			{ title = "Marksman" }
		)
		location = workspace.location(path)
	end
	if location then
		vim.lsp.util.show_document(location, "utf-8", { focus = true })
		return true
	end
	return false
end

function M.hover()
	local bufnr = vim.api.nvim_get_current_buf()
	local ref = context(bufnr)
	-- Marksman devuelve `"\n"` como hover de una nota vacía. Neovim 0.12 lo
	-- acepta antes de normalizarlo, termina con un preview de ancho cero y
	-- `nvim_open_win()` falla. Todas las formas de nota local pasan por el
	-- mismo renderer, no solo las referencias CommonMark.
	if ref then
		local paths, declared = resolved_paths(ref, bufnr)
		if declared and declared.path and not is_external(declared.path) then
			choose(paths, "Elige la nota para el hover", function(path)
				if not path then
					return
				end
				if not require("lzy.marksman.workspace").is_markdown(path) then
					vim.notify("Los adjuntos no tienen preview; usa gx", vim.log.levels.INFO, {
						title = "Marksman",
					})
					return
				end
				local rendered = require("lzy.marksman.preview").render(path, declared.fragment)
				if rendered then
					require("lzy.marksman.preview").open(rendered)
				end
			end)
			return
		end
	end
	vim.lsp.buf.hover()
end

function M.definition()
	local bufnr = vim.api.nvim_get_current_buf()
	local ref, component = context(bufnr)
	if ref and ref.kind ~= "reference_use" and component then
		-- En un uso, `gd` conserva la semántica de Marksman y salta a la
		-- declaración. Ya dentro de la declaración, cualquiera de sus partes de
		-- identidad (id, destino o fragmento) sigue el destino de la definición.
		if component.kind == "reference_id" or component.kind == "note" or component.kind == "heading" then
			local paths, declared = resolved_paths(ref, bufnr)
			local has_attachment = false
			for _, path in ipairs(paths) do
				if not require("lzy.marksman.workspace").is_markdown(path) then
					has_attachment = true
					break
				end
			end
			-- Para notas inline/wiki conservamos la navegación nativa de Marksman.
			-- Las definiciones CommonMark las completamos nosotros; cualquier
			-- adjunto, venga de la forma que venga, usa el opener común.
			if declared and (ref.kind == "reference_definition" or has_attachment) then
				choose(paths, "Elige la definición", function(path)
					if not path then
						return
					end
					open_resolved(path, declared)
				end)
				return
			end
		end
	end
	vim.lsp.buf.definition()
end

---Sigue siempre el destino final: los usos CommonMark atraviesan su
---declaración, las notas respetan headings y los adjuntos usan el mismo opener
---content-aware que gx/gd.
function M.follow()
	local bufnr = vim.api.nvim_get_current_buf()
	local ref = context(bufnr)
	if ref then
		local declared = definition(ref)
		if declared and declared.raw_target and is_external(declared.raw_target) then
			return require("sabunv.nvim.file_opener").open_external(declared.raw_target, { title = "Marksman" })
		end
		local paths
		paths, declared = resolved_paths(ref, bufnr)
		if declared then
			-- Nada que abrir: si el destino es una nota que todavía no existe, se
			-- ofrece crearla en vez de quedarse en un aviso. El fichero se llama
			-- igual que el enlace, así que cualquier otro `[[Nombre]]` del
			-- proyecto resuelve solo en cuanto exista.
			if #paths == 0 and declared.path and declared.path ~= "" and not is_external(declared.path) then
				local root = require("lzy.marksman.workspace").root(bufnr)
				local source_path = vim.api.nvim_buf_get_name(bufnr)
				if root and source_path ~= "" then
					local created, renamed = require("lzy.marksman.new_note").create(declared.path, {
						source_path = source_path,
						root = root,
					})
					if created and renamed then
						M.repoint(bufnr, declared, created, root)
					end
					return created ~= nil
				end
			end
			choose(paths, "Elige el destino", function(path)
				if path then
					open_resolved(path, declared)
				end
			end)
			return true
		end
	end

	-- Completa el único caso que no representa nuestro parser estructural:
	-- autolinks como <https://example.com>.
	local cursor = vim.api.nvim_win_get_cursor(0)
	local markdown = require("sabunv.nvim.markdown")
	local target = markdown.ref_target(bufnr, cursor[1], cursor[2])
	if target and markdown.open(target, { bufnr = bufnr }) then
		return true
	end
	vim.notify("No hay ningún enlace bajo el cursor", vim.log.levels.INFO, { title = "Marksman" })
	return false
end

---Reapunta un enlace al fichero que se acaba de crear con otro nombre.
---
---Si al crear cambias el nombre, el fichero deja de llamarse como el enlace y
---éste se queda señalando a nada. Se reescribe **sólo el destino**: la etiqueta
---y el alias son texto del autor y no se tocan.
---
---Cada sintaxis recibe su forma canónica, que no es la misma: `[[Mi nota]]` con
---el espacio literal, `/Mi%20nota.md` escapado y con extensión.
---@param bufnr integer
---@param ref table el ref cuyo `path_range` se reescribe
---@param path string el fichero creado
---@param root string
function M.repoint(bufnr, ref, path, root)
	if not ref.path_range or not ref.range then
		return
	end
	local workspace = require("lzy.marksman.workspace")
	local target = workspace.canonical_target(
		path,
		root,
		ref.kind,
		vim.api.nvim_buf_get_name(bufnr)
	)
	-- Entre ángulos el espacio no corta, así que va literal (misma regla que en
	-- lzy.marksman.rename): quien escribe `<...>` lo hace para no ver `%20`.
	if target and ref.angled then
		target = vim.uri_decode(target) or target
	end
	if not target or target == ref.path then
		return
	end
	vim.api.nvim_buf_set_text(
		bufnr,
		ref.range.start_row,
		ref.path_range.start_col,
		ref.range.start_row,
		ref.path_range.end_col,
		{ target }
	)
end

---¿Este diagnóstico del servidor habla de algo que ya juzgamos nosotros?
---
---Existir y ser ambiguo son las dos preguntas que los dos motores contestan, y
---las contestan distinto: marksman indexa por TÍTULO (su H1) y por nombre de
---fichero exacto; nosotros por nombre, sin distinguir caja, deshaciendo escapes
---y aceptando el slug. Ni su «no existe» es el nuestro (él marca en rojo
---`[[una-nota-nueva]]` cuando `Una nota nueva.md` lleva otro H1) ni su
---ambigüedad es la nuestra (dos notas encabezadas `# Una nota` le parecen el
---mismo destino aunque se llamen distinto).
---
---Así que su veredicto se filtra **entero**, no sólo cuando discrepamos. Antes
---se filtraba sólo el «no existe» que nosotros sí resolvíamos, y en los enlaces
---rotos de verdad coincidían los dos: dos avisos seguidos, con dos redacciones,
---sobre el mismo `[Git](/docs/Gi.md)`. Nuestro criterio es el que manda aquí
---(ver lzy.marksman.diagnostics, que emite los suyos para exactamente los
---mismos enlaces), así que sobra la segunda voz.
---
---Lo demás pasa tal cual, empezando por «non-existent heading»: de los anchors
---no decimos nada, y ahí el suyo es el único aviso que hay.
---@param diagnostic lsp.Diagnostic
---@return boolean
local function superseded(diagnostic)
	local lowered = (diagnostic.message or ""):lower()
	return lowered:find("non%-existent document") ~= nil
		or lowered:find("ambiguous link to document") ~= nil
end

---Handler de diagnósticos de marksman: deja pasar todo menos los veredictos
---sobre destinos, que damos nosotros.
function M.publish_diagnostics(err, result, ctx, config)
	if result and type(result.diagnostics) == "table" then
		result.diagnostics = vim.tbl_filter(function(diagnostic)
			return not superseded(diagnostic)
		end, result.diagnostics)
	end
	return vim.lsp.handlers["textDocument/publishDiagnostics"](err, result, ctx, config)
end

M.superseded = superseded

local CHECKBOX_STATES = { " ", "x", "~", "!", ">" }

local function next_checkbox_state(current)
	for idx, state in ipairs(CHECKBOX_STATES) do
		if state == current then
			return CHECKBOX_STATES[idx % #CHECKBOX_STATES + 1]
		end
	end
	return CHECKBOX_STATES[1]
end

local function list_prefix(line)
	local indent, bullet, spaces, rest = line:match("^(%s*)([-+*])(%s+)(.*)$")
	if bullet then
		return indent .. bullet .. spaces, rest
	end
	local numbered_indent, number, delimiter, numbered_spaces, numbered_rest =
		line:match("^(%s*)(%d+)([.%)])(%s+)(.*)$")
	if number then
		return numbered_indent .. number .. delimiter .. numbered_spaces, numbered_rest
	end
end

function M.toggle_checkbox()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if require("lzy.marksman.parser").excluded_rows(lines)[row - 1] then
		return
	end
	local line = lines[row] or ""
	local prefix, rest = list_prefix(line)
	if prefix then
		local state, spaces, body = rest:match("^%[(.)%](%s*)(.*)$")
		if state then
			spaces = spaces == "" and body ~= "" and " " or spaces
			line = prefix .. "[" .. next_checkbox_state(state) .. "]" .. spaces .. body
		else
			line = prefix .. "[ ] " .. rest
		end
	else
		local indent = line:match("^(%s*)") or ""
		line = indent .. "- [ ] " .. line:sub(#indent + 1)
	end
	vim.api.nvim_buf_set_lines(bufnr, row - 1, row, true, { line })
end

local function frontmatter_row(lines, row)
	local delimiter = lines[1] == "---" and "---" or lines[1] == "+++" and "+++" or nil
	if not delimiter then
		return false
	end
	for idx = 2, #lines do
		if lines[idx] == delimiter then
			return row < idx
		end
	end
	return false
end

local function heading_row(lines, row)
	for _, heading in ipairs(require("lzy.marksman.workspace").headings(lines)) do
		if heading.row == row then
			return true
		end
	end
	return false
end

---Paridad funcional con `obsidian.actions.smart_action`: enlace, tag, fold,
---checkbox/lista/párrafo y, si nada aplica, Enter normal.
function M.smart_action()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local parser = require("lzy.marksman.parser")
	local excluded = parser.excluded_rows(lines)
	local ref = not excluded[row] and parser.at(lines, row, col) or nil
	local followable_ref = ref and (ref.kind ~= "reference_use" or ref.definition ~= nil)
	local autolink = not excluded[row] and require("sabunv.nvim.markdown").ref_target(bufnr, row + 1, col)
	if followable_ref or autolink then
		return "<cmd>lua require('lzy.marksman').follow()<CR>"
	elseif require("lzy.marksman.tags").at(bufnr, row, col) then
		return "<cmd>lua require('lzy.marksman.tags').open()<CR>"
	elseif heading_row(lines, row) or frontmatter_row(lines, row) then
		-- El folding Markdown es opt-in. Sin él, Enter conserva su acción
		-- normal y nunca convierte accidentalmente un heading en checkbox.
		if vim.g.markdown_folding == 1 or vim.wo.foldmethod == "expr" then
			return "za"
		end
		return "<CR>"
	elseif not excluded[row] then
		return "<cmd>lua require('lzy.marksman').toggle_checkbox()<CR>"
	end
	return "<CR>"
end

function M.backlinks()
	require("lzy.marksman.backlinks").open()
end

---Copia según lo que haya bajo el cursor. Misma implementación que en el vault:
---ver lzy.obsidian.smart_copy, que distingue el motor por su cuenta.
function M.smart_copy()
	require("lzy.obsidian.smart_copy").smart_copy()
end

function M.rename()
	local bufnr = vim.api.nvim_get_current_buf()
	if require("lzy.marksman.tags").rename_at(bufnr) then
		return
	end
	local ref, component = context(bufnr)
	local rename = require("lzy.marksman.rename")
	if ref and component and rename.link(ref, component, bufnr) then
		return
	end
	if rename.heading_declaration(bufnr) then
		return
	end
	-- Paridad con obsidian-ls: fuera de un símbolo concreto, rename actúa sobre
	-- la nota actual y no sobre una palabra arbitraria de prosa.
	if rename.current_note(bufnr) then
		return
	end
	vim.lsp.buf.rename(nil, { name = "marksman", bufnr = bufnr })
end

---@param _ vim.lsp.Client
---@param bufnr integer
function M.on_attach(_, bufnr)
	-- Su diagnóstico de enlaces rotos no cubre el nuestro: para él `[[una-nota]]`
	-- vale si algún H1 dice `# Una nota`, aunque no exista ningún fichero con ese
	-- nombre. Ver lzy.marksman.diagnostics.
	require("lzy.marksman.diagnostics").setup()
	require("lzy.marksman.diagnostics").schedule(bufnr)

	vim.keymap.set("n", "K", M.hover, {
		buffer = bufnr,
		desc = "Marksman: preview de la nota enlazada",
	})
	vim.keymap.set("n", "gd", M.definition, {
		buffer = bufnr,
		desc = "Marksman: ir a la definición",
	})
	vim.keymap.set("n", "<C-A-r>", M.rename, {
		buffer = bufnr,
		desc = "Marksman: renombrar componente",
	})
	vim.keymap.set("n", "<leader>nb", M.backlinks, {
		buffer = bufnr,
		desc = "Marksman: qué notas enlazan a esta",
	})
	vim.keymap.set("n", "<leader>nf", M.follow, {
		buffer = bufnr,
		desc = "Marksman: seguir el enlace bajo el cursor",
	})
	vim.keymap.set("n", "<leader>nx", M.toggle_checkbox, {
		buffer = bufnr,
		desc = "Marksman: toggle checkbox",
	})
	-- La copia inteligente no es cosa del vault: código, énfasis y componentes
	-- de enlace son iguales aquí. Lo único que cambia es qué se fabrica cuando
	-- no hay nada literal que copiar -- fuera de un vault, un enlace Markdown
	-- con etiqueta legible en vez de un wikilink. Lo decide smart_copy solo.
	vim.keymap.set("n", "<leader>ns", M.smart_copy, {
		buffer = bufnr,
		desc = "Marksman: copia inteligente (código/enlace/header)",
	})
	vim.keymap.set("n", "<CR>", M.smart_action, {
		expr = true,
		buffer = bufnr,
		desc = "Marksman Smart Action",
	})
	vim.api.nvim_buf_create_user_command(bufnr, "MarksmanBacklinks", M.backlinks, {
		desc = "Mostrar backlinks de la nota actual",
		force = true,
	})
	vim.api.nvim_buf_create_user_command(bufnr, "MarksmanFollowLink", M.follow, {
		desc = "Seguir el enlace bajo el cursor",
		force = true,
	})
	vim.api.nvim_buf_create_user_command(bufnr, "MarksmanRelink", function()
		require("lzy.marksman.relink").run({ bufnr = bufnr })
	end, {
		desc = "Llevar los enlaces del proyecto a la forma que declara su .marksman.toml",
		force = true,
	})
end

return M
