# Soporte de lenguajes y dependencias

Esta guía documenta las integraciones de lenguaje disponibles en **saburou-nvim**: servidores
LSP, formatters y parsers de Tree-sitter, además de las dependencias de sistema que algunas
herramientas necesitan para funcionar correctamente.

> [!IMPORTANT] Que una integración aparezca aquí significa que la configuración sabe utilizarla;
> **no implica que esté activada por defecto**. Algunas entradas pueden permanecer comentadas
> para mantener una instalación base más pequeña.

Los ejemplos de paquetes de sistema se centran en **Arch Linux**. La configuración de Neovim
intenta ser portable cuando es razonable, y las excepciones se indican en cada sección.

## Dónde vive cada cosa

Las rutas de esta sección son relativas al repositorio, no rutas locales de una máquina concreta:

- `lua/lzy/lspconfig.lua`: servidores LSP y ajustes específicos.
- `lua/lzy/conform.lua`: formatters y resolvers de ejecutables/plugins externos.
- `lua/lzy/lint.lua`: linters para lo que ningún LSP cubre, y en qué proyectos se ejecutan.
- `lua/lzy/treesitter.lua`: parsers, aliases y activación de Tree-sitter.
- `lua/hzsr/mason/nvchad/names.lua`: mapeos entre nombres de configuración y paquetes de Mason.
- `lua/user/opts.lua`: detección adicional de filetypes/extensiones.
- `lua/hzsr/sys/java.lua`: resolución portable de JDK para herramientas que no toleran cualquier
  versión de Java.

## Matriz de soporte

Los nombres de la columna **LSP** son los identificadores usados por la configuración de Neovim;
no siempre coinciden con el nombre del paquete de Mason.


