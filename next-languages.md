# Próximos lenguajes

Estado de la investigación: 2026-08-14.

Este documento es una hoja de ruta. No implica que todos estos servidores deban activarse a la
vez. En especial, conviene elegir **un LSP principal** y **un formateador principal** por
filetype para evitar diagnósticos duplicados y dos herramientas peleándose por el mismo buffer.

## Estado

| Lenguaje       | Estado              | Notas                                                      |
| -------------- | ------------------- | ---------------------------------------------------------- |
| PowerShell     | Hecho el 2026-08-15 | Probado en Linux con `pwsh` 7                              |
| PostgreSQL/SQL | Hecho el 2026-08-15 | Los dos servidores, repartidos por raíz                    |
| Groovy         | Hecho el 2026-08-15 | Ver los avisos de su sección: el JDK y el timeout          |
| Nix            | Hecho el 2026-08-15 | `nil` necesita `nix` del sistema para compilar, ver abajo  |
| Julia          | Hecho el 2026-08-15 | `cmd` propio y `runic` con condition a medida, ver sección |
| Batch          | Nada que hacer      | Esperando a que el parser entre en `nvim-treesitter`       |
| El resto       | Pendiente           | Fish, Solidity, Erlang y R                                 |

Lo hecho trajo dos piezas que no eran de ningún lenguaje en concreto y que ya están disponibles:

- **Capa de linting** (`lua/lzy/lint.lua`, nvim-lint) para lo que ningún LSP cubre, con
  condiciones por proyecto. Nació porque `sqls` no publica diagnósticos.
- **JDK de compilación para Mason** (`lua/hzsr/mason/init.lua`): algunos paquetes se compilan al
  instalar y su herramienta de build rechaza los JDK modernos. Se fija `JAVA_HOME` antes de
  cualquier instalación.

## Qué hacer con cada lenguaje

Los lenguajes se activan **de uno en uno**, nunca varios a la vez: se termina uno, se entrega al
usuario para que lo pruebe y solo entonces se empieza el siguiente. Antes de tocar nada,
comprobar que el lenguaje ya está descrito en este documento; si no lo está, añadirlo aquí con su
stack —LSP, Treesitter, formateador y dependencias— antes de configurarlo.

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

Corrección de la tabla de arriba, comprobada al implementarlo: Neovim detecta `.ps1` y `.psm1`, pero
**no `.psd1`**. Los manifiestos de módulo se quedaban sin filetype y `powershell_es` —que solo
atiende `ps1`— no se adjuntaba a ellos. Lo mapea `lua/user/opts.lua`.

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

| Lenguaje     | LSP decidido                  | Treesitter | Conform                              | Instalación principal                   |
| ------------ | ----------------------------- | ---------- | ------------------------------------ | --------------------------------------- |
| PostgreSQL   | `postgres_lsp`                | `sql`      | ver política SQL                     | Mason                                   |
| SQL genérico | `sqls`                        | `sql`      | ver política SQL                     | Mason                                   |
| Fish         | `fish_lsp`                    | `fish`     | `fish_indent`                        | LSP en Mason; formatter viene con Fish  |
| Nix          | `nil_ls`                      | `nix`      | `nixfmt`                             | Mason (`nil` compila con Cargo + `nix`) |
| Solidity     | `solidity_ls_nomicfoundation` | `solidity` | `forge_fmt`                          | LSP en Mason; formatter con Foundry     |
| Erlang       | `elp`                         | `erlang`   | `erlfmt`                             | LSP en Mason; formatter externo         |
| Groovy       | `groovyls`                    | `groovy`   | `npm-groovy-lint`                    | Mason                                   |
| R            | `air`                         | `r`        | `air`                                | Mason                                   |
| Julia        | `julials`                     | `julia`    | `runic` (`cmd`/`condition` a medida) | Mason (`cmd` propio, ver Julia)         |

Las excepciones importantes están debajo; no conviene copiar la tabla a ciegas. Los formatters
que no vienen de Mason (`forge_fmt`, `erlfmt`, `runic`) siguen la política de binarios externos.

### PostgreSQL y SQL genérico

#### Política decidida

