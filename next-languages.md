# Próximos lenguajes

Estado de la investigación: 2026-08-14.

Este documento es una hoja de ruta. No implica que todos estos servidores deban activarse a la
vez. En especial, conviene elegir **un LSP principal** y **un formateador principal** por
filetype para evitar diagnósticos duplicados y dos herramientas peleándose por el mismo buffer.

## Qué hacer con cada lenguaje

AGREGA AQUÍ SI NO ESTA YA O ACLARAR MEJOR: asegurarse de que está aquí, no se instalan multiples
lenguajes a la vez, se lanzan uno a uno y se interactua con el usuario para que lo pruebe.

No dar un lenguaje por terminado hasta completar este checklist:

- [ ] Configurar LSP, Treesitter y Conform —o documentar el fallback LSP—; tocar `opts.lua` o
	  `indent.lua` solo si hace falta.
- [ ] Verificar los mappings de Mason en `lua/hzsr/mason/nvchad/names.lua` y documentar todas las
	  dependencias en `docs/language-dependencies.md`.
- [ ] Si un paquete requiere Yay, comprobar antes si existe en Chaotic-AUR (CAUR), documentar
	  ambas vías y añadir siempre `--sudoloop` al comando de Yay.
- [ ] Crear en `/home/saburou/wip/proyectos/<lenguaje>` un proyecto mínimo pero completo, con
	  código válido y deliberadamente mal formateado. Incluir manifiestos, configuración, varios
	  filetypes o `.git` solo cuando sean necesarios para probar el lenguaje o detectar la raíz.
- [ ] Pedir al usuario que ejecute `:MasonInstallAll`; no lanzar instalaciones de Mason en su
	  lugar. Si faltan paquetes del sistema, indicar cuáles y esperar a que autorice instalarlos
	  con `pkexec`. Avisar antes al usuario, el usuario quizás está fumando y el pkexec se puede
	  quedar 5 minutos colgado mientras el usuario no está. Una vez autorizado el paquete exacto,
	  ejecutar `pkexec pacman` con `--noconfirm` desde el primer intento para evitar repetir el
	  comando por falta de entrada interactiva.
- [ ] Después de la instalación, comprobar detección de filetype, Treesitter, conexión y
	  funciones básicas del LSP, diagnósticos y formato usando el proyecto de prueba. Esto
	  también se delega al usuario.

## Prioridad 0: PowerShell y Batch

### Qué son realmente `pwsh`, `powershell`, `cmd` y `bat`

No son cuatro lenguajes.

| Nombre                          | Qué es                                                                                    | Archivos relacionados en Neovim               |
| ------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------- |
| `pwsh` / `pwsh.exe`             | Ejecutable de PowerShell moderno, versión 7+, multiplataforma y basado en .NET moderno    | `.ps1`, `.psm1`, `.psd1` → filetype `ps1`     |
| `powershell` / `powershell.exe` | Ejecutable de Windows PowerShell 5.1, antiguo, solo Windows y basado en .NET Framework    | Los mismos archivos y el mismo filetype `ps1` |
| `cmd.exe`                       | Intérprete clásico de comandos de Windows; es otro lenguaje, no una edición de PowerShell | `.bat` y `.cmd` → filetype `dosbatch`         |
| `.bat` / `.cmd`                 | Dos extensiones de la misma familia de scripts batch ejecutada por `cmd.exe`              | Ambos usan `dosbatch`                         |

`pwsh` y `powershell.exe` hablan esencialmente el mismo lenguaje PowerShell, pero no ofrecen
exactamente el mismo runtime, módulos ni compatibilidad. Para trabajo nuevo elegiría PowerShell 7
(`pwsh`). Windows PowerShell 5.1 solo interesa para automatización heredada o módulos que dependan
de Windows/.NET Framework.

La preferencia `auto`/`pwsh`/`powershell`/`cmd` de `lua/user/terminal.lua` elige el **proceso de la
terminal integrada**. No configura los filetypes ni el LSP.

### PowerShell: stack recomendado

