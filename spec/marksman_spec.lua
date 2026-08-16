local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Marksman adapter", function()
	local root

	local function write(relative, lines)
		local path = vim.fs.joinpath(root, relative)
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile(lines, path)
		return path
	end

	local function write_binary(relative, contents)
		local path = vim.fs.joinpath(root, relative)
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		local fd = assert(vim.uv.fs_open(path, "w", 420))
		assert(vim.uv.fs_write(fd, contents, 0))
		vim.uv.fs_close(fd)
		return path
	end

	before_each(function()
		root = vim.fn.tempname()
		vim.fn.mkdir(root, "p")
		write(".marksman.toml", { "[core]", "title_from_heading = true" })
	end)

	after_each(function()
		vim.fn.delete(root, "rf")
	end)

	it("separates every CommonMark reference component", function()
		local parser = require("lzy.marksman.parser")
		local line = '[definition]: /notes/other.md#my-heading "Description"'
		local ref = assert(parser.definition(line, 4))

		assert.are.equal("definition", ref.label)
		assert.are.equal("/notes/other.md", ref.path)
		assert.are.equal("my-heading", ref.fragment)
		assert.are.equal("Description", ref.title)
		assert.are.same({ start_col = 1, end_col = 11 }, ref.label_range)
		assert.are.same({ start_col = 14, end_col = 29 }, ref.path_range)
		assert.are.same({ start_col = 30, end_col = 40 }, ref.fragment_range)
		assert.are.same({ start_col = 42, end_col = 53 }, ref.title_range)

		assert.are.equal("reference_id", parser.component(ref, 2).kind)
		assert.are.equal("note", parser.component(ref, 15).kind)
		assert.are.equal("heading", parser.component(ref, ref.fragment_range.start_col - 1).kind)
		assert.are.equal("heading", parser.component(ref, 31).kind)
		assert.are.equal("description", parser.component(ref, 43).kind)
	end)

	it("parses inline, wiki and all three reference-use forms", function()
		local parser = require("lzy.marksman.parser")
		local links = parser.links('[Text](./note.md#head "Title") [[note#Head|Alias]] [Visible][id] [id][] [id]', 0)

		assert.are.equal(5, #links)
		assert.are.same({ "inline", "wiki", "reference_use", "reference_use", "reference_use" }, {
			links[1].kind,
			links[2].kind,
			links[3].kind,
			links[4].kind,
			links[5].kind,
		})
		assert.are.equal("./note.md", links[1].path)
		assert.are.equal("head", links[1].fragment)
		assert.are.equal("Alias", links[2].label)
		assert.are.equal("id", links[3].reference_id)
		assert.are.equal("collapsed", links[4].form)
		assert.are.equal("shortcut_link", links[5].form)

		local external = assert(parser.definition('[web]: https://example.com "Web"'))
		assert.are.equal("url", parser.component(external, 10).kind)
	end)

	it("matches Marksman's local, root and ambiguous path coordinates", function()
		local workspace = require("lzy.marksman.workspace")
		local source = write("notes/deep/source.md", { "# Source" })
		local root_only = write("root-only.md", { "# Root" })
		local local_only = write("notes/deep/local-only.md", { "# Local" })
		local root_duplicate = write("duplicate.md", { "# Root duplicate" })
		local local_duplicate = write("notes/deep/duplicate.md", { "# Local duplicate" })
		local other_duplicate = write("other/duplicate.md", { "# Other duplicate" })

		assert.are.same(
			{ root_only },
			workspace.resolve("/root-only.md", {
				root = root,
				source_path = source,
			})
		)
		assert.are.same(
			{},
			workspace.resolve("./root-only.md", {
				root = root,
				source_path = source,
			})
		)
		assert.are.same(
			{ local_only },
			workspace.resolve("./local-only.md", {
				root = root,
				source_path = source,
			})
		)
		assert.are.same(
			{ root_duplicate, local_duplicate, other_duplicate },
			workspace.resolve("duplicate.md", { root = root, source_path = source })
		)
		assert.are.same(
			{ root_duplicate },
			workspace.resolve("/duplicate.md", {
				root = root,
				source_path = source,
			})
		)
	end)

	it("renames a note without changing labels, fragments or path coordinates", function()
		local target = write("target.md", { "# Target", "", "## Old heading" })
		write("notes/source.md", {
			"[Root](/target.md)",
			"[Relative](../target.md#old-heading)",
			"[[/target#Old heading|Visible label]]",
			'[definition]: /target.md#old-heading "Description"',
			"[Use][definition]",
			"```markdown",
			"[Not a link](/target.md)",
			"```",
		})

		local edit, err, count = require("lzy.marksman.rename").note_edit(target, "renamed.md", root)
		assert.is_nil(err)
		assert.are.equal(4, count)

		local replacements, renamed
		replacements = {}
		for _, change in ipairs(edit.documentChanges) do
			if change.kind == "rename" then
				renamed = {
					old = vim.uri_to_fname(change.oldUri),
					new = vim.uri_to_fname(change.newUri),
				}
			else
				for _, text_edit in ipairs(change.edits) do
					assert.is_true(text_edit.range.start.character > 0)
					replacements[#replacements + 1] = text_edit.newText
				end
			end
		end
		table.sort(replacements)
		assert.are.same({ "../renamed.md", "/renamed", "/renamed.md", "/renamed.md" }, replacements)
		assert.are.same({ old = target, new = vim.fs.joinpath(root, "renamed.md") }, renamed)
	end)

	it("qualifies bare links when a renamed basename would become ambiguous", function()
		local target = write("notes/target.md", { "# Target" })
		write("other/renamed.md", { "# Existing homonym" })
		write("source.md", { "[Target](target.md)" })

		local edit = assert(require("lzy.marksman.rename").note_edit(target, "renamed", root))
		local replacement
		for _, change in ipairs(edit.documentChanges) do
			if change.textDocument then
				replacement = change.edits[1].newText
			end
		end
		assert.are.equal("/notes/renamed.md", replacement)
	end)

	it("qualifies a wikilink with the minimal suffix and a markdown link with the root path", function()
		-- Las dos sintaxis se desambiguan distinto a propósito: un `[[wiki]]` lo
		-- resuelve un motor que busca, así que le vale el sufijo mínimo; un
		-- destino Markdown lo resuelve GitHub siguiendo la ruta literal, donde un
		-- sufijo daría 404. Antes las dos salían con la ruta entera.
		local target = write("a/b/c/target.md", { "# Target" })
		write("x/y/z/renamed.md", { "# Homónimo" })
		write("source.md", { "[[target]]", "[W](target.md)" })

		local edit = assert(require("lzy.marksman.rename").note_edit(target, "renamed", root))
		local written = {}
		for _, change in ipairs(edit.documentChanges) do
			if change.textDocument then
				for _, single in ipairs(change.edits) do
					written[#written + 1] = single.newText
				end
			end
		end
		table.sort(written)

		assert.are.same({ "/a/b/c/renamed.md", "c/renamed" }, written)
	end)

	it("adds reference-definition fragments to Marksman's heading rename", function()
		local target = write("target.md", { "# Target", "", "## Old heading" })
		local source = write("source.md", {
			'[definition]: /target.md#old-heading "Description"',
			"[Inline](/target.md#old-heading)",
		})
		local uri = vim.uri_from_fname(source)
		local original = {
			changes = {
				[uri] = {
					{
						range = {
							start = { line = 1, character = 20 },
							["end"] = { line = 1, character = 31 },
						},
						newText = "new-heading",
					},
				},
			},
		}

		local edit =
			require("lzy.marksman.rename").augment_heading_edit(original, target, "Old heading", "New Heading", root)
		assert.are.equal(2, #edit.changes[uri])
		assert.are.equal("new-heading", edit.changes[uri][2].newText)
		assert.are.same({ line = 0, character = 25 }, edit.changes[uri][2].range.start)
	end)

	it("preserves encoded reference fragments during heading rename", function()
		local target = write("unicode-target.md", { "# Target", "", "## Old Café" })
		local source = write("unicode-source.md", {
			"[definition]: /unicode-target.md#old-caf%C3%A9",
		})
		local edit = require("lzy.marksman.rename").augment_heading_edit(
			{},
			target,
			"old-caf%C3%A9",
			"Nueva Sección",
			root,
			"utf-8",
			2
		)
		local changes = edit.changes[vim.uri_from_fname(source)]
		assert.are.equal(1, #changes)
		-- Se escapa lo que rompe el destino y nada más: la `ó` se queda legible
		-- en vez de convertirse en `%c3%b3`. Antes esto dependía de qué
		-- codificador te tocara (ver lzy.link_target.encode).
		assert.are.equal("nueva-sección", changes[1].newText)
	end)

	it("renames into a wikilink with literal spaces, and only escapes the Markdown one", function()
		-- Renombrar a "Espacios y mayús" dejaba `[[Espacios%20y%20mayús]]`: el
		-- escape es cosa del destino Markdown, donde el espacio corta el destino.
		-- Dentro de `[[...]]` no hay nada que cortar y el espacio va literal.
		local target = write("espacios-y-mayús.md", { "# vieja" })
		write("source.md", {
			"[[espacios-y-mayús]]",
			"[[/espacios-y-mayús]]",
			"[[espacios-y-mayús|como se lee]]",
			"[x](/espacios-y-may%C3%BAs.md)",
		})

		local edit = assert(
			require("lzy.marksman.rename").note_edit(target, "Espacios y mayús", root)
		)
		local written = {}
		for _, change in ipairs(edit.documentChanges) do
			if change.textDocument then
				for _, single in ipairs(change.edits) do
					written[#written + 1] = single.newText
				end
			end
		end
		table.sort(written)

		-- El `.marksman.toml` de estas pruebas no declara `completion.wiki.style`,
		-- así que manda el default de marksman: `title-slug`. Nosotros escribimos
		-- en el estilo del PROYECTO, no en el nuestro, para no dejar el buffer con
		-- las dos formas (la del linter del servidor y la nuestra).
		assert.are.same({
			"/Espacios%20y%20mayús.md", -- Markdown: escapado y con extensión
			"/espacios-y-mayús", -- wiki con barra: sin escapar
			"espacios-y-mayús", -- wiki desnudo
			"espacios-y-mayús", -- y el que lleva alias, que se conserva
		}, written)
	end)

	it("repoints the link when you create the note under a different name", function()
		-- El caso real: sigues un `[[mi-nota]]` que escribió el servidor en slug,
		-- lo creas como "Mi nota", y el enlace tiene que quedar apuntando ahí --
		-- en la forma de SU sintaxis, nunca con %20 dentro de `[[...]]`.
		write("source.md", {
			"Wiki [[mi-nota]] y con alias [[mi-nota|como se lee]].",
			"Markdown [x](mi-otra)",
		})
		local source = vim.fs.joinpath(root, "source.md")
		vim.cmd("edit! " .. vim.fn.fnameescape(source))
		local bufnr = vim.api.nvim_get_current_buf()
		local marksman = require("lzy.marksman")
		local new_note = require("lzy.marksman.new_note")

		local function create_and_repoint(row, col, name)
			vim.api.nvim_win_set_cursor(0, { row, col })
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local ref = assert(require("lzy.marksman.parser").at(lines, row - 1, col))
			local created, renamed = new_note.create(ref.path, {
				source_path = source,
				root = root,
				ask = function()
					return name
				end,
				open = function() end,
			})
			assert.is_true(renamed, "el nombre elegido difiere del que pedía el enlace")
			marksman.repoint(bufnr, ref, created, root)
		end

		create_and_repoint(1, 7, "Mi nota")
		create_and_repoint(2, 15, "Mi otra")

		assert.are.same({
			-- En el estilo del proyecto (slug por defecto), y el alias intacto.
			"Wiki [[mi-nota]] y con alias [[mi-nota|como se lee]].",
			-- El destino Markdown sí va escapado y con extensión.
			"Markdown [x](/Mi%20otra.md)",
		}, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
		assert.is_not_nil(vim.uv.fs_stat(vim.fs.joinpath(root, "Mi nota.md")))
	end)

	it("writes wikilinks in the style the project declares, not in ours", function()
		-- `.marksman.toml` es la declaración de estilo del proyecto y manda sobre
		-- todos los que escriben en él. Antes escribíamos siempre verbatim, así
		-- que en un proyecto con el default (`title-slug`) el linter del servidor
		-- proponía `[[mi-nota]]` y nuestro rename dejaba `[[Mi nota]]`.
		write(".marksman.toml", { "[core]", "title_from_heading = true", "[completion.wiki]", 'style = "file-stem"' })
		local workspace = require("lzy.marksman.workspace")
		assert.are.equal("file-stem", workspace.wiki_style(root))

		local target = write("vieja.md", { "# vieja" })
		write("source.md", { "[[vieja]]", "[W](/vieja.md)" })

		local edit = assert(require("lzy.marksman.rename").note_edit(target, "Espacios y mayús", root))
		local written = {}
		for _, change in ipairs(edit.documentChanges) do
			if change.textDocument then
				for _, single in ipairs(change.edits) do
					written[#written + 1] = single.newText
				end
			end
		end
		table.sort(written)

		assert.are.same({
			"/Espacios%20y%20mayús.md", -- Markdown: siempre escapado
			"Espacios y mayús", -- wiki: verbatim, porque el proyecto lo pide
		}, written)
	end)

	it("reads the wiki style from the project, defaulting to Marksman's own", function()
		local workspace = require("lzy.marksman.workspace")
		-- El spec escribe un `.marksman.toml` sin la clave: manda el default.
		assert.are.equal("title-slug", workspace.wiki_style(root))

		local note = write("Mi Nota.md", { "# Mi Nota" })
		assert.are.equal("mi-nota", workspace.wiki_name(note, root))
	end)

	describe("relink", function()
		local function apply(root_dir)
			local relink = require("lzy.marksman.relink")
			local plan = assert(relink.plan({ root = root_dir }))
			vim.lsp.util.apply_workspace_edit(relink.workspace_edit(plan), "utf-8")
			return plan
		end

		it("rewrites every link to the form the project declares", function()
			write(".marksman.toml", { "[core]", "title_from_heading = true", "[completion.wiki]", 'style = "file-stem"' })
			write("docs/Una nota nueva.md", { "# Una nota", "" })
			local source = write("source.md", {
				"[[una-nota-nueva]]", -- slug del nombre
				"[[una-nota]]", -- slug del TÍTULO: no nombra ningún fichero
				"[[una nota nueva|con alias]]", -- caja distinta, alias del autor
				"[W](docs/Una%20nota%20nueva.md)", -- relativo, no canónico
				"[[fantasma]]", -- no resuelve: intacto
				"[Web](https://ejemplo.com)", -- externo: intacto
			})
			vim.cmd("edit! " .. vim.fn.fnameescape(source))

			apply(root)

			assert.are.same({
				-- `file-stem`: el nombre del fichero, tal cual.
				"[[Una nota nueva]]",
				"[[una-nota]]", -- intacto: no resuelve, no se adivina
				"[[Una nota nueva|con alias]]",
				"[W](/docs/Una%20nota%20nueva.md)",
				"[[fantasma]]",
				"[Web](https://ejemplo.com)",
			}, vim.api.nvim_buf_get_lines(0, 0, -1, false))
		end)

		it("follows the slug style when the project asks for it", function()
			-- El spec escribe un `.marksman.toml` sin la clave: manda `title-slug`,
			-- que slugifica el TÍTULO -- por eso sale `una-nota` y no el nombre.
			write("docs/Una nota nueva.md", { "# Una nota", "" })
			local source = write("source.md", { "[[Una nota nueva]]", "[[una-nota-nueva]]" })
			vim.cmd("edit! " .. vim.fn.fnameescape(source))

			apply(root)

			-- El estilo decide la FORMA (guiones), pero la identidad sigue siendo
			-- el nombre completo del fichero, no una derivada del título.
			assert.are.same(
				{ "[[una-nota-nueva]]", "[[una-nota-nueva]]" },
				vim.api.nvim_buf_get_lines(0, 0, -1, false)
			)
		end)

		it("never rewrites a working link into an ambiguous one", function()
			-- Con `title-slug` la identidad es el TÍTULO, y los títulos no son
			-- únicos: dos notas de la misma carpeta con el mismo H1 dan el mismo
			-- destino, y ni añadir la carpeta las separa. Sin la comprobación de
			-- ida y vuelta, canonizar convertía dos enlaces que funcionaban en uno
			-- ambiguo -- rompía justo lo que venía a arreglar.
			-- Dos nombres distintos que slugifican igual: el sistema de ficheros los
			-- distingue, pero `title-slug` no puede representarlos por separado --
			-- y añadir la carpeta tampoco, porque comparten carpeta.
			write("docs/Mi Nota.md", { "# Una" })
			write("docs/mi-nota.md", { "# Otra" })
			write("docs/Otra cosa.md", { "# Tercera" })
			local source = write("source.md", { "[[Mi Nota]]", "[[Otra cosa]]" })
			vim.cmd("edit! " .. vim.fn.fnameescape(source))

			local workspace = require("lzy.marksman.workspace")
			assert.is_nil(
				workspace.canonical_target(vim.fs.joinpath(root, "docs/Mi Nota.md"), root, "wiki", source),
				"sin forma inequívoca, no se propone ninguna"
			)
			assert.are.equal(
				"otra-cosa",
				workspace.canonical_target(vim.fs.joinpath(root, "docs/Otra cosa.md"), root, "wiki", source)
			)

			apply(root)
			assert.are.same({
				"[[Mi Nota]]", -- intacto: canonizarlo lo volvería ambiguo
				"[[otra-cosa]]", -- éste sí, porque su nombre no colisiona
			}, vim.api.nvim_buf_get_lines(0, 0, -1, false))
		end)

		it("leaves a project that is already canonical alone", function()
			write("docs/nota.md", { "# nota", "" })
			write("source.md", { "[[nota]]", "[W](/docs/nota.md)" })
			assert.are.equal(0, assert(require("lzy.marksman.relink").plan({ root = root })).count)
		end)
	end)

	it("drops the server's 'non-existent' warning for links that do resolve here", function()
		-- Su resolutor es más estricto que el nuestro: indexa por título (el H1) y
		-- por nombre exacto, así que marca en rojo enlaces perfectamente
		-- seguibles. Se filtran ESOS y sólo esos -- un enlace roto de verdad falla
		-- en los dos y el aviso sobrevive.
		write("Una nota nueva.md", { "# Una nota", "" })
		local source = write("source.md", { "[[una-nota-nueva]]", "[[esto-no-existe]]" })
		vim.cmd("edit! " .. vim.fn.fnameescape(source))
		local bufnr = vim.api.nvim_get_current_buf()
		local marksman = require("lzy.marksman")

		local function diag(message)
			return { message = message, range = { start = { line = 0, character = 0 } } }
		end

		assert.is_true(
			marksman.resolvable_elsewhere(diag("Link to non-existent document 'una-nota-nueva'"), bufnr)
		)
		assert.is_false(
			marksman.resolvable_elsewhere(diag("Link to non-existent document 'esto-no-existe'"), bufnr)
		)
		-- Y no se toca ningún otro diagnóstico del servidor.
		assert.is_false(
			marksman.resolvable_elsewhere(diag("Link to non-existent heading 'una-nota-nueva'"), bufnr)
		)
	end)

	it("owns the ambiguity verdict instead of letting both criteria argue", function()
		-- Él mide la ambigüedad contra los TÍTULOS: dos notas encabezadas
		-- `# Una nota` le parecen el mismo destino aunque se llamen distinto, y
		-- marcaba `[[una-nota]]` como ambiguo cuando para nosotros señala un solo
		-- fichero. Su veredicto se filtra entero y emitimos el nuestro.
		write("Una nota.md", { "# Una nota" })
		write("Una nota nueva.md", { "# Una nota" })
		local source = write("source.md", { "[[una-nota]]" })
		vim.cmd("edit! " .. vim.fn.fnameescape(source))
		local bufnr = vim.api.nvim_get_current_buf()
		local marksman = require("lzy.marksman")
		require("lzy.marksman.workspace").invalidate_files()

		local function diag(message)
			return { message = message, range = { start = { line = 0, character = 0 } } }
		end
		assert.is_true(
			marksman.resolvable_elsewhere(diag("Ambiguous link to document 'una-nota'"), bufnr),
			"su ambigüedad se filtra: para nosotros no lo es"
		)
		-- Y nosotros no decimos nada, porque resuelve a un solo fichero.
		assert.are.same({}, require("lzy.marksman.diagnostics").collect(bufnr))

		-- Pero si colisionan los NOMBRES, la ambigüedad sí es nuestra.
		write("otra/Una nota.md", { "# Distinta" })
		require("lzy.marksman.workspace").invalidate_files()
		local found = require("lzy.marksman.diagnostics").collect(bufnr)
		assert.are.equal(1, #found)
		assert.matches("ambiguo", found[1].message)
	end)

	it("diagnoses the links the server accepts but we do not", function()
		-- El servidor da por bueno `[[una-nota]]` porque el H1 dice `# Una nota`,
		-- así que no avisa; nosotros no lo resolvemos, así que dejaba de seguirse
		-- en silencio. Nadie lo diagnosticaba.
		write("Una nota nueva.md", { "# Una nota", "" })
		local source = write("source.md", {
			"[[Una nota nueva]]", -- existe
			"[[una-nota-nueva]]", -- variante del nombre: existe
			"[[una-nota]]", -- el título: NO nombra ningún fichero
			"[Web](https://ejemplo.com)", -- externo: no es asunto nuestro
			"```",
			"[[dentro-de-un-fence]]",
			"```",
		})
		vim.cmd("edit! " .. vim.fn.fnameescape(source))
		require("lzy.marksman.workspace").invalidate_files()

		local found = require("lzy.marksman.diagnostics").collect(0)
		assert.are.equal(1, #found, "sólo el que no nombra ningún fichero")
		assert.are.equal(2, found[1].lnum, "la tercera línea")
		assert.matches("una%-nota", found[1].message)
	end)

	it("identifies a note by its name, so a title-shaped link does not exist", function()
		-- La identidad es el NOMBRE del fichero. `Una nota nueva.md` encabezada
		-- `# Una nota` no responde a `[[una-nota]]`: eso no nombra ningún fichero,
		-- y darlo por bueno escondería el desajuste en vez de enseñarlo.
		local note = write("Una nota nueva.md", { "# Una nota", "" })
		local workspace = require("lzy.marksman.workspace")
		local opts = { source_path = write("source.md", { "x" }), root = root }

		assert.are.equal("una-nota-nueva", workspace.wiki_name(note, root))

		-- Todas las variantes DEL NOMBRE resuelven: caja, guiones y escapes.
		assert.are.same({ note }, workspace.resolve("Una nota nueva", opts))
		assert.are.same({ note }, workspace.resolve("una nota nueva", opts))
		assert.are.same({ note }, workspace.resolve("una-nota-nueva", opts))
		assert.are.same({ note }, workspace.resolve("Una%20nota%20nueva", opts))
		-- La del título, no.
		assert.are.same({}, workspace.resolve("una-nota", opts))
		assert.are.same({}, workspace.resolve("Una nota", opts))
	end)

	it("resolves a wikilink written in Marksman's own slug form", function()
		-- El servidor de marksman completa `[[espacios-y-mayús]]` para un fichero
		-- llamado `Espacios y mayús.md`: un slug que no es el nombre de nada y
		-- que por tanto no resolvía. Se acepta al leer.
		local note = write("Espacios y mayús.md", { "# Espacios y mayús" })
		local workspace = require("lzy.marksman.workspace")
		local opts = { source_path = write("source.md", { "x" }), root = root }

		assert.are.same({ note }, workspace.resolve("espacios-y-mayús", opts))
		-- El nombre de verdad sigue mandando, y el slug no pisa nada exacto.
		assert.are.same({ note }, workspace.resolve("Espacios y mayús", opts))
		-- Un slug que no corresponde a nada sigue sin resolver.
		assert.are.same({}, workspace.resolve("no-existe-esto", opts))
	end)

	it("offers to create the note a link asks for, named exactly like the link", function()
		local new_note = require("lzy.marksman.new_note")
		write("source.md", { "x" })
		local source = vim.fs.joinpath(root, "source.md")

		local created = new_note.create("Nota Nueva", {
			source_path = source,
			root = root,
			ask = function(default)
				return default
			end,
			open = function() end,
		})

		-- Verbatim: ni slug ni id generado, para que otros [[Nota Nueva]] resuelvan.
		assert.are.equal(vim.fs.joinpath(root, "Nota Nueva.md"), created)
		assert.are.equal("# Nota Nueva", vim.fn.readfile(created)[1])

		-- Subcarpeta pedida en el enlace, y saneado de lo que rompe un wikilink.
		local nested = new_note.create("sub/Otra [rara]", {
			source_path = source,
			root = root,
			ask = function(default)
				return default
			end,
			open = function() end,
		})
		assert.are.equal(vim.fs.joinpath(root, "sub/Otra rara.md"), nested)

		-- Y si dices que no, no se crea nada.
		assert.is_nil(new_note.create("Rechazada", {
			source_path = source,
			root = root,
			ask = function()
				return nil
			end,
			notify = function() end,
		}))
		assert.is_nil(vim.uv.fs_stat(vim.fs.joinpath(root, "Rechazada.md")))
	end)

	it("smart-copies outside a vault, emitting Markdown instead of wikilinks", function()
		write(".marksman.toml", { "[core]" })
		local note = write("docs/Guía rápida.md", {
			"# Guía rápida",
			"",
			"Con `git status` inline y un [Enlace](otra.md).",
			"",
			"## Sección Dos",
		})
		vim.cmd("edit! " .. vim.fn.fnameescape(note))
		vim.bo.filetype = "markdown"
		vim.treesitter.start(0, "markdown")
		vim.treesitter.get_parser(0, "markdown"):parse(true)

		local function copy_at(row, col)
			vim.api.nvim_win_set_cursor(0, { row, col })
			local got
			require("lzy.obsidian.smart_copy").smart_copy({
				copy = function(text)
					got = text
				end,
				notify = function() end,
			})
			return got
		end

		-- Sobre un heading: enlace Markdown con etiqueta legible y destino
		-- escapado. El anchor va en la forma canónica de marksman (slug).
		assert.are.equal("[Guía rápida](/docs/Guía%20rápida.md#guía-rápida)", copy_at(1, 3))
		assert.are.equal("[Sección Dos](/docs/Guía%20rápida.md#sección-dos)", copy_at(5, 4))

		-- Lo genérico sigue funcionando igual que en el vault.
		local line = vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
		assert.are.equal("git status", copy_at(3, line:find("git status") + 2))
		assert.are.equal("otra.md", copy_at(3, line:find("otra%.md") + 2))

		-- Y sin nada bajo el cursor, un enlace al fichero, no un wikilink.
		assert.are.equal("[Guía rápida](/docs/Guía%20rápida.md)", copy_at(3, 1))
	end)

	it("renders linked content and a styled empty-note notice", function()
		local preview = require("lzy.marksman.preview")
		local content = write("content.md", {
			"---",
			"id: content",
			"---",
			"# Content",
			"",
			"## Wanted section",
			"Visible body.",
			"## Next",
			"Hidden body.",
		})
		local empty = write("empty.md", {
			"---",
			"title: Empty title",
			"aliases:",
			"  - Empty alias",
			"tags: [empty, test]",
			"---",
		})

		assert.are.equal("## Wanted section\nVisible body.", preview.render(content, "wanted-section"))
		assert.are.equal(
			table.concat({
				"> **Nota vacía**",
				">",
				"> `Empty alias` no tiene contenido fuera del frontmatter.",
				"",
				"**Aliases:** Empty alias",
				"",
				"**Tags:** #empty #test",
			}, "\n"),
			preview.render(empty)
		)
	end)

	it("uses the same safe preview for wiki, inline and CommonMark references", function()
		write("empty.md", { "" })
		local source_path = write("source.md", {
			"[[/empty]]",
			"[Empty](/empty.md)",
			"[empty]: /empty.md",
			"[Use][empty]",
		})
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"[[/empty]]",
			"[Empty](/empty.md)",
			"[empty]: /empty.md",
			"[Use][empty]",
		})
		vim.api.nvim_set_current_buf(bufnr)

		local preview = require("lzy.marksman.preview")
		local original_open, original_hover = preview.open, vim.lsp.buf.hover
		local rendered, native = {}, false
		preview.open = function(value)
			rendered[#rendered + 1] = value
		end
		vim.lsp.buf.hover = function()
			native = true
		end

		for _, position in ipairs({ { 1, 3 }, { 2, 10 }, { 3, 12 }, { 4, 7 } }) do
			vim.api.nvim_win_set_cursor(0, position)
			require("lzy.marksman").hover()
		end

		preview.open, vim.lsp.buf.hover = original_open, original_hover
		vim.api.nvim_buf_delete(bufnr, { force = true })
		assert.is_false(native)
		assert.are.equal(4, #rendered)
		for _, value in ipairs(rendered) do
			assert.matches("%*%*Nota vacía%*%*", value)
		end
	end)

	it("follows a reference definition from its identifier or destination", function()
		local target = write("target.md", { "# Target" })
		local source_path = write("source.md", { '[root]: /target.md "Description"' })
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			'[root]: /target.md "Description"',
		})
		vim.api.nvim_set_current_buf(bufnr)

		local original_show, original_definition = vim.lsp.util.show_document, vim.lsp.buf.definition
		local locations, native = {}, false
		vim.lsp.util.show_document = function(location)
			locations[#locations + 1] = location
		end
		vim.lsp.buf.definition = function()
			native = true
		end

		for _, col in ipairs({ 2, 12 }) do
			vim.api.nvim_win_set_cursor(0, { 1, col })
			require("lzy.marksman").definition()
		end

		vim.lsp.util.show_document, vim.lsp.buf.definition = original_show, original_definition
		vim.api.nvim_buf_delete(bufnr, { force = true })
		assert.is_false(native)
		assert.are.equal(2, #locations)
		assert.are.equal(target, vim.uri_to_fname(locations[1].uri))
		assert.are.equal(target, vim.uri_to_fname(locations[2].uri))
	end)

	it("finds a linked section beyond the beginning of a long note", function()
		local lines = { "# Long note" }
		for _ = 1, 140 do
			lines[#lines + 1] = "Filler."
		end
		lines[#lines + 1] = "## Deep section"
		lines[#lines + 1] = "Visible deep body."
		local target = write("long.md", lines)

		assert.are.equal(
			"## Deep section\nVisible deep body.",
			require("lzy.marksman.preview").render(target, "deep-section")
		)
	end)

	it("resolves and previews duplicate heading anchors independently", function()
		local target = write("duplicates.md", {
			"# Duplicates",
			"",
			"## Repeat",
			"First body.",
			"",
			"## Repeat",
			"Second body.",
			"",
			"## Next",
		})
		local workspace = require("lzy.marksman.workspace")
		local first = assert(workspace.location(target, "repeat"))
		local second = assert(workspace.location(target, "repeat-1"))

		assert.are.equal(2, first.range.start.line)
		assert.are.equal(5, second.range.start.line)
		assert.are.equal("## Repeat\nSecond body.", require("lzy.marksman.preview").render(target, "repeat-1"))
	end)

	it("reanchors later duplicates when an earlier heading is renamed", function()
		local target = write("duplicates.md", {
			"# Duplicates",
			"",
			"## Repeat",
			"",
			"## Repeat",
		})
		local source = write("source.md", {
			"[First](/duplicates.md#repeat)",
			"[Second](/duplicates.md#repeat-1)",
			"[[/duplicates#Repeat]]",
			"[[/duplicates#Repeat-1]]",
			"[first]: /duplicates.md#repeat",
			"[second]: /duplicates.md#repeat-1",
		})
		local edit =
			require("lzy.marksman.rename").augment_heading_edit({}, target, "repeat", "Changed", root, "utf-8", 2)
		local replacements = {}
		for _, text_edit in ipairs(edit.changes[vim.uri_from_fname(source)]) do
			replacements[#replacements + 1] = text_edit.newText
		end
		table.sort(replacements)
		assert.are.same({ "changed", "changed", "changed", "repeat", "repeat", "repeat" }, replacements)
	end)

	it("writes canonical fragments for wiki links after heading rename", function()
		local target = write("target.md", { "# Target", "", "## Old heading" })
		local source = write("source.md", {
			"[[/target#Old heading]]",
			"[Inline](/target.md#old-heading)",
		})
		local edit =
			require("lzy.marksman.rename").augment_heading_edit({}, target, "old-heading", "Nueva Sección", root)
		local replacements = {}
		for _, text_edit in ipairs(edit.changes[vim.uri_from_fname(source)]) do
			replacements[#replacements + 1] = text_edit.newText
		end
		assert.are.same({ "nueva-sección", "nueva-sección" }, replacements)
	end)

	it("preserves Unicode letters in the same heading anchors as Marksman", function()
		local target = write("unicode.md", { "# Unicode", "", "## Sección Única", "Contenido." })
		local workspace = require("lzy.marksman.workspace")

		assert.are.equal("sección-única", workspace.slug("Sección Única"))
		assert.are.equal(2, assert(workspace.location(target, "sección-única")).range.start.line)
		assert.are.equal(
			"## Sección Única\nContenido.",
			require("lzy.marksman.preview").render(target, "sección-única")
		)
	end)

	it("indexes ATX and Setext headings with separate anchors", function()
		local workspace = require("lzy.marksman.workspace")
		local headings = workspace.headings({
			"# Document",
			"",
			"Setext Heading",
			"--------------",
		})

		assert.are.equal(2, #headings)
		assert.are.equal("document", headings[1].anchor)
		assert.are.equal("setext-heading", headings[2].anchor)
		assert.is_true(headings[2].setext)
		assert.are.equal(2, headings[2].row)
	end)

	it("does not classify Windows drive paths as external URLs", function()
		local parser = require("lzy.marksman.parser")
		local definition = assert(parser.definition('[ref]: C:\\notes\\target.md "Local"'))
		assert.are.equal("note", parser.component(definition, 8).kind)
	end)

	it("keeps URL fragments in the URL component", function()
		local parser = require("lzy.marksman.parser")
		local definition = assert(parser.definition("[web]: https://example.com/page#section"))
		local component = parser.component(definition, definition.fragment_range.start_col)
		assert.are.equal("url", component.kind)
		assert.are.equal("https://example.com/page#section", component.text)
	end)

	it("renames a reference URL and its description independently", function()
		local source_path = write("source.md", {
			'[web]: https://example.com/page#section "Description"',
		})
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			'[web]: https://example.com/page#section "Description"',
		})
		vim.api.nvim_set_current_buf(bufnr)

		local parser = require("lzy.marksman.parser")
		local rename = require("lzy.marksman.rename")
		local original_input = vim.ui.input
		vim.ui.input = function(_, callback)
			callback("New description")
		end
		local line = vim.api.nvim_get_current_line()
		local ref = assert(parser.definition(line, 0))
		assert.is_true(rename.link(ref, parser.component(ref, ref.title_range.start_col), bufnr))
		assert.are.equal('[web]: https://example.com/page#section "New description"', vim.api.nvim_get_current_line())

		vim.ui.input = function(_, callback)
			callback("https://example.org/new#part")
		end
		line = vim.api.nvim_get_current_line()
		ref = assert(parser.definition(line, 0))
		assert.is_true(rename.link(ref, parser.component(ref, ref.target_range.start_col), bufnr))
		assert.are.equal('[web]: https://example.org/new#part "New description"', vim.api.nvim_get_current_line())
		vim.ui.input = original_input
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not index headings inside fenced code", function()
		local headings = require("lzy.marksman.workspace").headings({
			"# Real heading",
			"",
			"```markdown",
			"# Fake heading",
			"```",
		})
		assert.are.equal(1, #headings)
		assert.are.equal("real-heading", headings[1].anchor)
	end)

	it("ignores links and definitions inside metadata and code blocks", function()
		local parser = require("lzy.marksman.parser")
		local lines = {
			"---",
			"value: '[fake]: target.md'",
			"---",
			"",
			"```markdown",
			"[Fake](target.md)",
			"```",
			"",
			"[Real](target.md)",
		}
		assert.is_nil(parser.at(lines, 5, 8))
		assert.is_nil(parser.definitions(lines).fake)
		assert.are.equal("inline", parser.at(lines, 8, 8).kind)
	end)

	it("completes a reference target with an unambiguous root path", function()
		write("target.md", { "# Target" })
		local source_path = write("notes/source.md", { "[definition]: tar" })
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "[definition]: tar" })
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "markdown"
		vim.api.nvim_win_set_cursor(0, { 1, 17 })

		local source = require("lzy.marksman.completion").source()
		local result
		source:complete({}, function(value)
			result = value
		end)

		assert.are.equal("utf-8", source:get_position_encoding_kind())
		assert.are.equal("/target.md", result.items[1].textEdit.newText)
		assert.are.same({ line = 0, character = 14 }, result.items[1].textEdit.range.start)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("lists root notes immediately after slash in every destination syntax", function()
		write("alpha.md", { "# Alpha" })
		write("nested/beta.md", { "# Beta" })
		local source_path = write("notes/source.md", {
			"[definition]: /",
			"[Text](/",
			"[[/",
		})
		local lines = { "[definition]: /", "[Text](/", "[[/" }
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "markdown"

		local source = require("lzy.marksman.completion").source()
		local expected_starts = { 14, 7, 2 }
		for row, line in ipairs(lines) do
			vim.cmd.stopinsert()
			vim.api.nvim_win_set_cursor(0, { row, math.max(#line - 1, 0) })
			vim.cmd("startinsert!")
			local result
			source:complete({}, function(value)
				result = value
			end)
			-- Cada sintaxis inserta SU forma: en `[[` el nombre legible, en las
			-- Markdown la ruta escapada desde la raiz.
			local wanted = line:match("%[%[") and "alpha" or "/alpha.md"
			local alpha = vim.iter(result.items):find(function(item)
				return item.textEdit.newText == wanted
			end)
			assert.is_not_nil(alpha, line)
			assert.are.same({ line = row - 1, character = expected_starts[row] }, alpha.textEdit.range.start)
		end
		vim.cmd.stopinsert()
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("filters with the coordinate that was typed, so cmp keeps the item", function()
		-- El filtro se puntúa contra lo tecleado, coordenada incluida: filtrar
		-- "/docs" contra "docs/api.md" da score 0 en cmp y el item desaparece,
		-- que es el síntoma de "empezar por / no ofrece nada".
		write("docs/api.md", { "# Api" })
		local source_path = write("notes/source.md", { "[[/docs" })
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "[[/docs" })
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "markdown"
		vim.cmd("startinsert!")
		vim.api.nvim_win_set_cursor(0, { 1, 6 })

		local result
		require("lzy.marksman.completion").source():complete({}, function(value)
			result = value
		end)
		local api = vim.iter(result.items):find(function(item)
			return item.textEdit.newText == "docs/api"
		end)
		assert.is_not_nil(api)
		-- El filtro conserva la coordenada aunque el destino insertado no la lleve.
		assert.are.equal("/docs/api.md", api.filterText)
		-- Con nvim-cmp disponible se comprueba el efecto real: lo tecleado tiene
		-- que puntuar contra el filtro. "/docs" contra "docs/api.md" daba 0.
		local ok, matcher = pcall(require, "cmp.matcher")
		if ok then
			assert.is_true(matcher.match("/docs", api.filterText) > 0)
			assert.are.equal(0, matcher.match("/docs", "docs/api.md"))
		end

		vim.cmd.stopinsert()
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("offers the folders of both roots for [[/, so there is a way down the tree", function()
		write("docs/api.md", { "# Api" })
		write("docs/deep/nested.md", { "# Nested" })
		local source_path = write("notes/source.md", { "[[/" })
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "[[/" })
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "markdown"
		vim.cmd("startinsert!")
		vim.api.nvim_win_set_cursor(0, { 1, 3 })

		local result
		require("lzy.marksman.completion").source():complete({}, function(value)
			result = value
		end)
		local function find(target)
			return vim.iter(result.items):find(function(item)
				return item.textEdit.newText == target
			end)
		end

		-- La carpeta del proyecto, que es lo que faltaba: sin ella `[[/` no daba
		-- nada hasta acertar a ciegas el nombre del archivo.
		-- Sin barra inicial: en `[[` la coordenada va en su forma simple.
		local docs = assert(find("docs/"), "no folder from the project root")
		assert.are.equal("Carpeta del proyecto", docs.detail)
		assert.are.equal(vim.lsp.protocol.CompletionItemKind.Folder, docs.kind)
		assert.are.same({ line = 0, character = 2 }, docs.textEdit.range.start)
		-- Y las del sistema: la barra es ambigua a propósito.
		assert.is_not_nil(
			vim.iter(result.items):find(function(item)
				return item.detail == "Carpeta del sistema"
			end),
			"no folder from the system root"
		)
		-- Las notas siguen ahí; la carpeta no las sustituye.
		assert.is_not_nil(find("docs/api"))
		-- Solo el primer nivel: bajar es tarea del siguiente `/`.
		assert.is_nil(find("docs/deep/"))

		vim.cmd.stopinsert()
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("keeps descending once a folder has been accepted", function()
		write("docs/deep/nested.md", { "# Nested" })
		local source_path = write("notes/source.md", { "[[/docs/" })
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "[[/docs/" })
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "markdown"
		vim.cmd("startinsert!")
		vim.api.nvim_win_set_cursor(0, { 1, 8 })

		local result
		require("lzy.marksman.completion").source():complete({}, function(value)
			result = value
		end)
		local deep = vim.iter(result.items):find(function(item)
			return item.textEdit.newText == "docs/deep/"
		end)
		assert.is_not_nil(deep)

		vim.cmd.stopinsert()
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("resolves a root-relative target as a system path when the project has no such file", function()
		local inside = write("docs/api.md", { "# Api" })
		local outside = vim.fn.tempname() .. ".md"
		vim.fn.writefile({ "# Outside" }, outside)
		local source_path = write("notes/source.md", { "x" })
		local workspace = require("lzy.marksman.workspace")

		assert.are.same(
			{ vim.fs.normalize(inside) },
			workspace.resolve("/docs/api.md", { source_path = source_path, root = root })
		)
		-- No cuelga del proyecto: la barra vale como ruta absoluta del sistema.
		assert.are.same(
			{ vim.fs.normalize(outside) },
			workspace.resolve(outside, { source_path = source_path, root = root })
		)
		vim.fn.delete(outside)
	end)

	it("reaches a sibling directory through ../, which vim.fs.relpath cannot express", function()
		local coord = require("lzy.link_target")
		assert.are.equal("../docs/x.md", coord.relative("/a/b/docs/x.md", "/a/b/notes"))
		assert.is_nil(vim.fs.relpath("/a/b/notes", "/a/b/docs/x.md"))
		assert.are.equal("../docs/x.md", coord.note_relative("/a/b/docs/x.md", "/a/b/notes", "../"))
		assert.are.equal("./sub/x.md", coord.note_relative("/a/b/notes/sub/x.md", "/a/b/notes", "./"))
	end)

	it("collects only unambiguous structural backlinks, including CommonMark uses", function()
		local target = write("target.md", { "# Target" })
		write("notes/target.md", { "# Homonym" })
		local source = write("source.md", {
			"[Inline](/target.md)",
			"[[/target]]",
			"[ref]: /target.md",
			"[Use][ref]",
			"[ref][]",
			"[ref]",
			"[Ambiguous](target.md)",
			"```markdown",
			"[Code](/target.md)",
			"```",
		})

		local backlinks = require("lzy.marksman.backlinks").collect(target, root)
		assert.are.equal(5, #backlinks)
		assert.are.same(
			{ 1, 2, 4, 5, 6 },
			vim.tbl_map(function(item)
				assert.are.equal(source, item.filename)
				assert.are.equal(item.lnum, item.end_pos[1])
				assert.is_true(item.end_pos[2] > item.pos[2])
				return item.lnum
			end, backlinks)
		)
	end)

	it("always sends zero, one or many backlinks through the picker", function()
		local target = write("target.md", { "# Target" })
		local orphan = write("orphan.md", { "# Orphan" })
		write("source.md", { "[[/target]]" })
		local picked = {}
		local function pick(items, opts)
			picked[#picked + 1] = { count = #items, title = opts.prompt_title }
		end
		local backlinks = require("lzy.marksman.backlinks")
		backlinks.open({ path = target, root = root, pick = pick })
		backlinks.open({ path = orphan, root = root, pick = pick })
		assert.are.same({
			{ count = 1, title = "Backlinks" },
			{ count = 0, title = "Backlinks" },
		}, picked)
	end)

	it("follows a CommonMark use through its declaration to the final note", function()
		local target = write("target.md", { "# Target", "", "## Section" })
		local source_path = write("source.md", {
			"[ref]: /target.md#section",
			"[Visible][ref]",
		})
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"[ref]: /target.md#section",
			"[Visible][ref]",
		})
		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, { 2, 11 })

		local original_show, location = vim.lsp.util.show_document
		vim.lsp.util.show_document = function(value)
			location = value
		end
		assert.is_true(require("lzy.marksman").follow())
		vim.lsp.util.show_document = original_show
		assert.are.equal(target, vim.uri_to_fname(location.uri))
		assert.are.equal(2, location.range.start.line)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("matches Obsidian smart action for links, tags, folds and checkboxes", function()
		write("target.md", { "# Target" })
		local source_path = write("source.md", {
			"[[/target]]",
			"Text #project/sub",
			"## Heading",
			"- [ ] Task",
			"Paragraph",
		})
		local lines = { "[[/target]]", "Text #project/sub", "## Heading", "- [ ] Task", "Paragraph" }
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_set_current_buf(bufnr)
		local old_foldmethod = vim.wo.foldmethod
		local old_markdown_folding = vim.g.markdown_folding
		vim.g.markdown_folding = nil
		vim.wo.foldmethod = "expr"

		local marksman = require("lzy.marksman")
		vim.api.nvim_win_set_cursor(0, { 1, 3 })
		assert.matches("follow", marksman.smart_action())
		vim.api.nvim_win_set_cursor(0, { 2, 8 })
		assert.matches("tags", marksman.smart_action())
		vim.api.nvim_win_set_cursor(0, { 3, 4 })
		assert.are.equal("za", marksman.smart_action())
		vim.api.nvim_win_set_cursor(0, { 4, 4 })
		assert.matches("toggle_checkbox", marksman.smart_action())
		vim.api.nvim_win_set_cursor(0, { 5, 3 })
		assert.matches("toggle_checkbox", marksman.smart_action())

		vim.api.nvim_win_set_cursor(0, { 4, 4 })
		marksman.toggle_checkbox()
		assert.are.equal("- [x] Task", vim.api.nvim_buf_get_lines(bufnr, 3, 4, false)[1])
		vim.api.nvim_win_set_cursor(0, { 5, 3 })
		marksman.toggle_checkbox()
		assert.are.equal("- [ ] Paragraph", vim.api.nvim_buf_get_lines(bufnr, 4, 5, false)[1])

		vim.wo.foldmethod = "manual"
		vim.api.nvim_win_set_cursor(0, { 3, 4 })
		assert.are.equal("<CR>", marksman.smart_action())
		assert.are.equal("## Heading", vim.api.nvim_buf_get_lines(bufnr, 2, 3, false)[1])

		vim.wo.foldmethod = old_foldmethod
		vim.g.markdown_folding = old_markdown_folding
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("indexes tag trees and frontmatter but ignores fenced code", function()
		write("one.md", {
			"---",
			"tags: [project, project/meta]",
			"---",
			"Visible #project/sub and #project/sub/deep",
			"```",
			"Hidden #project/sub",
			"```",
		})
		write("two.md", { "Otra #project", "No relacionada #other" })
		local index = require("lzy.marksman.tags")
		assert.are.equal(5, #index.collect("project", root))
		assert.are.equal(2, #index.collect("project/sub", root))
		assert.are.equal(1, #index.collect("project/meta", root))
		local branches = index.branches("project", root)
		assert.are.same({ "project", "project/meta", "project/sub", "project/sub/deep" },
			vim.tbl_map(function(item)
				return item.tag
			end, branches))
		assert.are.same({ count = 5, notes = 2 }, { count = branches[1].count, notes = branches[1].notes })
	end)

	it("selects a tag branch before listing its note occurrences", function()
		write("one.md", { "Parent #project", "Child #project/sub", "Deep #project/sub/deep" })
		write("two.md", { "Other child #project/other" })
		local index = require("lzy.marksman.tags")
		local selected, results
		index.open({
			tag = "project",
			root = root,
			select = function(items, opts, callback)
				assert.are.equal("Tags: #project", opts.prompt_title)
				assert.are.equal("project", items[1].tag)
				for _, item in ipairs(items) do
					if item.tag == "project/sub" then
						selected = item.tag
						return callback(item)
					end
				end
			end,
			pick = function(items, opts)
				results = items
				assert.are.equal("#project/sub", opts.prompt_title)
			end,
		})

		assert.are.equal("project/sub", selected)
		assert.are.same({ "project/sub", "project/sub/deep" }, vim.tbl_map(function(item)
			assert.are.equal("#" .. item.tag, item.label)
			return item.tag
		end, results))
	end)

	it("renames a tag subtree in body and frontmatter", function()
		local one = write("one.md", {
			"---",
			"tags:",
			"  - project",
			"  - project/child",
			"---",
			"Visible #project and #project/child; keep #other",
			"```",
			"Hidden #project",
			"```",
		})
		local two = write("two.md", { "Case-insensitive #PROJECT/grandchild" })
		local edit, err, count = require("sabunv.nvim.tags").rename_edit("project", "work", root)
		assert.is_nil(err)
		assert.are.equal(5, count)

		local replacements = {}
		for _, text_edit in ipairs(edit.changes[vim.uri_from_fname(one)]) do
			replacements[#replacements + 1] = text_edit.newText
			assert.are_not.equal(7, text_edit.range.start.line)
		end
		for _, text_edit in ipairs(edit.changes[vim.uri_from_fname(two)]) do
			replacements[#replacements + 1] = text_edit.newText
		end
		table.sort(replacements)
		assert.are.same({ "work", "work", "work/child", "work/child", "work/grandchild" }, replacements)
	end)

	it("installs Marksman backlinks, follow and smart-action controls buffer-locally", function()
		local source_path = write("source.md", { "# Source" })
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		local old_mapleader = vim.g.mapleader
		vim.g.mapleader = " "
		require("lzy.marksman").on_attach({}, bufnr)

		local mappings = {}
		for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
			mappings[mapping.desc or mapping.lhs] = mapping
		end
		assert.is_not_nil(mappings["Marksman: qué notas enlazan a esta"])
		assert.is_not_nil(mappings["Marksman: seguir el enlace bajo el cursor"])
		assert.is_not_nil(mappings["Marksman: toggle checkbox"])
		assert.are.equal(1, mappings["Marksman Smart Action"].expr)
		local commands = vim.api.nvim_buf_get_commands(bufnr, {})
		assert.is_not_nil(commands.MarksmanBacklinks)
		assert.is_not_nil(commands.MarksmanFollowLink)
		vim.g.mapleader = old_mapleader
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("uses Marksman coordinates for gx, including reference definitions", function()
		local root_asset = write("asset.png", { "root asset" })
		local local_asset = write("notes/local.png", { "local asset" })
		local source_path = write("notes/source.md", {
			"[Root](/asset.png)",
			"[Local](./local.png)",
			"[ref]: /asset.png",
			"[Use][ref]",
		})
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"[Root](/asset.png)",
			"[Local](./local.png)",
			"[ref]: /asset.png",
			"[Use][ref]",
		})
		vim.api.nvim_set_current_buf(bufnr)

		-- El init normal carga este módulo al arrancar; se recarga para que el
		-- runner de Plenary pruebe siempre el worktree y no la versión precargada.
		package.loaded["sabunv.nvim.markdown"] = nil
		local markdown = require("sabunv.nvim.markdown")
		assert.are.equal(source_path, vim.api.nvim_buf_get_name(bufnr))
		local actual_root = markdown.root_of(bufnr)
		assert.are.equal(root, actual_root)
		assert.are.same(
			{ root_asset },
			require("lzy.marksman.workspace").resolve("/asset.png", {
				source_path = source_path,
				root = root,
				all_files = true,
			})
		)
		local resolved_root, root_candidates = markdown.resolve("/asset.png", { bufnr = bufnr })
		assert.is_nil(root_candidates)
		assert.are.equal(root_asset, resolved_root)
		local resolved_local = markdown.resolve("./local.png", { bufnr = bufnr })
		assert.are.equal(local_asset, resolved_local)
		local invalid_local = markdown.resolve("./asset.png", { bufnr = bufnr })
		assert.is_nil(invalid_local)
		assert.are.equal("/asset.png", markdown.ref_target(bufnr, 3, 9))
		assert.are.equal("/asset.png", markdown.ref_target(bufnr, 4, 3))

		local opener = require("sabunv.nvim.file_opener")
		local original_open_path, opened = opener.open_path
		opener.open_path = function(path)
			opened = path
			return true
		end
		assert.is_true(markdown.open("/asset.png", { bufnr = bufnr }))
		opener.open_path = original_open_path
		assert.are.equal(root_asset, opened)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("opens attachments from their content instead of their extension", function()
		local custom = write("assets/text.custom", { "plain text" })
		local fake_video = write("assets/text.mp4", { "still plain text" })
		local fake_text = write_binary("assets/binary.txt", "\137PNG\r\n\26\n\0binary")
		local unknown = write_binary("assets/binary.weird", "%PDF-1.7\n\0binary")
		local source = write("source.md", { "# Source" })
		local opener = require("sabunv.nvim.file_opener")

		-- Fuerza el detector portable que se usa en Windows cuando no existe
		-- el ejecutable Unix `file`.
		assert.is_true(opener.is_text(custom, { file_command = false }))
		assert.is_true(opener.is_text(fake_video, { file_command = false }))
		assert.is_false(opener.is_text(fake_text, { file_command = false }))
		assert.is_false(opener.is_text(unknown, { file_command = false }))

		vim.cmd.edit(source)
		assert.is_true(opener.open_path(custom, { schedule = false }))
		assert.are.equal(custom, vim.api.nvim_buf_get_name(0))
		vim.cmd.edit(source)
		assert.is_true(opener.open_path(fake_video, { schedule = false }))
		assert.are.equal(fake_video, vim.api.nvim_buf_get_name(0))
		vim.cmd.edit(source)

		local original_open, opened = vim.ui.open, {}
		vim.ui.open = function(path)
			opened[#opened + 1] = path
		end
		assert.is_true(opener.open_path(fake_text, { schedule = false }))
		assert.is_true(opener.open_path(unknown, { schedule = false }))
		vim.ui.open = original_open
		assert.are.same({ fake_text, unknown }, opened)
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.startswith(vim.api.nvim_buf_get_name(bufnr), root .. "/") then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
	end)

	it("routes gd on attachments through the same content-aware opener", function()
		local custom = write("assets/text.custom", { "plain text" })
		local binary = write_binary("assets/binary.weird", "\137PNG\r\n\26\n\0binary")
		local source_path = write("source.md", {
			"[Text](/assets/text.custom)",
			"[[/assets/binary.weird]]",
			"[asset]: /assets/text.custom",
			"[Use][asset]",
		})
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(bufnr, source_path)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"[Text](/assets/text.custom)",
			"[[/assets/binary.weird]]",
			"[asset]: /assets/text.custom",
			"[Use][asset]",
		})
		vim.api.nvim_set_current_buf(bufnr)

		local opener = require("sabunv.nvim.file_opener")
		local original_open, original_definition = opener.open_path, vim.lsp.buf.definition
		local opened, native = {}, false
		opener.open_path = function(path)
			opened[#opened + 1] = path
			return true
		end
		vim.lsp.buf.definition = function()
			native = true
		end

		for _, position in ipairs({ { 1, 12 }, { 2, 10 }, { 3, 3 }, { 3, 18 } }) do
			vim.api.nvim_win_set_cursor(0, position)
			require("lzy.marksman").definition()
		end
		-- Un uso CommonMark conserva su semántica: `gd` va a la declaración.
		vim.api.nvim_win_set_cursor(0, { 4, 8 })
		require("lzy.marksman").definition()

		opener.open_path, vim.lsp.buf.definition = original_open, original_definition
		vim.api.nvim_buf_delete(bufnr, { force = true })
		assert.are.same({ custom, binary, custom, custom }, opened)
		assert.is_true(native)
	end)
end)