| Lenguaje / formato | Filetype                         | LSP                      | Formatter                    | Tree-sitter                    |
| ------------------ | -------------------------------- | ------------------------ | ---------------------------- | ------------------------------ |
| Ansible            | `yaml.ansible`                   | `ansiblels`              | `yamlfmt` (vía `yaml`)       | `yaml` (fallback)              |
| Bash               | `bash`                           | `bashls`                 | `shfmt`                      | `bash`                         |
| C                  | `c`                              | `clangd`                 | `clang_format`               | `c`                            |
| C++                | `cpp`                            | `clangd`                 | `clang_format`               | `cpp`                          |
| CMake              | `cmake`                          | `neocmake`               | —                            | `cmake`                        |
| C#                 | `cs`                             | `csharp_ls`              | `csharpier`                  | `c_sharp`                      |
| Clojure            | `clojure`                        | `clojure_lsp`            | `zprint`                     | `clojure`                      |
| EDN                | `edn`                            | —                        | `zprint`                     | `clojure` (alias)              |
| CSS                | `css`                            | `cssls`                  | `prettier`                   | `css`                          |
| Dart               | `dart`                           | `dartls`                 | `dart_format`                | `dart`                         |
| Django templates   | `htmldjango`                     | `djls`                   | `djlint`                     | `htmldjango`                   |
| Elixir             | `elixir`                         | `elixirls`               | `mix`                        | `elixir`                       |
| EEx                | `eelixir`                        | `elixirls`               | `mix`                        | —                              |
| HEEx               | `heex`                           | `elixirls`               | `mix`                        | `heex`                         |
| F#                 | `fsharp`                         | `fsautocomplete`         | `fantomas`                   | `fsharp`                       |
| Fish               | `fish`                           | —                        | —                            | `fish`                         |
| Gleam              | `gleam`                          | —                        | `gleam`                      | —                              |
| Go                 | `go`                             | `gopls`                  | `gofmt`                      | `go`                           |
| Go modules         | `gomod` / `gosum` / `gowork`     | `gopls`                  | —                            | `gomod` / `gosum` / `gowork`   |
| Go templates       | `gotmpl`                         | `gopls`                  | `prettier_gotmpl`            | `gotmpl`                       |
| Groovy             | `groovy`                         | `groovyls`               | `npm-groovy-lint`            | `groovy`                       |
| Handlebars         | `handlebars`                     | —                        | `prettier_handlebars`        | —                              |
| Haskell            | `haskell`                        | `hls`                    | `fourmolu`                   | `haskell`                      |
| Literate Haskell   | `lhaskell`                       | `hls`                    | `fourmolu`                   | `haskell` (alias)              |
| HTML               | `html`                           | `html`                   | `prettier`                   | `html`                         |
| Java               | `java`                           | `jdtls`                  | `google-java-format`         | `java`                         |
| JavaScript         | `javascript` / `javascriptreact` | `vtsls`                  | `prettier`                   | `javascript`                   |
| Jinja              | `jinja`                          | `jinja_lsp`              | `prettier_jinja`             | `jinja` + `jinja_inline`       |
| JSON               | `json`                           | `jsonls`                 | `biome`                      | `json` / `json5`               |
| Kotlin             | `kotlin`                         | `kotlin_language_server` | `ktlint`                     | `kotlin`                       |
| LaTeX / TeX        | `tex` / `plaintex`               | `texlab`                 | `latexindent`                | —                              |
| Liquid / Shopify   | `liquid`                         | `shopify_theme_ls`       | `prettier_liquid`            | `liquid`                       |
| Lua                | `lua`                            | `lua_ls`                 | `stylua`                     | `lua` / `luadoc`               |
| Make               | `make`                           | —                        | —                            | `make`                         |
| Markdown           | `markdown`                       | `marksman`               | `prettier` + `markdown_tabs` | `markdown` + `markdown_inline` |
| OCaml              | `ocaml`                          | `ocamllsp`               | `ocamlformat`                | `ocaml`                        |
| OCaml interface    | `ocamlinterface`                 | `ocamllsp`               | `ocamlformat`                | `ocaml_interface`              |
| PHP                | `php`                            | `phpactor`               | `php_cs_fixer`               | `php`                          |
| PowerShell         | `ps1`                            | `powershell_es`          | vía LSP                      | `powershell`                   |
| Pug / Jade         | `pug`                            | `pug`                    | `prettier_pug`               | `pug`                          |
| Python             | `python`                         | `basedpyright` + `ruff`  | `ruff_format`                | `python`                       |
| QML                | `qml`                            | `qmlls`                  | `qmlformat` (externo)        | `qmljs`                        |
| Ruby               | `ruby`                           | `ruby_lsp`               | `rubocop`                    | `ruby`                         |
| Rust               | `rust`                           | `rust_analyzer`          | `rustfmt`                    | `rust`                         |
| Scala              | `scala`                          | `metals`                 | `scalafmt`                   | `scala`                        |
| SCSS               | `scss`                           | `cssls`                  | `prettier`                   | —                              |
| SQL                | `sql`                            | `postgres_lsp` / `sqls`  | `sqlfluff` / `pg_format`     | `sql`                          |
| Surface            | `surface`                        | —                        | `mix`                        | —                              |
| Svelte             | `svelte`                         | `svelte`                 | `prettier_svelte`            | `svelte`                       |
| Swift              | `swift`                          | `sourcekit`              | `swiftformat`                | `swift`                        |
| TOML               | `toml`                           | `taplo`                  | `taplo`                      | `toml`                         |
| Twig               | `twig`                           | `twiggy_language_server` | `prettier_twig`              | `twig`                         |
| TypeScript / TSX   | `typescript` / `typescriptreact` | `vtsls`                  | `prettier`                   | `typescript` / `tsx`           |
| Typst              | `typst`                          | `tinymist`               | `typstyle`                   | `typst`                        |
| Vim                | `vim`                            | —                        | —                            | `vim`                          |
| Vimdoc             | `vimdoc`                         | —                        | —                            | `vimdoc`                       |
| Vue                | `vue`                            | `vue_ls`                 | `prettier`                   | `vue`                          |
| YAML               | `yaml`                           | `yamlls`                 | `yamlfmt`                    | `yaml`                         |
| Zig                | `zig`                            | `zls`                    | `zigfmt`                     | `zig`                          |

Además se instala el parser `printf`, usado como parser auxiliar. `expert` se mantiene como
alternativa comentada a `elixirls` hasta evaluarlo con calma.

## Qué instala Mason y qué no