| Capa       | Elección                                     | Motivo                                                                       |
| ---------- | -------------------------------------------- | ---------------------------------------------------------------------------- |
| LSP        | `powershell_es` (PowerShell Editor Services) | Definición, referencias, completado, análisis con PSScriptAnalyzer y formato |
| Treesitter | parser `powershell`                          | El parser se asocia al filetype `ps1`                                        |
| Conform    | ninguna entrada                              | Usar el formato de `powershell_es` mediante el fallback LSP                  |
| Mason      | `powershell-editor-services`                 | Ya existe el mapping `powershell_es` en `names.lua`                          |
| Runtime    | `pwsh` (PowerShell 7)                        | Necesario para ejecutar scripts y para PowerShell Editor Services            |

En Linux, `pwsh` es PowerShell 7 nativo, no una emulación. Permite probar el lenguaje y toda la
integración del editor; los módulos y APIs exclusivos de Windows deben validarse en Windows.

Cambios futuros en `lspconfig.lua`:

```lua
-- M.servers
"powershell_es",

-- M.config
powershell_es = function()
  return {
	bundle_path = vim.fs.joinpath(
	  vim.fn.stdpath "data",
	  "mason",
	  "packages",
	  "powershell-editor-services"
	),
	shell = vim.fn.executable "pwsh" == 1 and "pwsh" or "powershell",
  }
end,
```

La configuración especial no es decorativa: el config de `nvim-lspconfig` necesita conocer la raíz
del ZIP extraído de PowerShell Editor Services. Mason instala precisamente esa raíz en el
directorio usado arriba, pero su paquete no expone un binario normal en `mason/bin`.

En un equipo sin PowerShell 7, el fallback arrancaría `powershell.exe`. PowerShell Editor Services
soporta las versiones vigentes de PowerShell 7+; el soporte de Windows PowerShell 5.1 es de mejor
esfuerzo.

Cambios futuros en `treesitter.lua`:

```lua
-- M.languages: nombre del parser
"powershell",

-- M.enabled_highlights: nombre del filetype de Neovim
ps1 = true,
```

No añadir `ps1` a Conform. Si posteriormente queremos una política de formato propia, se puede
crear un formatter Conform que invoque `Invoke-Formatter`, pero duplicaría el motor que ya usa
PowerShell Editor Services/PSScriptAnalyzer.

### Batch (`.bat` y `.cmd`): stack recomendado por ahora

| Capa       | Elección          | Motivo                                                                                     |
| ---------- | ----------------- | ------------------------------------------------------------------------------------------ |
| Filetype   | `dosbatch` nativo | Neovim ya detecta `.bat` y `.cmd`                                                          |
| LSP        | ninguno           | No hay un servidor batch maduro y estándar que merezca añadirse                            |
| Conform    | ninguno           | No hay un formateador batch consolidado en Conform                                         |
| Treesitter | esperar           | Existe `tree-sitter-batch`, pero todavía no está en el catálogo local de `nvim-treesitter` |

Batch seguirá teniendo el highlighting Vim tradicional de `dosbatch`. No debemos añadir `cmd`, `bat` ni
`dosbatch` a `M.languages`: esos no son nombres de parser válidos actualmente.

Más adelante hay dos opciones para Treesitter:

1. Esperar a que `nvim-treesitter` catalogue `wharflab/tree-sitter-batch`.
2. Registrar ese parser manualmente y mapear `dosbatch` a su lenguaje.

La primera opción es preferible: el parser es reciente y batch tiene una gramática especialmente
desagradable (`%var%`, expansión retardada, labels, paréntesis y quoting de `cmd.exe`). Aquí el coste
de mantenimiento manual supera el beneficio inmediato.

## Prioridad 1: segunda tanda

### Resumen recomendado

| Lenguaje     | LSP recomendado               | Treesitter | Conform                   | Instalación principal                  |
| ------------ | ----------------------------- | ---------- | ------------------------- | -------------------------------------- |
| PostgreSQL   | `postgres_lsp`                | `sql`      | formato LSP o `pg_format` | Mason                                  |
| SQL genérico | `sqls`                        | `sql`      | `sqlfluff`                | Mason                                  |
| Fish         | `fish_lsp`                    | `fish`     | `fish_indent`             | LSP en Mason; formatter viene con Fish |
| Nix          | `nixd`                        | `nix`      | `nixfmt`                  | `nixd` externo; `nixfmt` en Mason      |
| Solidity     | `solidity_ls_nomicfoundation` | `solidity` | `forge_fmt`               | LSP en Mason; formatter con Foundry    |
| Erlang       | `elp`                         | `erlang`   | `erlfmt`                  | LSP en Mason; formatter externo        |
| Groovy       | `groovyls`                    | `groovy`   | `npm-groovy-lint`         | Mason                                  |
| R            | `air`                         | `r`        | `air`                     | Mason                                  |
| Julia        | `julials`                     | `julia`    | `runic`                   | LSP en Mason; formatter externo        |

