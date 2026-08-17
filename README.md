# saburou-nvim

## Brief

![Vista previa](/docs/attachments/preview.png)

`saburou-nvim` es mi configuración de _**Neovim**_. Es una configuración opinionada que ha alcanzado una
fase en la que principalmente me ocupo de arreglar bugs o dar soporte a lenguajes de programación
diversos.

- Si os gusta el proyecto y quereis implusarlo podéis donarme para un café en [![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=W9K3ZTUM2QNAC).

## Installation

### Pre-requisitos

#### Imprescindibles

- **[Neovim](/docs/Neovim.md) 0.12+** La configuración usa APIs y comportamientos disponibles a partir de Neovim 0.12.
  No se garantiza compatibilidad con versiones anteriores ni futuras.
- **[Git](/docs/Git.md)** ― necesario para clonar el repositorio, para que `lazy.nvim` instale los plugins, y para
  crear el directorio `.git` en la raíz de tu proyecto ya que es la manera en la que la mayoría de
  los linters de distintos lenguajes reconocen el directorio raíz.
- **[Cargo+Rust](/docs/Cargo+Rust.md)** — necesario para compilar e instalar `tree-sitter-cli`.
- **[tree-sitter-cli](/docs/tree-sitter-cli.md) 0.26.1 o superior** — necesario para que `nvim-treesitter` compile los parsers.
- Una **[Nerd Font](https://www.nerdfonts.com/)** configurada en la terminal para mostrar correctamente los iconos.
	- Nota: Elige una variante que no termine en `Mono` para que los iconos no se vean todos del
	  mismo tamaño
- **[Node.js](/docs/Node.js.md)** — necesario para compilar `tree-sitter-cli` y para varias herramientas de
  JavaScript/TypeScript usadas por la configuración, incluidos servidores LSP, herramientas
  instaladas mediante Mason y `copilot.lua`.

**[curl](/docs/Curl.md) y un [compilador de C](/docs/Compilador%20de%20C.md) (`gcc` o `clang`)** disponibles en el `PATH` — necesarios para que
`lazy.nvim`, `mason.nvim` y `nvim-treesitter` puedan descargar compilar dependencias opcionales de la
configuración.

#### Circunstanciales

> [!NOTE] Dependencias opcionales molestas
>
> - Si no usas opencode o copilot.nvim y no quieres que se queje la configuración entonces
>   instalalos o comenta los plugins. Una vez terminada la alpha, tras la limpieza, esto dejara
>   de ser así. Y hay más casos así:
>     - No instalar Python provoca que la instalación de muchos paquetes de Mason fallen.

- **[AI CLI Tools](/docs/AI%20CLI%20Tools.md)** — OpenCode, Claude y Codex; necesarios para utilizar las funcionalidades de IA
  proporcionadas por la configuración.
- **[ripgrep](/docs/ripgrep.md)** — necesario para las búsquedas de texto utilizadas por distintas funcionalidades de
  la configuración.
- **[Python](/docs/Python.md)** Utilizado por muchos paquetes en que se instalan por medio de `Mason`.

### Clonar configuración

#### Windows

**Clonar como configuración principal**

```powershell
git clone https://github.com/heizeisaburou/saburou-nvim $env:LOCALAPPDATA\nvim
```

**Clonar como configuración alternativa**

```powershell
git clone https://github.com/heizeisaburou/saburou-nvim $env:LOCALAPPDATA\nombre_que_tu_quieras
```

**Iniciar una configuración alternativa (pwsh)**

Lo más sencillo es crear una función:

```powershell
function srnv {
	$hadNvimAppName = Test-Path Env:NVIM_APPNAME
	$oldNvimAppName = $env:NVIM_APPNAME

	try {
		$env:NVIM_APPNAME = "nombre_que_tu_quieras"
		nvim @args
	}
	finally {
		if ($hadNvimAppName) {
			$env:NVIM_APPNAME = $oldNvimAppName
		}
		else {
			Remove-Item Env:NVIM_APPNAME -ErrorAction SilentlyContinue
		}
	}
}

```

Si es para probar al momento:

```powershell
$env:NVIM_APPNAME = "nombre_que_tu_quieras"; nvim; Remove-Item Env:NVIM_APPNAME
```

#### Linux / macOS

**Clonar como configuración principal**

```sh
git clone https://github.com/heizeisaburou/saburou-nvim ~/.config/nvim
```

**Clonar como configuración alternativa**

```sh
git clone https://github.com/heizeisaburou/saburou-nvim ~/.config/nombre_que_tu_quieras
```

**Iniciar configuración alternativa (Bourne shells)**

En Linux es muy sencillo pasar envs sin dejarlas clavadas:

```sh
NVIM_APPNAME=nombre_que_tu_quieras nvim
```

También puedes crear un alias (`.bashrc`, `.zshrc`, etc):

```zsh
alias nombre_que_tu_quieras='NVIM_APPNAME=nombre_que_tu_quieras nvim'
```

### Ajustar la configuración

Por defecto desactivo en mi configuración la mayoría de linter, formateadores, etc. por dos
motivos:

- Porque si no lo hicieramos la cantidad de dependencias sería absurda:
	- Aparecerían muchos errores, pareciendo que _saburou-nvim_ está roto.
	- Se aumentaría mucho la plataforma de ataque por número de dependencias que se instalan
	  mediante `Mason`.

También tomamos algunas decisiones como sincronizar el clipboard del usuario si es que se puede,
algo que un usuario experimentado de Neovim probablemente no quiera.



## Lenguajes soportados

| Lenguaje / formato | Filetype                         | LSP                           | Formatter                    | Tree-sitter                                   |
| ------------------ | -------------------------------- | ----------------------------- | ---------------------------- | --------------------------------------------- |
| Ansible            | `yaml.ansible`                   | `ansiblels`                   | `yamlfmt` (vía `yaml`)       | `yaml` (fallback)                             |
| Assembly (GAS)     | `asm`                            | `asm_lsp`                     | — (no existe)                | `asm`                                         |
| Assembly (NASM)    | `nasm`                           | `asm_lsp`                     | `nasmfmt`                    | `nasm`                                        |
| Bash               | `bash`                           | `bashls`                      | `shfmt`                      | `bash`                                        |
| Batch              | `dosbatch`                       | —                             | —                            | pendiente (`tree-sitter-batch` sin catalogar) |
| C                  | `c`                              | `clangd`                      | `clang_format`               | `c`                                           |
| C++                | `cpp`                            | `clangd`                      | `clang_format`               | `cpp`                                         |
| CMake              | `cmake`                          | `neocmake`                    | —                            | `cmake`                                       |
| C#                 | `cs`                             | `csharp_ls`                   | `csharpier`                  | `c_sharp`                                     |
| Clojure            | `clojure`                        | `clojure_lsp`                 | `zprint`                     | `clojure`                                     |
| EDN                | `edn`                            | —                             | `zprint`                     | `clojure` (alias)                             |
| CSS                | `css`                            | `cssls`                       | `prettier`                   | `css`                                         |
| Dart               | `dart`                           | `dartls`                      | `dart_format`                | `dart`                                        |
| Django templates   | `htmldjango`                     | `djls`                        | `djlint`                     | `htmldjango`                                  |
| Elixir             | `elixir`                         | `elixirls`                    | `mix`                        | `elixir`                                      |
| EEx                | `eelixir`                        | `elixirls`                    | `mix`                        | —                                             |
| HEEx               | `heex`                           | `elixirls`                    | `mix`                        | `heex`                                        |
| Erlang             | `erlang`                         | `elp`                         | `erlfmt`                     | `erlang`                                      |
| F#                 | `fsharp`                         | `fsautocomplete`              | `fantomas`                   | `fsharp`                                      |
| Fish               | `fish`                           | `fish_lsp`                    | `fish_indent`                | `fish`                                        |
| Gleam              | `gleam`                          | —                             | `gleam`                      | —                                             |
| GLSL               | `glsl`                           | `glsl_analyzer`               | vía LSP                      | `glsl`                                        |
| Go                 | `go`                             | `gopls`                       | `gofmt`                      | `go`                                          |
| Go modules         | `gomod` / `gosum` / `gowork`     | `gopls`                       | —                            | `gomod` / `gosum` / `gowork`                  |
| Go templates       | `gotmpl`                         | `gopls`                       | `prettier_gotmpl`            | `gotmpl`                                      |
| Groovy             | `groovy`                         | `groovyls`                    | `npm-groovy-lint`            | `groovy`                                      |
| Handlebars         | `handlebars`                     | —                             | `prettier_handlebars`        | —                                             |
| Haskell            | `haskell`                        | `hls`                         | `fourmolu`                   | `haskell`                                     |
| Literate Haskell   | `lhaskell`                       | `hls`                         | `fourmolu`                   | `haskell` (alias)                             |
| HTML               | `html`                           | `html`                        | `prettier`                   | `html`                                        |
| Java               | `java`                           | `jdtls`                       | `google-java-format`         | `java`                                        |
| JavaScript         | `javascript` / `javascriptreact` | `vtsls`                       | `prettier`                   | `javascript`                                  |
| Julia              | `julia`                          | `julials`                     | `runic`                      | `julia`                                       |
| Jinja              | `jinja`                          | `jinja_lsp`                   | `prettier_jinja`             | `jinja` + `jinja_inline`                      |
| JSON               | `json`                           | `jsonls`                      | `biome`                      | `json` / `json5`                              |
| Kotlin             | `kotlin`                         | `kotlin_language_server`      | `ktlint`                     | `kotlin`                                      |
| LaTeX / TeX        | `tex` / `plaintex`               | `texlab`                      | `latexindent`                | —                                             |
| Liquid / Shopify   | `liquid`                         | `shopify_theme_ls`            | `prettier_liquid`            | `liquid`                                      |
| Lua                | `lua`                            | `lua_ls`                      | `stylua`                     | `lua` / `luadoc`                              |
| Make               | `make`                           | —                             | —                            | `make`                                        |
| Markdown           | `markdown`                       | `marksman`                    | `prettier` + `markdown_tabs` | `markdown` + `markdown_inline`                |
| Nix                | `nix`                            | `nil_ls`                      | `nixfmt`                     | `nix`                                         |
| OCaml              | `ocaml`                          | `ocamllsp`                    | `ocamlformat`                | `ocaml`                                       |
| OCaml interface    | `ocamlinterface`                 | `ocamllsp`                    | `ocamlformat`                | `ocaml_interface`                             |
| PHP                | `php`                            | `phpactor`                    | `php_cs_fixer`               | `php`                                         |
| PowerShell         | `ps1`                            | `powershell_es`               | vía LSP                      | `powershell`                                  |
| Pug / Jade         | `pug`                            | `pug`                         | `prettier_pug`               | `pug`                                         |
| Python             | `python`                         | `basedpyright` + `ruff`       | `ruff_format`                | `python`                                      |
| QML                | `qml`                            | `qmlls`                       | `qmlformat` (externo)        | `qmljs`                                       |
| R                  | `r`                              | `air`                         | `air`                        | `r`                                           |
| Ruby               | `ruby`                           | `ruby_lsp`                    | `rubocop`                    | `ruby`                                        |
| Rust               | `rust`                           | `rust_analyzer`               | `rustfmt`                    | `rust`                                        |
| Scala              | `scala`                          | `metals`                      | `scalafmt`                   | `scala`                                       |
| SCSS               | `scss`                           | `cssls`                       | `prettier`                   | —                                             |
| Solidity           | `solidity`                       | `solidity_ls_nomicfoundation` | `forge_fmt`                  | `solidity`                                    |
| SQL                | `sql`                            | `postgres_lsp` / `sqls`       | `sqlfluff` / `pg_format`     | `sql`                                         |
| Surface            | `surface`                        | —                             | `mix`                        | —                                             |
| Svelte             | `svelte`                         | `svelte`                      | `prettier_svelte`            | `svelte`                                      |
| Swift              | `swift`                          | `sourcekit`                   | `swiftformat`                | `swift`                                       |
| TOML               | `toml`                           | `taplo`                       | `taplo`                      | `toml`                                        |
| Twig               | `twig`                           | `twiggy_language_server`      | `prettier_twig`              | `twig`                                        |
| TypeScript / TSX   | `typescript` / `typescriptreact` | `vtsls`                       | `prettier`                   | `typescript` / `tsx`                          |
| Typst              | `typst`                          | `tinymist`                    | `typstyle`                   | `typst`                                       |
| Vim                | `vim`                            | —                             | —                            | `vim`                                         |
| Vimdoc             | `vimdoc`                         | —                             | —                            | `vimdoc`                                      |
| Vue                | `vue`                            | `vue_ls`                      | `prettier`                   | `vue`                                         |
| WebAssembly        | `wat`                            | `wasm_language_tools`         | vía LSP                      | pendiente (sin parser catalogado)             |
| YAML               | `yaml`                           | `yamlls`                      | `yamlfmt`                    | `yaml`                                        |
| Zig                | `zig`                            | `zls`                         | `zigfmt`                     | `zig`                                         |