Mason cubre buena parte de los LSP y formatters, pero esta configuración **no presupone que Mason
aporte el SDK o toolchain del lenguaje**. Un servidor puede estar perfectamente instalado y aun
así no poder analizar un proyecto si falta su runtime, compilador, gestor de paquetes o metadata
de build.

Hay tres casos especialmente importantes:

1. **Herramientas incluidas en el toolchain**: por ejemplo `dartls`/`dart format`, `gofmt`,
   `rustfmt`, `zigfmt` o `sourcekit-lsp`.
2. **Herramientas externas al catálogo usado por Mason**: por ejemplo `metals`, `scalafmt`,
   `qmlformat` y varios plugins de Prettier.
3. **LSP instalados por Mason que dependen de software del sistema**: C#, Clojure, Kotlin,
   Haskell, OCaml, Ruby, Django/Ansible, etc.
4. **Paquetes que Mason no descarga sino que compila**: `groovy-language-server` se instala con
   `./gradlew build`. Ahí el JDK importa antes de que exista el servidor, y las herramientas de
   build rechazan los JDK más nuevos que ellas mismas. Por eso la configuración fija `JAVA_HOME`
   a un JDK 21 o 17 —y avisa de cuál eligió— antes de lanzar **cualquier** instalación, incluidas
   las de la interfaz de Mason: se engancha al evento `package:install:handle`, que se emite
   justo antes de ejecutar el instalador. Un `JAVA_HOME` explícito del entorno manda sobre esto.

Cuando algo no arranca, conviene comprobar en este orden: ejecutable disponible, filetype
correcto, raíz de proyecto detectada y toolchain del proyecto instalado/restaurado.

### Paquetes de AUR y Chaotic-AUR

Si una dependencia requiere Yay, comprobar antes si el mismo paquete está disponible en
Chaotic-AUR (CAUR). Documentar las dos vías: CAUR mediante `pacman` como opción preferida cuando el
repositorio esté configurado y AUR mediante Yay como alternativa. Los comandos de Yay deben usar
siempre `--sudoloop`.

## Notas por lenguaje

### Ansible

El LSP usa `yaml.ansible`, no `yaml` a secas. `lua/user/opts.lua` detecta playbooks y estructuras
típicas (`roles/`, `playbooks/`, `group_vars/`, `host_vars/`, `inventory/`) y deja el resto de
YAML para `yamlls`.

Dependencias de sistema:

```bash
sudo pacman -S --needed ansible-core ansible-lint
```

- `ansible-core` aporta `ansible` y `ansible-playbook`.
- `ansible-lint` se usa para diagnósticos del propio LSP.
- El formatter sigue siendo `yamlfmt`; `yaml.ansible` se resuelve al formatter de `yaml`.
- La configuración de `yamlfmt` fuerza el formateo real por `stdin` y conserva el `---` de los
  playbooks; esto evita el no-op que puede producir una invocación basada únicamente en
  `-in $FILENAME`.
- Tree-sitter reutiliza el parser `yaml` para el filetype compuesto.

### C#

`csharp_ls` y CSharpier necesitan un **.NET SDK completo**, no sólo el runtime. Si
`dotnet tool install` falla con mensajes del tipo `No .NET SDKs were found`, hay que instalar el
SDK y los runtimes compatibles con esa versión.

Comprobación útil:

```bash
dotnet --list-sdks
dotnet --list-runtimes
dotnet --info
```

En Arch, evita mezclar paquetes del sistema con Snap, repositorios de Microsoft o instalaciones
manuales en `/usr/share/dotnet`; tener varios runtimes en paralelo sí es normal.

### Clojure

Mason puede instalar `clojure-lsp`, pero el servidor necesita el CLI `clojure` para calcular el
classpath de proyectos `tools.deps`.

```bash
sudo pacman -S --needed clojure
clojure -Sdescribe
clojure -Spath
```

Si el LSP informa de un `Classpath lookup failed`, comprobar primero que el CLI funciona desde la
misma sesión que inicia Neovim. EDN reutiliza `zprint` y el parser de Clojure.

### Dart

`dartls` y `dart_format` **no son paquetes independientes de Mason**: ambos vienen con el SDK de
Dart.

```bash
sudo pacman -S --needed dart
dart --version
dart format --help
```