Las alternativas y excepciones importantes están debajo; no conviene copiar la tabla a ciegas.

### PostgreSQL y SQL genérico

#### PostgreSQL

Para proyectos PostgreSQL elegiría `postgres_lsp`, el servidor actual de la comunidad de Supabase.
Usa un parser PostgreSQL real y puede ofrecer análisis de tipos, completado, lint de migraciones
y formato específico de PostgreSQL.

```lua
-- lspconfig.lua: M.servers
"postgres_lsp",

-- treesitter.lua
"sql",          -- M.languages
sql = true,     -- M.enabled_highlights
```

El servidor tiene `workspace_required = true`: cada proyecto debe tener una raíz reconocible,
normalmente `postgres-language-server.jsonc`. No esperaría que se adjunte correctamente a un `.sql`
suelto en cualquier directorio.

Opciones de formato:

- Primera prueba: no poner `sql` en Conform y usar el formato LSP.
- Alternativa independiente: `sql = { "pg_format" }`.

Si usamos `pg_format`, añadir a `names.lua`:

```lua
pg_format = "pgformatter",
```

#### SQL genérico

Para SQL que deba servir con PostgreSQL, MySQL, SQLite, SQL Server y otros, elegiría `sqls` antes
que `sqlls`:

```lua
-- lspconfig.lua: M.servers
"sqls",

-- conform.lua: formatters_by_ft
sql = { "sqlfluff" },
```

`sqls` y `sqlls` son proyectos diferentes. `sqlls` es el nombre de config para `sql-language-server`;
`slls` probablemente era una errata. `sqls` tiene soporte explícito para varios motores y aprovecha
la conexión a base de datos para completado y navegación. Sin configurar la conexión, su valor
baja bastante.

`sqlfluff` necesita que cada proyecto declare su dialecto, normalmente en `.sqlfluff`. Si no queremos
esa disciplina, `sql_formatter` es más sencillo pero menos útil como linter y menos consciente de
cada dialecto.

No activaría `postgres_lsp` y `sqls` globalmente a la vez para `sql`: ambos se adjuntarían al mismo
buffer. La selección debe ser por tipo de proyecto o se debe elegir uno como política general.

Mapping de Mason que falta para PostgreSQL:

```lua
postgres_lsp = "postgres-language-server",
```

`sqls`, `sqlls`, `sqlfluff` y `sql_formatter` ya tienen mapping local.

### Fish

Stack recomendado:

```lua
-- lspconfig.lua: M.servers
"fish_lsp",

-- treesitter.lua: M.languages
"fish",

-- treesitter.lua: M.enabled_highlights
fish = true,

-- conform.lua: formatters_by_ft
fish = { "fish_indent" },

-- names.lua
fish_lsp = "fish-lsp",
```

`fish_indent` viene con Fish y no se instala mediante Mason, por lo que no necesita mapping. Aunque
`fish_lsp` también sabe formatear, prefiero `fish_indent`: es la herramienta canónica del propio
shell y deja el reparto de responsabilidades muy claro.

### Nix

Hay que elegir uno:

- `nixd`: recomendación para uso serio de NixOS, Home Manager y flakes. Tiene mejor conocimiento
  de opciones, paquetes y navegación entre archivos, a costa de ser más pesado y depender del
  ecosistema Nix.
- `nil_ls`: alternativa más sencilla y ya mapeada en Mason como `nil`.

Propuesta principal:

```lua
-- lspconfig.lua: M.servers
"nixd",

-- treesitter.lua
"nix",          -- M.languages
nix = true,     -- M.enabled_highlights

-- conform.lua
nix = { "nixfmt" },

-- names.lua
nixfmt = "nixfmt",
```

