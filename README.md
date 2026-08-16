# saburou-nvim

## Brief

![Vista previa](docs/preview.png)

`saburou-nvim` es mi configuración de [Neovim](https://neovim.io/). Es una configuración opinionada, y estamos en una
fase en la que ya principalmente nos centramos en la corrección de bugs. En paralelo ha empezado
una refactorización completa que esperamos que no tarde demasiado en llegar.

Si os gusta el proyecto y quereis implusarlo podéis donarme para un café en [![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=W9K3ZTUM2QNAC).

## Installation

- [Windows 11](/docs/windows11.md)

### Guías deseadas

- [Arch Linux](/docs/archlinux.md)

- [macOS](/docs/macos.md)

- [Fedora](/docs/fedora.md)

- [Debian](/docs/debian.md)
- [Ubuntu](/docs/ubuntu.md)

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