Neovim ejecuta el servidor a través de `dart language-server --protocol=lsp`; basta con que
`dart` esté en `PATH`. Lo mismo aplica al SDK incluido con Flutter.

### F#

FSAutocomplete puede aparecer adjunto y, aun así, no ofrecer diagnósticos si el proyecto no está
restaurado. Desde la carpeta del `.fsproj`:

```bash
dotnet restore
```

Después, reiniciar el LSP. En F# la lista y el orden de archivos del `.fsproj` forman parte del
modelo del proyecto.

### Haskell

La instalación de HLS usada por Mason depende de **GHCup**. En Unix puede instalarse con el
bootstrap oficial:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

No se ejecuta como root. Tras instalarlo, abrir una terminal nueva o cargar `~/.ghcup/env` para
que Mason encuentre `ghcup`. El toolchain base (GHC/Cabal) pertenece a GHCup; HLS puede seguir
gestionado por Mason para evitar duplicados.

Los `.lhs` usan el filetype `lhaskell`: Conform aplica `fourmolu` y Tree-sitter reutiliza el
parser `haskell` mediante alias.

### Groovy

Groovy casi nunca se escribe llamándose Groovy: el filetype `groovy` cubre también los
`build.gradle` del DSL de Gradle y los `Jenkinsfile`. Neovim detecta los tres de serie.

`groovy-language-server` es el caso más delicado de todo el catálogo por el JDK, y por partida
doble:

- **Al instalar**: Mason no lo descarga, lo compila con `./gradlew build`, y el wrapper del
  proyecto fija Gradle 9.1 (septiembre de 2025). Gradle rechaza cualquier JDK posterior a él: con
  un JDK 26 el build muere con `Unsupported class file major version 70`. Por eso la
  configuración fija `JAVA_HOME` a un JDK 21 o 17 antes de cualquier instalación de Mason.
- **Al ejecutar**: el jar tiene bytecode Java 8 y arrancaría en cualquier JDK, pero lo mueve
  Groovy 4.0.26. Se le pasa el mismo JDK con `cmd_env`, igual que a `kotlin-language-server`,
  para no depender de que el del sistema siga siendo compatible. `GROOVY_LSP_JAVA_HOME` fuerza
  otro.

`npm-groovy-lint` entra **solo como formateador**. Sabe también linteear, pero los diagnósticos
ya los da `groovyls`, y dos fuentes diciendo cosas parecidas sobre el mismo buffer es justo lo
que esta configuración evita. Si `groovyls` se queda corto en reglas de estilo, el sitio para
añadirlo es la capa de nvim-lint, no Conform.

Su entrada en Conform lleva `timeout_ms = 20000` por necesidad: arranca una JVM con CodeNarc y la
primera pasada de la sesión supera los 10 s en archivos normales. Las siguientes son bastante más
rápidas, pero el límite tiene que aguantar la primera o el formato falla por timeout.

### Java

`jdtls` y `google-java-format` no requieren ajustes especiales en la configuración más allá de
disponer de un JDK compatible con el proyecto.

### Kotlin

`kotlin-language-server` puede romperse al ejecutarse con un JDK demasiado nuevo para su parser
interno. La configuración resuelve un JDK compatible de forma local al proceso del servidor, sin
cambiar el Java predeterminado del sistema.

Preferencia actual del resolver:

```lua
local java_home = hzsr.sys.java.resolve_home {
  env = { "KOTLIN_LSP_JAVA_HOME", "JAVA_HOME", "JDK_HOME" },
  versions = { 21, 17 },
  require_jdk = true,
}
```

Además se define siempre un `storagePath` escribible bajo `stdpath("cache")`; esto evita que
scripts `.kts` sueltos terminen serializando `init_options` como `[]`, valor que el servidor no
acepta.

Para forzar una instalación concreta:

```bash
export KOTLIN_LSP_JAVA_HOME="/ruta/al/jdk-21"
```

En Windows puede definirse la misma variable de entorno apuntando al directorio del JDK. El
resolver también contempla `extra_homes` y `extra_roots` desde la configuración.

### OCaml

Mason necesita un `opam` inicializado, no sólo el ejecutable instalado:

```bash
sudo pacman -S --needed opam
opam init --yes --no-setup --compiler=ocaml-system
```