Entran **los dos**, y se reparten por raíz de proyecto. No es la coexistencia cara de
obsidian.nvim/marksman: allí lo caro fue reimplementar las funciones del vault para que dos
plugins no se pelearan por el buffer; aquí no hay plugins, solo dos clientes LSP y una
comprobación de raíz.

Media pieza viene hecha de fábrica. `nvim-lspconfig` ya publica `postgres_lsp` con
`root_markers = { "postgres-language-server.jsonc" }` y `workspace_required = true`, así que **se
autolimita**: fuera de un proyecto Postgres ni arranca. El que se pasa de la raya es `sqls`, que
trae `root_markers = { "config.yml" }` y ningún `workspace_required`, de modo que se engancharía
también dentro del proyecto Postgres. Todo el arbitraje es hacerle sitio, con el mismo patrón que
ya usa `marksman` en `lua/lzy/lspconfig.lua`:

```lua
sqls = {
  -- Dentro de un proyecto Postgres manda postgres_lsp. root_dir devuelve nil
  -- ahí y workspace_required impide arrancar sin root, igual que marksman
  -- dentro de un vault.
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
	  return on_dir(nil)
	end
	local postgres = #vim.fs.find({ "postgres-language-server.jsonc" }, {
	  upward = true,
	  path = vim.fs.dirname(name),
	}) > 0
	if postgres then
	  return on_dir(nil)
	end
	on_dir(vim.fs.root(bufnr, { "config.yml", ".git" }))
  end,
},
```

Contrapartida aceptada: con `workspace_required`, un `.sql` suelto sin `.git` ni raíz se queda sin
`sqls`. En la práctica casi no ocurre, y `sqls` sin proyecto aporta poco.

Formato: `sqlfluff` cuando el proyecto declara su dialecto y `pg_format` cuando no. `sqlfluff` es mejor
—formatea y hace de linter— pero exige un `.sqlfluff` por proyecto y sin él se queja; en una config
pública eso castiga a quien solo abre un `.sql`. Conform lo resuelve con `condition`, el mismo patrón
que ya usa `markdown_tabs` en `lua/lzy/conform.lua`:

```lua
sql = { "sqlfluff", "pg_format", stop_after_first = true },

-- formatters
sqlfluff = {
  condition = function(_, ctx)
	return vim.fs.root(ctx.filename, { ".sqlfluff" }) ~= nil
  end,
},
```

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
normalmente `postgres-language-server.jsonc`. No se adjunta a un `.sql` suelto en cualquier
directorio, y eso es justamente lo que hace barato el reparto con `sqls`.

El formato no lo lleva el LSP sino Conform, según la política decidida arriba. `pg_format` es el
que atiende a quien no declara dialecto, así que hace falta su mapping en `names.lua`:

```lua
pg_format = "pgformatter",
```

#### SQL genérico

Para SQL que deba servir con PostgreSQL, MySQL, SQLite, SQL Server y otros, elegiría `sqls` antes
que `sqlls`:

```lua
-- lspconfig.lua: M.servers
"sqls",
```

`sqls` y `sqlls` son proyectos diferentes. `sqlls` es el nombre de config para `sql-language-server`;
`slls` probablemente era una errata. `sqls` tiene soporte explícito para varios motores y aprovecha
la conexión a base de datos para completado y navegación. Sin configurar la conexión, su valor
baja bastante.

`sqlfluff` necesita que cada proyecto declare su dialecto, normalmente en `.sqlfluff`; por eso entra
con `condition` y `pg_format` recoge el resto. `sql_formatter` queda como alternativa descartada: más
sencillo, pero peor linter y menos consciente de cada motor.

`postgres_lsp` y `sqls` conviven porque se reparten por raíz, no porque se activen los dos sobre el
mismo buffer: eso sigue estando prohibido y es lo que evita el `root_dir` de la política.

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

Decidido: **`nil_ls`**, no `nixd`. `nixd` sabe bastante más (opciones, paquetes, navegación con NixOS,
Home Manager y flakes), pero no está en el registro de Mason: se instala con Nix o desde el
sistema. En una config pública eso significa que quien la clona y ejecuta `:MasonInstallAll` se
queda con un LSP configurado que no tiene. `nil_ls` ya está mapeado en Mason como `nil` y entra solo.