`nixd` no está en el registro local de Mason y debe instalarse con Nix; no hay que inventarle un
mapping. Si preferimos instalación totalmente automática con Mason, cambiar `nixd` por `nil_ls` y
mantener el resto.

No usar ambos LSP a la vez.

### Solidity

Para proyectos Hardhat o Foundry:

```lua
-- lspconfig.lua: M.servers
"solidity_ls_nomicfoundation",

-- treesitter.lua
"solidity",          -- M.languages
solidity = true,     -- M.enabled_highlights

-- conform.lua
solidity = { "forge_fmt" },
```

El mapping LSP de Mason ya existe. `forge_fmt` viene con Foundry y debe estar en el `PATH`; no
necesita ni tiene sentido como paquete Mason separado. En proyectos que no usen Foundry se puede
omitir Conform y probar el formato del LSP, o adoptar Prettier con `prettier-plugin-solidity` más
adelante.

### Erlang y el ecosistema BEAM

Para completar Elixir/HEEx elegiría ELP (`elp`), el servidor incremental creado por WhatsApp, antes
que `erlangls`:

```lua
-- lspconfig.lua: M.servers
"elp",

-- treesitter.lua
"erlang",          -- M.languages
erlang = true,     -- M.enabled_highlights

-- conform.lua
erlang = { "erlfmt" },
```

`elp = "elp"` ya está en `names.lua`. `erlfmt` se instala fuera de Mason; no añadir mapping mientras el
registro no ofrezca el paquete.

Esto no sustituye Elixir: para el BEAM completo quedarían parsers `elixir`, `heex` y `erlang`, más el
LSP de Elixir que se elija en su momento.

### Groovy

Groovy cubre scripts, `Jenkinsfile`, Gradle y parte del ecosistema JVM:

```lua
-- lspconfig.lua: M.servers
"groovyls",

-- treesitter.lua
"groovy",          -- M.languages
groovy = true,     -- M.enabled_highlights

-- conform.lua
groovy = { "npm-groovy-lint" },

-- names.lua: mapping que falta para el formatter
["npm-groovy-lint"] = "npm-groovy-lint",
```

El mapping `groovyls = "groovy-language-server"` ya existe. Hay que comprobar también el Java
requerido por la versión instalada de Groovy Language Server. `npm-groovy-lint` formatea y además
puede producir reglas de lint; al integrarlo inicialmente conviene comprobar que no duplica
diagnósticos que queramos obtener por otra vía.

### R

La recomendación inicial para archivos `.R` es Air: un único binario moderno que ofrece LSP y
formato.

```lua
-- lspconfig.lua: M.servers
"air",

-- treesitter.lua
"r",          -- M.languages
r = true,     -- M.enabled_highlights

-- conform.lua
r = { "air" },

-- names.lua
air = "air",
```

Alternativa: `r_language_server`, ya mapeado como `r-languageserver`. Es el servidor establecido y
cubre además `rmd` y `quarto` en la config de `nvim-lspconfig`; necesita el paquete R `languageserver`.
Lo preferiría si trabajamos mucho con R Markdown/Quarto o si Air se queda corto en funciones de
paquete/proyecto.

No activar `air` y `r_language_server` a la vez para `.R` sin una razón concreta.

### Julia

El estándar del ecosistema es `julials`, respaldado por `LanguageServer.jl`:

```lua
-- lspconfig.lua: M.servers
"julials",

-- treesitter.lua
"julia",          -- M.languages
julia = true,     -- M.enabled_highlights

-- conform.lua
julia = { "runic" },
```

El mapping `julials = "julia-lsp"` ya existe. `runic` es un formatter de Julia y Conform ya conoce su
interfaz, pero no está en el registro local de Mason: debe instalarse desde Julia o mediante el
sistema. Si no queremos esa dependencia, puede omitirse y dejar que `julials`/el ecosistema Julia
resuelva el formato.

Los proyectos deben tener un entorno Julia reconocible (`Project.toml` o `JuliaProject.toml`). El
config actual de `nvim-lspconfig` incluye el comando `:LspJuliaActivateEnv` para cambiar el entorno
cuando sea necesario.

## Bloques consolidados para cuando se implemente

Estos bloques son una referencia, no una invitación a activar todas las alternativas
simultáneamente.