`--no-setup` evita modificar archivos del shell. Si una herramienta del switch se quiere ejecutar
manualmente, puede usarse `opam exec` o cargar `opam env` sólo para esa sesión.

#### `ocamlformat-rpc`

Algunas instalaciones de Mason exponen `ocamlformat` pero no enlazan `ocamlformat-rpc` en
`mason/bin`. La configuración de `ocamllsp` añade al `PATH` del servidor el directorio
`mason/packages/ocamlformat/bin`, calculado a partir de `stdpath("data")`. No se modifica el
`PATH` global ni se crean symlinks manuales.

#### Dune en modo watch

La integración RPC de Dune necesita una instancia activa para ciertos
diagnósticos/actualizaciones del proyecto:

```bash
opam exec -- dune build --watch
```

El watcher pertenece al ciclo de vida del proyecto y no se inicia automáticamente desde Neovim.

### Python

La configuración separa responsabilidades:

- `basedpyright`: análisis de tipos, navegación y completado.
- `ruff`: diagnósticos/lint rápidos.
- `ruff_format`: formateo mediante Conform.

Esto permite usar Ruff sin convertirlo en sustituto del servidor de tipos.

### PowerShell

PowerShell 7 se ejecuta de forma nativa en Linux mediante `pwsh`; no es una emulación. Es suficiente
para probar sintaxis, scripts multiplataforma, formato y PowerShell Editor Services. Los módulos,
cmdlets y APIs exclusivos de Windows deben probarse en Windows.

Mason instala `powershell-editor-services`, pero no el runtime `pwsh`. En Arch, instalar
`powershell-bin` desde una de estas fuentes:

```bash
# Chaotic-AUR (preferida si el repositorio ya está configurado)
sudo pacman -S --needed powershell-bin

# AUR
yay --sudoloop -S --needed powershell-bin
```

Comprobación:

```bash
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'
```

El paquete de Mason no deja binario en `mason/bin`: es un ZIP con scripts que se arrancan desde
PowerShell. Por eso la configuración le pasa `bundle_path` con la raíz extraída y `shell` con el
runtime, que es `pwsh` y cae a `powershell` si no lo encuentra.

Dos detalles propios de este stack:

- `.psd1` (manifiestos de módulo y ajustes de PSScriptAnalyzer) **no lo detecta Neovim**; lo
  mapea a `ps1` la regla de `lua/user/opts.lua`. Sin ella, `powershell_es` —que solo atiende
  `ps1`— no se adjunta a esos archivos.
- No hay entrada en Conform para `ps1` a propósito: el formato lo hace el propio servidor con
  PSScriptAnalyzer, y el mapeo de formato cae a LSP cuando Conform no cubre el filetype. Un
  formateador propio duplicaría ese motor.

### SQL

Es el único filetype con **dos LSP a la vez**, repartidos por raíz de proyecto en lugar de
adjuntarse los dos al mismo buffer:

- `postgres_lsp` (Mason: `postgres-language-server`) manda en los proyectos que tienen un
  `postgres-language-server.jsonc`. Viene de fábrica con `workspace_required`, así que fuera de
  ellos ni arranca.
- `sqls` (Mason: `sqls`) cubre el resto de motores. La configuración le añade un `root_dir` que
  devuelve `nil` dentro de un árbol PostgreSQL, para que no se solape con el anterior.

Consecuencia asumida: un `.sql` suelto, sin `.git` ni raíz de proyecto, no recibe ningún LSP.

Ninguno de los dos necesita software del sistema, pero los dos rinden mucho más con una base de
datos accesible: `postgres_lsp` toma de ahí los tipos y `sqls` el completado de tablas y columnas
(vía su `config.yml`). Sin conexión, ambos se quedan en análisis de sintaxis.

**`sqls` no produce diagnósticos**: no anuncia `diagnosticProvider` y tampoco los publica. No es un
fallo de configuración, es lo que hace. Sí avisa una vez por proyecto de que no tiene conexión a
base de datos. Los diagnósticos del SQL que no es PostgreSQL los pone `sqlfluff` a través de
nvim-lint, con el mismo criterio de dialecto declarado que el formato: donde no hay declaración no
se ejecuta, y ese `.sql` se queda sin diagnósticos antes que llenarse de falsos positivos.

