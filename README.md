# saburou-nvim

## Brief

![Vista previa](/docs/attachments/preview.png)

`saburou-nvim` es mi configuración de _**Neovim**_. Es una configuración opinionada que ha alcanzado una
fase en la que principalmente me ocupo de arreglar bugs o dar soporte a lenguajes de programación
diversos.

- Si os gusta el proyecto y quereis implusarlo podéis donarme para un café en [![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=W9K3ZTUM2QNAC).

## Agradecimientos

- [@POLA](https://github.com/POLA-LCS) y [@Misitox](https://github.com/mateolgallegoss) por ser los primeros betatesters de Windows.
- [@SamuelGiron1](https://github.com/SamuelGiron1) por ser el primer betatester de macOS y también por ayudarme a redactar la guía
  completa de macOS dejandome utilizar su mac.

## Installation

> [!note] Si usas macOS
>
> La documentación de macOS está completa, pero no dispongo de un equipo macOS con el que
> probarla ni con el que reproducir bugs. Antes de instalar, lee [macOS support](/docs/macOS%20support.md).

### Pre-requisitos

#### Imprescindibles

- **[Neovim](/docs/Neovim.md) 0.12+** La configuración usa APIs y comportamientos disponibles a partir de Neovim 0.12.
  No se garantiza compatibilidad con versiones anteriores ni futuras.
- Una **[Nerd Font](/docs/Nerd%20Font.md)** configurada en la terminal para mostrar correctamente los iconos. Elige una
  variante que no termine en `Mono` para que los iconos no se vean todos del mismo tamaño.
- **[Git](/docs/Git.md)** ― necesario para clonar el repositorio, para que `lazy.nvim` instale los plugins, y para
  crear el directorio `.git` en la raíz de tu proyecto ya que es la manera en la que la mayoría de
  los linters de distintos lenguajes reconocen el directorio raíz.
- **[curl](/docs/Curl.md)** disponible en el `PATH` — necesario para que `mason.nvim` y `nvim-treesitter` puedan descargar
  dependencias opcionales de la configuración.
- **[ripgrep](/docs/ripgrep.md)** — necesario para las búsquedas de texto utilizadas por distintas funcionalidades de
  la configuración.
- **[Cargo+Rust](/docs/Cargo+Rust.md)** — necesario para compilar e instalar `tree-sitter-cli`.
- **[tree-sitter-cli](/docs/tree-sitter-cli.md) 0.26.1 o superior** — necesario para que `nvim-treesitter` compile los parsers.
- **[Node.js](/docs/Node.js.md)** — necesario para compilar `tree-sitter-cli` y para varias herramientas de
  JavaScript/TypeScript usadas por la configuración, como por ejemplo para instalar `prettier` que
  es un formateador core de la configuración porque lo utilizamos para `markdown`, para varias
  herramientas instaladas mediante `Mason`, `copilot.lua` y también para poder instalar `codex`, `claude`
  y `copilot` en tu sistema.
- **[Compilador de C](/docs/Compilador%20de%20C.md)** — necesario para que `mason.nvim` y `nvim-treesitter` puedan compilar
  dependencias opcionales de la configuración (incluidos los parsers de Tree-sitter). En Linux,
  `gcc` o `clang` disponible en el `PATH`; en Windows es `MSVC`.

#### Circunstanciales

- **[AI CLI Tools](/docs/AI%20CLI%20Tools.md)** — OpenCode, Claude y Codex; necesarios para utilizar las funcionalidades de IA
  proporcionadas por la configuración.

- **[Python](/docs/langs/Python.md)** Utilizado por muchos paquetes en que se instalan por medio de `Mason`.

> [!WARNING] Dependencias circunstanciales molestas
>
> - Si no usas opencode o copilot.nvim y no quieres que se queje la configuración entonces
>   instalalos o comenta los plugins. Una vez terminada la alpha, tras la limpieza, esto dejara
>   de ser así. Y hay más casos así:
>     - No instalar Python provoca que la instalación de muchos paquetes de Mason fallen.

## Lenguajes

- [Python](/docs/langs/Python.md)
- [Go](/docs/langs/Go.md)

### Clonar configuración

#### Windows

> [!WARNING]
>
> La configuración tarda bastante más tiempo en cargar en Windows que en Linux. Esto en principio
> no es cosa mia, y aunque quiero optimizarlo no llegará hasta el refactor (si es que puedo
> hacerlo). Por ejemplo en mi máquina VMWare tarda _6 segundos_ en abrir T_T.

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

### Lazy sync

El gestor de paquetes `Lazy` se invoca automáticamente la primera vez que arrancas mi configuración
de Neovim.

Si por lo que sea cerraste bruscamente Neovim, o quieres actualizar los paquetes `Lazy` puedes
utilizar `:Lazy sync` en cualquier momento.

Tras actualizar los paquetes recarga la configuración con `<leader>rs`.

> [!note]
>
> Los paquetes con pocas estrellas o que podrían romper la configuración tienen el commit fijado
> en [/lua/lzy/_plg.lua](/lua/lzy/_plg.lua) mediante `commit = "..."`.

### Instalar linters, formateadores y treesitters

El final de la instalación consiste en ejecutar `:MasonInstallAll` y `:TSInstallAll`.

Una vez ejecutados recarga Neovim con `<leader>rs`.

> [!note]
>
> - :MasonInstallAll hay que ejecutarlo cada vez que actives lenguajes en:
>     - [/lua/lzy/lspconfig.lua](/lua/lzy/lspconfig.lua)
>     - [/lua/lzy/conform.lua](/lua/lzy/conform.lua)
>     - [/lua/lzy/nvim-lint.lua](/lua/lzy/nvim-lint.lua)
> - :TSInstallAll hay que ejecutarlo nuevamente cada vez que actives lenguajes en:
>     - [/lua/lzy/treesitter.lua](/lua/lzy/treesitter.lua)

### Reconocimiento de tipos de la configuración

El comando `:Luarc` crea un archivo para que el linter de lua reconozca los tipos de mi
configuración de los plugins de `Lazy`. Esto hace que sea más fácil modificarla.

Por defecto la crea en la ruta correcta, solo tienes que guardar el archivo y recargar Neovim con
`<leader>rs`.

> [!note]
>
> Este comando hay que ejecutarlo cada vez que agregues nuevos paquetes al gestor de paquetes
> Lazy (los que indicas en [/lua/lzy/_plg.lua](/lua/lzy/_plg.lua).

### Ajustar la configuración

Por defecto desactivo en mi configuración la mayoría de linter, formateadores, etc. por dos
motivos:

- Porque si no lo hicieramos la cantidad de dependencias sería absurda:
	- Aparecerían muchos errores, pareciendo que _saburou-nvim_ está roto.
	- Se aumentaría mucho la plataforma de ataque por número de dependencias que se instalan
	  mediante `Mason`.

También tomamos algunas decisiones como sincronizar el clipboard del usuario si es que se puede,
algo que un usuario experimentado de Neovim probablemente no quiera.

Todo eso se ajusta a mano, y siempre igual: cada archivo tiene **una lista, con lo activo arriba y
el resto comentado justo debajo**. Descomentar una línea es activarla. No hay ningún archivo de
opciones aparte ni nada que generar.

#### Añadir soporte para un lenguaje

Aquí está la parte laboriosa, y conviene saberlo antes de empezar: **un lenguaje no es una sola
cosa**. Son hasta cuatro herramientas independientes, cada una en su archivo, y ninguna necesita a
las otras. Descomenta el lenguaje en las que te interesen:

| Archivo                                           | Lista              | Qué te da                                                 |
| ------------------------------------------------- | ------------------ | --------------------------------------------------------- |
| [lua/lzy/lspconfig.lua](/lua/lzy/lspconfig.lua)   | `M.servers`        | Diagnósticos, ir a definición, autocompletado y renombrar |
| [lua/lzy/treesitter.lua](/lua/lzy/treesitter.lua) | `M.languages`      | Resaltado, plegado y movimientos por sintaxis             |
| [lua/lzy/conform.lua](/lua/lzy/conform.lua)       | `formatters_by_ft` | Formateo al guardar                                       |
| [lua/lzy/nvim-lint.lua](/lua/lzy/nvim-lint.lua)   | `M.linters_by_ft`  | Diagnósticos donde no llega el LSP                        |

Casi siempre querrás las dos primeras: son las que hacen que un lenguaje se _sienta_ soportado. El
formateador y el linter son opcionales, y en muchos lenguajes el propio LSP ya formatea.

Después de descomentar, dos comandos:

- `:MasonInstallAll` — instala los servidores, formateadores y linters que hayas dejado activos.
- `:TSInstallAll` — compila los parsers de Tree-sitter.

La tabla de [Lenguajes soportados](#lenguajes-soportados) te dice qué nombre lleva cada lenguaje en cada columna, que no
siempre es el que esperarías.

> [!WARNING]
>
> Cada herramienta arrastra lo suyo, y ahí es donde la cosa se complica de verdad. Descomentar
> `sql` te pide [Python](/docs/Python.md); un servidor de Groovy o de Kotlin, un JDK; varios formateadores,
> [Node.js](/docs/Node.js.md). Por eso vienen desactivados: no para esconderlos, sino para que la instalación por
> defecto no te obligue a instalar medio ecosistema. Los comentarios de cada lista avisan de los
> casos raros.

#### Tus mapeos y tus manías

[lua/user/cfg.lua](/lua/user/cfg.lua) es tu archivo. Mapeos, comandos y las decisiones que no son técnicas sino de
gusto. Es el único sitio que puedes tocar sin chocar con el resto de la configuración.

Lo primero que hay ahí es lo primero que probablemente quieras cambiar:

```lua
local sync_clipboard = true
```

Sincroniza el clipboard del sistema con los registros de Neovim, para que copiar y pegar funcione
como en cualquier otro programa. Está en `true` porque en tus primeros meses con Neovim es una
pelea que no hace falta pelear. Cuando deje de serlo, ponlo en `false`: recuperas el control de los
registros, y te quedan `<leader>cs` y `<leader>cn` para mover el contenido en una dirección o en la
otra cuando lo necesites.

#### Indentación

- En [lua/user/indent.lua](/lua/user/indent.lua) puedes configurar la indentación por lenguaje. Primero el estilo
  `spaces|tabs` y si has escogido `spaces` entonces puedes decidir cuántos con `width`.

- En [lua/lzy/conform.lua](/lua/lzy/conform.lua) puedes especificar un `line-lenght` por defecto. A menos que sea
  reemplazado por la configuración de formateo del proyecto este será el valor que se usará para
  determinar cuándo una línea es demasiado larga. `line-lenght = 97` queda bien con una fuente
  `JetBrainsMono Nerd Font` de `11px`; probado en una _Kitty con zsh_ y _Terminal de Windows con
  Powershell_.

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