```lua
-- lspconfig.lua: M.servers
"nil_ls",

-- treesitter.lua
"nix",          -- M.languages
nix = true,     -- M.enabled_highlights

-- conform.lua
nix = { "nixfmt" },

-- names.lua
nixfmt = "nixfmt",
```

Quien trabaje en serio con NixOS puede cambiar `nil_ls` por `nixd` en su fork; queda documentado
como mejora opcional, no como default. No usar ambos a la vez.

Lo que se aprendió al implementarlo, que no estaba anticipado en la propuesta original:

- **`nil` necesita el binario `nix` para compilarse**, no solo `cargo`/`rustc`. Su `build.rs`
  ejecuta `nix eval` para volcar la tabla de funciones integradas del lenguaje y la empotra en el
  binario; sin `nix` en el `PATH` la instalación de Mason falla con
  `Failed to get builtins. Is nix accessible?`. Es dependencia solo de compilación: una vez
  construido, `nil` no vuelve a necesitar `nix` para funcionar. En Arch está en el repo oficial
  `extra` (`pacman -S nix`), sin pasar por AUR ni Chaotic-AUR.
- Por eso "Instalación principal: Mason" de la tabla de arriba es una simplificación: hace falta
  ese paquete del sistema una vez, igual que Groovy necesita un JDK compatible. Ver el caso 5 de
  "Qué instala Mason y qué no" en `docs/language-dependencies.md`.

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

El mapping `groovyls = "groovy-language-server"` ya existe.

Lo que se aprendió al implementarlo, que era justo lo que la nota marcaba como riesgo:

- **El Java importa antes de que exista el servidor.** Mason no descarga este paquete, lo compila
  con `./gradlew build`, y el wrapper fija Gradle 9.1 (septiembre de 2025). Con el JDK 26 del
  sistema el build muere con `Unsupported class file major version 70`. Por eso se fija
  `JAVA_HOME` a un JDK 21 o 17 antes de cualquier instalación de Mason, y el servidor se arranca
  luego con ese mismo JDK vía `cmd_env`.
- **`npm-groovy-lint` entra solo como formateador**, para no duplicar los diagnósticos de
  `groovyls`. Necesita `timeout_ms = 20000`: arranca una JVM con CodeNarc y la primera pasada de
  la sesión pasa de 10 s.

### R

Decidido: **Air**, un único binario moderno de Mason que ofrece LSP y formato.

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

Alternativa descartada por ahora: `r_language_server`, ya mapeado como `r-languageserver`. Es el
servidor establecido y cubre además `rmd` y `quarto` en la config de `nvim-lspconfig`; necesita el
paquete R `languageserver`. Merecería el cambio si aparece mucho trabajo con R Markdown o Quarto, o
si Air se queda corto en funciones de paquete/proyecto.

No activar `air` y `r_language_server` a la vez para `.R` sin una razón concreta.

### Julia

El estándar del ecosistema es `julials`, respaldado por `LanguageServer.jl`. Con una salvedad
importante descubierta al implementarlo, no anticipada aquí: **el `cmd` por defecto de
`nvim-lspconfig` no sirve con el paquete que instala Mason**, no es solo "añadir a `M.servers`".