En un proyecto PostgreSQL no se solapan: allí `sqlfluff` normalmente no tiene dialecto declarado y
los diagnósticos los pone `postgres_lsp`.

El formato no lo hace el LSP sino Conform, y también depende del proyecto:

- `sqlfluff` (Mason) si el proyecto declara su dialecto, en un `.sqlfluff` o en una sección
  `[tool.sqlfluff]`/`[sqlfluff]` de `pyproject.toml`, `setup.cfg`, `tox.ini` o `pep8.ini`.
  `sqlfluff` aborta si no encuentra dialecto, así que solo se activa cuando existe de verdad.
- `pg_format` (Mason: `pgformatter`) en cualquier otro caso. Está orientado a PostgreSQL pero
  digiere SQL genérico, y no necesita configuración por proyecto.

La comprobación de la declaración es propia: la que trae Conform acepta `pyproject.toml` a secas,
lo que activaría `sqlfluff` en cualquier proyecto Python que tuviera un `.sql` dentro.

### QML

QML es uno de los casos donde se resuelve explícitamente el ejecutable porque según la
instalación puede existir como `qmlls` o `qmlls6`. El formatter `qmlformat` también es externo:
debe estar disponible en `PATH`.

### Ruby

Ruby LSP usa el Ruby del sistema y necesita Bundler. RuboCop puede requerir además componentes de
la biblioteca estándar empaquetados por separado en Arch:

```bash
sudo pacman -S --needed ruby ruby-bundler ruby-erb
```

Si el proyecto contiene `Gemfile`, generar también `Gemfile.lock` con `bundle install`.

Para evitar que Ruby LSP intente escribir gems bajo `/usr/lib/ruby/gems`, la configuración define
`BUNDLE_PATH` dentro de `stdpath("data")/ruby-lsp/bundle`. La ruta es por usuario y se calcula en
runtime.

### Scala

`metals` y `scalafmt` se tratan como herramientas externas. Se recomienda un JDK estable para
Metals; la configuración se ha diseñado para convivir con otros JDK instalados.

En Arch, `sbt` y un JDK pueden instalarse desde repositorios oficiales; Metals/Scalafmt pueden
proceder de AUR, Chaotic-AUR o sus métodos oficiales. Evita instalar el mismo ejecutable por
varias vías si eso deja versiones distintas compitiendo en `PATH`.

Scalafmt necesita una versión en `.scalafmt.conf`. Para proyectos que no tengan archivo de
configuración, `conform.lua` puede aplicar un fallback reproducible; los proyectos Scala 2
deberían declarar además su dialecto explícitamente.

Como Scalafmt arranca sobre la JVM, la entrada de Scala dispone de un timeout mayor que el valor
general de Conform.

### Swift

`sourcekit-lsp` viene dentro del toolchain de Swift; no se instala como paquete LSP independiente
de Mason. En Arch puede usarse el toolchain empaquetado como `swift-bin` cuando esté disponible
mediante la fuente de paquetes elegida.

Conform usa `swiftformat` por separado. `sourcekit` está restringido al filetype `swift` para
evitar competir con `clangd` en C/C++/Objective-C.

### Django templates

`djls` se restringe a `htmldjango` para no duplicar clientes en `html` o `python`. El servidor
necesita una raíz de proyecto Django real para resolver tags, filtros y contexto.

En Arch:

```bash
sudo pacman -S --needed python-django
```

El formatter es `djlint`, con perfil Django desde Conform.

### Go y plantillas Go

`gofmt` pertenece al toolchain de Go; `gopls` es el LSP. Para plantillas, `.tmpl`, `.gotmpl` y
`.gohtml` se normalizan al filetype `gotmpl`, que es el languageId que `gopls` entiende para este
caso.

El parser de Tree-sitter también es `gotmpl`. El formatter de plantillas usa Prettier con un
plugin externo:

```bash
sudo npm install -g prettier-plugin-go-template
```

`prettier_gotmpl` resuelve el plugin desde `npm root -g`; no se espera que Mason lo instale.

### Jinja

`.jinja`, `.jinja2` y `.j2` se normalizan al filetype `jinja`. `jinja_lsp` se restringe a ese
filetype para no duplicar a `basedpyright`.