### `lua/lzy/lspconfig.lua`

```lua
-- Primera tanda
"powershell_es",

-- Segunda tanda
"fish_lsp",
"postgres_lsp", -- PostgreSQL; no combinar globalmente con sqls
-- "sqls",      -- alternativa para SQL genérico
"nixd",         -- o nil_ls, nunca ambos
"solidity_ls_nomicfoundation",
"elp",
"groovyls",
"air",          -- o r_language_server, nunca ambos
"julials",
```

Batch no aparece porque no hay un LSP recomendable.

### `lua/lzy/treesitter.lua`

```lua
-- M.languages
"powershell",
"fish",
"sql",
"nix",
"solidity",
"erlang",
"groovy",
"r",
"julia",
```

```lua
-- M.enabled_highlights
ps1 = true,
fish = true,
sql = true,
nix = true,
solidity = true,
erlang = true,
groovy = true,
r = true,
julia = true,
```

Todos esos parsers existen en el catálogo local actual de `nvim-treesitter`. Batch es la excepción.

### `lua/lzy/conform.lua`

```lua
fish = { "fish_indent" },
-- sql = { "pg_format" }, -- PostgreSQL
sql = { "sqlfluff" },     -- SQL genérico; configurar dialecto por proyecto
nix = { "nixfmt" },
solidity = { "forge_fmt" },
erlang = { "erlfmt" },
groovy = { "npm-groovy-lint" },
r = { "air" },
julia = { "runic" },
```

PowerShell queda deliberadamente fuera para usar formato LSP. Batch queda fuera porque no hay una
opción suficientemente sólida.

### `lua/hzsr/mason/nvchad/names.lua`

Mappings que faltan si se adopta la propuesta completa:

```lua
air = "air",
fish_lsp = "fish-lsp",
nixfmt = "nixfmt",
["npm-groovy-lint"] = "npm-groovy-lint",
pg_format = "pgformatter",
postgres_lsp = "postgres-language-server",
```

No añadir mappings falsos para herramientas que Mason no ofrece (`nixd`, `erlfmt`, `runic`) ni para
herramientas que llegan con su toolchain (`fish_indent`, `forge_fmt`).

## Orden de implementación propuesto

1. Añadir PowerShell completo y probar `.ps1`, `.psm1` y `.psd1` en Windows y, si interesa,
   también con `pwsh` en Linux.
2. Mantener `.bat`/`.cmd` con `dosbatch` hasta que el parser batch madure en `nvim-treesitter`.
3. Añadir Fish y Nix: son stacks pequeños y fáciles de validar.
4. Elegir una política SQL antes de habilitar nada: PostgreSQL específico o SQL genérico.
5. Añadir Solidity, Erlang, Groovy, R y Julia cuando haya un proyecto real con el que verificar
   roots, toolchains y formato.

## Referencias principales

- [Diferencias entre PowerShell 7 y Windows PowerShell 5.1](https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell)
- [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices)
- [Parser Treesitter de batch](https://github.com/wharflab/tree-sitter-batch)
- [Postgres Language Server](https://github.com/supabase-community/postgres-language-server)
- [`sqls`](https://github.com/sqls-server/sqls) y
  [`sql-language-server`/`sqlls`](https://github.com/joe-re/sql-language-server)
- [`fish-lsp`](https://github.com/ndonfris/fish-lsp)
- [`nixd`](https://github.com/nix-community/nixd) y [`nil`](https://github.com/oxalica/nil)
- [Nomic Foundation Solidity Language Server](https://github.com/NomicFoundation/hardhat-vscode/tree/development/server)
- [Erlang Language Platform](https://github.com/WhatsApp/erlang-language-platform) y
  [`erlfmt`](https://github.com/WhatsApp/erlfmt)
- [Groovy Language Server](https://github.com/GroovyLanguageServer/groovy-language-server) y
  [`npm-groovy-lint`](https://github.com/nvuillam/npm-groovy-lint)
- [Air](https://github.com/posit-dev/air) y
  [`languageserver` para R](https://github.com/REditorSupport/languageserver)
- [`LanguageServer.jl`](https://github.com/julia-vscode/LanguageServer.jl) y
  [Runic.jl](https://github.com/fredrikekre/Runic.jl)