`julials.lua` invoca `julia` crudo con un script inline que espera `LanguageServer.jl` instalado
a mano vía `Pkg.add`. El paquete de Mason (`julia-lsp`) es un binario propio que recibe la ruta
del entorno como argumento posicional (`julia-lsp "<ruta>"`); con el `cmd` por defecto falla con
exit 1 inmediato. Es un problema real y reconocido, sin arreglo limpio en la API clásica de
`lspconfig` (`mason-org/mason-lspconfig.nvim#582`, "`before_init` llega demasiado tarde para
cambiar `cmd`").

Con la API nativa `vim.lsp.config`/`vim.lsp.enable` que usa esta config sí hay arreglo limpio,
porque `root_dir` se resuelve a una cadena antes de invocar `cmd(dispatchers, config)`:

```lua
-- lspconfig.lua: M.servers
"julials",

-- lspconfig.lua: M.config
julials = {
  cmd = function(dispatchers, config)
    local env = config.root_dir or vim.fn.getcwd()
    return vim.lsp.rpc.start({ "julia-lsp", env }, dispatchers)
  end,
},

-- treesitter.lua
"julia",          -- M.languages
julia = true,     -- M.enabled_highlights

-- conform.lua: formatters_by_ft
julia = { "runic" },
-- conform.lua: formatters (resuelve ~/.julia/bin/runic si no está en PATH,
-- avisa una vez y se salta el formato si de verdad no está; ver el código
-- completo y por qué NO es la pieza general de Erlang/Solidity)
runic = { command = function() --[[ ... ]] end, condition = function() --[[ ... ]] end },
```

El mapping `julials = "julia-lsp"` ya existía. `julia` (el runtime) es dependencia real del
sistema —sin él, `julia-lsp` no arranca—, disponible en el repo oficial `extra` de Arch, sin
CAUR/AUR. Verificado con `julia` instalado: el cliente llega a adjuntarse (`ATTACHED
client=julials`) con el `root_dir` correcto y arranca la precompilación de
`LanguageServer.jl`/`SymbolServer.jl`, que tarda varios minutos la primera vez.

`runic` **sí entra** en Conform, con una versión mínima y local del "aviso de binario ausente" en
vez de esperar a la pieza compartida con Erlang y Solidity (todavía sin escribir). `runic` no
está en el registro de Mason: se instala como Pkg App
(`julia -e 'using Pkg; Pkg.Apps.add("Runic")'`), que deja el binario en `~/.julia/bin/runic`, un
directorio que Julia no añade al `PATH`. El `command` del formatter resuelve esa ruta absoluta
directamente si no está en `PATH`, y el `condition` avisa una vez (`vim.notify_once`) y se salta
el formato si de verdad no está instalado —sin bloquear el guardado ni fallar en bucle—.

Ojo: **esto no es la pieza general que Erlang y Solidity también necesitan**. Es un condition/
command a medida, solo para `runic`, escrito para no dejar Julia sin formateador mientras esa
pieza compartida no exista. Cuando se escriba, generalizar este caso (está anotado en el propio
`lua/lzy/conform.lua`) en vez de mantener dos mecanismos distintos.

Verificado con `runic` instalado: formatea de verdad (indentación, `return` explícito) sin tocar
el proyecto de prueba, que debe seguir mal formateado para que se compruebe `<leader>fm` a mano.

Los proyectos deben tener un entorno Julia reconocible (`Project.toml` o `JuliaProject.toml`). El
config de `nvim-lspconfig` sigue aportando `:LspJuliaActivateEnv` para cambiar el entorno cuando
sea necesario; no se ha sobrescrito ese `on_attach`, solo `cmd`.

## Política de herramientas que Mason no instala

Esta config es pública y hay gente usándola, así que el criterio no es "qué tengo yo instalado"
sino "qué le pasa a quien la clona". `:MasonInstallAll` instala todo lo que salga de la lista de
servidores y de Conform, pero **lo que no tiene mapping en Mason se salta en silencio**
(`lua/hzsr/mason/nvchad/init.lua`). Eso afecta a `erlfmt`, `runic` y `forge_fmt`, y afectaría a `nixd` si
alguna vez volviera a la propuesta.

Decidido: esas herramientas **sí entran** en la config, pero con `condition` sobre el ejecutable,
de modo que no se intente formatear con un binario que no existe. **El fallo no puede ser
silencioso**: si un filetype tiene formateador configurado y su binario falta, hay que decirlo
—una vez por herramienta y sesión, no en cada guardado— indicando qué falta y cómo se instala.

Esa pieza es común a Erlang, Julia y Solidity: la idea original era escribirla **una vez, antes**
del primer lenguaje que la necesitara, no tres veces. En la práctica, Julia ya tiene su propio
`condition`/`command` a medida para `runic` (funcionando, pero sin generalizar) porque no
compensaba dejar el lenguaje sin formateador esperando a esa pieza compartida —ver la nota para
quien continúe esto, justo debajo—. Vive en `lua/lzy/conform.lua` junto al resto de `condition`,
y lo que se documente de cada herramienta va a `docs/language-dependencies.md`.

Los binarios que sí vienen de Mason (`pg_format`, `nixfmt`, `air`, `npm-groovy-lint`) no
necesitan nada de esto: si falta alguno, es que `:MasonInstallAll` no se ha ejecutado.

### Nota para quien siga con esto (probablemente Opus)

Dos cosas que 平生三郎 pidió dejar anotadas explícitamente, sin tocarlas ahora:

1. **Sonnet 5 fue metiendo las cosas como pudo**, con condicionales a medida por lenguaje
   (`runic` en Julia es el primer caso) en vez de esperar a esta pieza general. La prioridad fue
   dejarlo funcionando ya y lo más limpio posible, no bloquear el progreso. El trabajo que queda
   es generalizar esos casos sueltos en el mecanismo compartido de esta sección —una función
   reutilizable con aviso no silencioso, una vez por herramienta y sesión— y volver a pasar por
   Julia (y luego Erlang/Solidity) para usarla en vez del condicional suelto.
2. **`docs/language-dependencies.md` necesita una pasada completa, no solo para Julia/Erlang/
   Solidity**. Faltan lenguajes de la matriz que ya estaban configurados en `lspconfig.lua`/
   `conform.lua` desde antes de este esfuerzo de "next-languages" y que nunca se documentaron ahí
   (revisar toda la lista, no dar por buena una comprobación superficial). Y de los lenguajes que
   sí aparecen mencionados —los de antes de esta tanda de SQL/PowerShell/Groovy/Nix/Julia
   incluidos, no solo los tres nuevos—, cualquiera que tenga una dependencia externa real
   (toolchain del sistema, binario que Mason no instala, versión de JDK/runtime específica...)
   necesita su propia sección `###` explicándola, con el mismo rigor que ya tienen Groovy/Nix/
   Julia/PowerShell/SQL. El criterio de "qué le pasa a quien clona la config sin mi toolchain" se
   aplica a todo el catálogo, no solo a lo nuevo.

## Bloques consolidados para cuando se implemente

Estos bloques son una referencia, no una invitación a activar todas las alternativas
simultáneamente.

### `lua/lzy/lspconfig.lua`

```lua
-- Primera tanda
"powershell_es",

-- Segunda tanda
"fish_lsp",
"postgres_lsp", -- se autolimita a proyectos con postgres-language-server.jsonc
"sqls",         -- resto de motores; cede la raíz a postgres_lsp (ver política SQL)
"nil_ls",
"solidity_ls_nomicfoundation",
"elp",
"groovyls",
"air",
"julials", -- cmd propio en M.config; el de nvim-lspconfig no sirve con Mason (ver Julia)
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
sql = { "sqlfluff", "pg_format", stop_after_first = true },
nix = { "nixfmt" },
solidity = { "forge_fmt" },
erlang = { "erlfmt" },
groovy = { "npm-groovy-lint" },
r = { "air" },
julia = { "runic" },
```

`sqlfluff` lleva `condition` de `.sqlfluff` y `pg_format` recoge el resto. `forge_fmt`, `erlfmt` y `runic`
llevan `condition` de ejecutable con aviso no silencioso: ver la política de herramientas que Mason
no instala.

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

No añadir mappings falsos para herramientas que Mason no ofrece (`erlfmt`, `runic`) ni para
herramientas que llegan con su toolchain (`fish_indent`, `forge_fmt`). `nil_ls` ya está mapeado como
`nil`.

## Orden de implementación propuesto

1. ~~PowerShell~~. Hecho. Se probó en Linux con `pwsh` 7; lo de Windows queda para cuando haya
   scripts que usen cmdlets exclusivos de esa plataforma.
2. Mantener `.bat`/`.cmd` con `dosbatch` hasta que el parser batch madure en `nvim-treesitter`.
3. ~~SQL~~. Hecho, con los dos servidores repartidos por raíz y el formateador condicional.
4. ~~Groovy~~. Hecho, con el JDK de compilación resuelto por el camino.
5. ~~Nix~~. Hecho; `nil` necesita `nix` del sistema para compilarse, resuelto por el camino.
6. ~~Julia~~. Hecho completo: el `cmd` por defecto de `nvim-lspconfig` no servía con el paquete
   de Mason, resuelto con un `cmd` propio (ver su sección). `runic` entró también, con un
   `condition`/`command` mínimo escrito a medida en vez de esperar al aviso de binario ausente
   general —queda anotado para que ese aviso, cuando se escriba, generalice este caso en vez de
   dejarlo como un mecanismo aparte.
7. Añadir Fish: el stack más barato que queda, todo de Mason y fácil de validar.
8. Escribir el aviso de binario ausente antes de tocar Solidity y Erlang: los dos dependen de él.
   De paso, generalizar el `condition` a medida que ya tiene `runic`.
9. Añadir Solidity, Erlang y R cuando haya un proyecto real con el que verificar roots,
   toolchains y formato.

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

## Para 平生三郎: con qué modelo hacer cada lenguaje

> [!IMPORTANT]
>
> Sección personal de 平生三郎. La IA no entra aquí: no son instrucciones para ella, no forma
> parte del plan de implementación y no debe editarla.

Lo que decide el modelo no es el lenguaje, es el trabajo que queda pendiente en él. Pide **Opus**
cuando haya una decisión abierta entre herramientas que se excluyen, cuando el LSP necesite
código propio en `lspconfig.lua` (más que añadirlo a `M.servers`), cuando la instalación se salga de
Mason (toolchains, `pkexec`, Yay) o cuando dos herramientas puedan pelearse por el mismo buffer.
Con **Sonnet** basta cuando el stack ya está decidido y escrito aquí, todo sale de Mason o de la
propia toolchain, y el trabajo es rellenar tres tablas, montar el proyecto de prueba y seguir el
checklist.

| Lenguaje                 | Modelo  | Por qué                                                                                                                      |
| ------------------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------- |
| PowerShell               | Hecho   | `powershell_es` necesita config propia: `bundle_path` a la raíz del ZIP de Mason (que no expone binario) y fallback de shell |
| Batch                    | Ninguno | No hay nada que instalar; la decisión ya está tomada: esperar al parser                                                      |
| PostgreSQL/SQL           | Hecho   | La decisión ya está tomada, pero hay que escribir el arbitraje de raíz y el formateador condicional                          |
| Nix                      | Sonnet  | `nil_ls` decidido y todo sale de Mason: es rellenar las tres tablas y probar                                                 |
| Groovy                   | Hecho   | Hay que comprobar el Java que pide `groovyls` y que `npm-groovy-lint` no duplique diagnósticos                               |
| Julia                    | Sonnet  | `julials` es mecánico y `runic` ya tiene política: entra con condition. Depende del aviso compartido                         |
| Fish                     | Sonnet  | Todo decidido: `fish_lsp` en Mason y `fish_indent` viene con el shell                                                        |
| Solidity                 | Sonnet  | Mason para el LSP y `forge_fmt` con condition; depende del aviso compartido                                                  |
| Erlang                   | Sonnet  | `elp` ya está mapeado y `erlfmt` entra con condition; depende del aviso compartido                                           |
| R                        | Sonnet  | Air es un único binario de Mason que hace LSP y formato                                                                      |
| Aviso de binario ausente | Opus    | Pieza compartida por Solidity, Erlang y Julia; se escribe una vez y antes que ellos                                          |

Dos avisos para cuando lo lance Sonnet:

- Las elecciones de herramienta ya están tomadas y escritas arriba; no hay que dejarle "elegir".
  Si se topa con una decisión que no esté en este documento, lo que debe hacer es parar y
  preguntarte, no elegir por su cuenta. Merece la pena decírselo en el propio prompt.
- Recordarle que esta config es pública: lo que rompa a quien la clone sin tu toolchain es un
  fallo, no un detalle. Ese es el criterio que decidió `nil_ls`, el formateador SQL condicional y
  el aviso de binario ausente.