El formatter usa un plugin externo de Prettier:

```bash
sudo npm install -g prettier-plugin-jinja-template
```

Tree-sitter usa `jinja` y su dependencia `jinja_inline`.

### Handlebars

La configuración ofrece formateo, pero no registra LSP ni parser de Tree-sitter para Handlebars.
`.handlebars` se normaliza al mismo filetype que `.hbs`.

```bash
sudo npm install -g prettier-plugin-handlebars
```

Conform llama al parser `glimmer` que expone ese plugin.

### Liquid / Shopify

`shopify_theme_ls` usa el language server incluido en Shopify CLI. La raíz del tema se detecta
mediante archivos típicos de Shopify (`shopify.theme.toml`, `.theme-check.yml`, `.shopifyignore`,
etc.).

El formatter utiliza el plugin oficial de Liquid para Prettier, que se resuelve fuera de Mason:

```bash
sudo npm install -g @shopify/prettier-plugin-liquid
```

### Pug / Jade

`.jade` se mapea a `pug`. El parser de Tree-sitter y el formatter funcionan de forma
independiente del LSP.

```bash
sudo npm install -g @prettier/plugin-pug
```

`pug-lsp` existe, pero sigue siendo una integración experimental/inmadura. Conviene tratar sus
capacidades como opcionales y no depender de él para rename/hover.

### Svelte

El LSP usa la configuración `svelte`; Conform usa `prettier_svelte` y Tree-sitter el parser
`svelte`.

### Twig

`twiggy_language_server` necesita una raíz de workspace; `composer.json` o `.git` son marcadores
útiles. Sin un framework PHP detectado puede seguir aportando sintaxis y built-ins, pero las
capacidades ligadas al framework serán más limitadas.

El formatter usa un plugin externo:

```bash
sudo npm install -g @zackad/prettier-plugin-twig
```

La implementación de Twiggy es parcial: rename/references/navegación funcionan mejor que la
inferencia de hover en expresiones complejas. La documentación no debe asumir que todas las
capacidades anunciadas por el servidor están igualmente completas.

### Typst

`tinymist` proporciona el LSP y `typstyle` el formatter; Tree-sitter usa el parser `typst`. No se
requiere un SDK de lenguaje tradicional para estas herramientas standalone.

La configuración permite trabajar también con archivos `.typ` sueltos: el `root_dir` termina
llamando a `on_dir(...)` y se habilita `single_file_support`, en lugar de depender exclusivamente
de encontrar un `.git`. El formateo del propio LSP se desactiva para que Conform sea la única vía
de formato.

`typstyle` se define con los valores de ancho de línea e indentación de la política general, ya
que el builtin de Conform no pasa por sí solo esos argumentos.

### Vue

Se usa `vue_ls` (Volar) y no el alias antiguo `volar`. Conform delega el SFC completo a
`prettier`; Tree-sitter usa el parser `vue`.

Para un análisis TypeScript completo dentro de `<script>`, el proyecto debe tener disponible su
TypeScript/tsdk correspondiente.

## Formatters externos y plugins de Prettier

Estos formatters no se consideran paquetes instalables directamente por Mason en esta
configuración y deben existir en el sistema o como plugin global de Node:

| Formatter de Conform  | Dependencia                               |
| --------------------- | ----------------------------------------- |
| `prettier_gotmpl`     | `prettier-plugin-go-template`             |
| `prettier_handlebars` | `prettier-plugin-handlebars`              |
| `prettier_jinja`      | `prettier-plugin-jinja-template`          |
| `prettier_liquid`     | `@shopify/prettier-plugin-liquid`         |
| `prettier_pug`        | `@prettier/plugin-pug`                    |
| `prettier_twig`       | `@zackad/prettier-plugin-twig`            |
| `qmlformat`           | ejecutable del toolchain Qt/QML en `PATH` |
| `dart_format`         | `dart format`, incluido en Dart SDK       |
| `gofmt`               | incluido en Go                            |
| `rustfmt`             | incluido en el toolchain de Rust          |
| `zigfmt`              | incluido en Zig                           |

Los wrappers `prettier_*` resuelven el directorio global de Node en runtime. Si un plugin no
existe, el formatter debe fallar con un mensaje accionable en lugar de formatear silenciosamente
con un parser incorrecto.

## Detalles de formato

- Markdown usa `prettier` y después `markdown_tabs`. La segunda pasada normaliza la sangría que
  Prettier deja con espacios en algunas estructuras incluso cuando se prefieren tabs.
- `rubocop` y `scalafmt` tienen un timeout de 10 segundos para evitar falsos fallos en el primer
  arranque.
- `yaml.ansible` reutiliza la configuración de `yaml` y `yamlfmt`.
- `edn` reutiliza `zprint`; `lhaskell` reutiliza `fourmolu`.
- `ocaml` y `ocamlinterface` comparten `ocamlformat`.

## Detección y aliases de filetype

Hay varias extensiones que se normalizan deliberadamente para que LSP, formatter y Tree-sitter
hablen el mismo languageId/filetype:

- `.jinja2`, `.j2` → `jinja`.
- `.jade` → `pug`.
- `.handlebars` → `handlebars`.
- `.tmpl`, `.gotmpl`, `.gohtml` → `gotmpl`.
- YAML con estructura de Ansible → `yaml.ansible`.
- `edn` → parser Tree-sitter `clojure`.
- `lhaskell` → parser Tree-sitter `haskell`.

Antes de depurar un LSP, comprobar `:set filetype?`; un filetype incorrecto suele explicar tanto
que el servidor no se adjunte como que se active el servidor equivocado.

## Comprobaciones rápidas

Dentro de Neovim:

```vim
:checkhealth vim.lsp
:LspInfo
:Mason
:ConformInfo
```

Para Tree-sitter, usar los comandos que exponga la versión fijada por el repositorio
(`:TSInstall`, `:TSUpdate`, etc.).

## Mantenimiento

Arch es rolling release: para actualizar dependencias de sistema, preferir una actualización
completa (`sudo pacman -Syu`) y evitar upgrades parciales.

Al añadir o quitar soporte de un lenguaje, revisar como mínimo:

1. Identificador de LSP y, si aplica, mapeo de paquete de Mason.
2. `formatters_by_ft` y cualquier resolver de ejecutables/plugins externos.
3. Parser de Tree-sitter y aliases de filetype.
4. Detección de extensiones/filetypes no estándar.
5. Dependencias del SDK/toolchain que Mason no instala.
6. README y esta guía, sin introducir rutas personales, versiones locales ni estados de pruebas
   temporales.

Las versiones concretas observadas durante pruebas locales sólo deberían entrar en el repositorio
cuando sean necesarias para explicar una incompatibilidad reproducible; no como inventario de una
máquina concreta.

## Referencias

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [Conform.nvim](https://github.com/stevearc/conform.nvim)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [PowerShell en distribuciones Linux mantenidas por la comunidad](https://learn.microsoft.com/es-es/powershell/scripting/install/community-support)
- [PowerShell (`powershell-bin`) en AUR](https://aur.archlinux.org/packages/powershell-bin)
- [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices)
- [CSharpier](https://csharpier.com/docs/Installation)
- [Clojure en Arch Linux](https://archlinux.org/packages/extra/any/clojure/)
- [GHCup](https://www.haskell.org/ghcup/)
- [Metals](https://scalameta.org/metals/docs/editors/vim/)
- [Scalafmt](https://scalameta.org/scalafmt/docs/installation.html)
- [Swift](https://www.swift.org/)
- [djLint](https://djlint.com/)
- [django-language-server](https://github.com/joshuadavidthomas/django-language-server)
- [Shopify Liquid tooling](https://shopify.dev/docs/themes/tools/liquid)
- [prettier-plugin-liquid](https://github.com/Shopify/prettier-plugin-liquid)
- [jinja-lsp](https://github.com/uros-5/jinja-lsp)
- [prettier-plugin-handlebars](https://github.com/ggoodman/prettier-plugin-handlebars)
- [Vue language tools](https://github.com/vuejs/language-tools)
- [Twiggy](https://github.com/moetelo/twiggy)
- [Pug plugin for Prettier](https://github.com/prettier/plugin-pug)
- [pug-lsp](https://github.com/opa-oz/pug-lsp)
